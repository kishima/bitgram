# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "open3"

RSpec.describe "command line" do
  def run_cli(*args, input: "")
    output = StringIO.new
    error = StringIO.new
    status = Bitgram::CLI.new(stdin: StringIO.new(input), stdout: output, stderr: error).run(args)
    [output.string, error.string, status]
  end

  let(:definition) { '{"version":1,"fields":[{"name":"A","bits":32}]}' }

  it "exposes the CLI" do
    expect(Bitgram.const_defined?(:CLI)).to be true
  end

  %w[render validate presets init doctor version].each do |command|
    it "shows help for #{command}" do
      output, error, status = run_cli(command, "--help")
      expect(status).to eq(0)
      expect(output).to include("Usage:", command)
      expect(error).to be_empty
    end
  end

  it "renders standard input and detects JSON" do
    output, error, status = run_cli("render", "-", input: definition)
    expect(status).to eq(0)
    expect(error).to be_empty
    expect(output).to include("|                               A                               |")
  end

  it "renders a preset with Unicode borders" do
    output, _, status = run_cli("render", "--preset", "udp", "--ascii-style", "unicode")
    expect(status).to eq(0)
    expect(output).to include("┌", "Source Port")
  end

  it "gives --set priority irrespective of argument order" do
    output, _, status = run_cli("render", "-", "--set", "layout.bit_order=lsb0", "--bit-order", "msb0",
                                "--set", "layout.bit_numbers=false", "--set", "ascii.indent=3", input: definition)
    expect(status).to eq(0)
    expect(output.lines.first).to start_with("   +-+")
    reverse, _, reverse_status = run_cli("render", "-", "--set", "layout.bit_order=lsb0",
                                         "--bit-order", "msb0", input: definition)
    expect(reverse_status).to eq(0)
    expect(reverse.lines[1]).to start_with(" 1 0 9 8")
  end

  it "infers SVG output from the file extension" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "diagram.svg")
      _, _, status = run_cli("render", "-", "-o", path, input: definition)
      expect(status).to eq(0)
      expect(File.read(path)).to include("<svg")
    end
  end

  it "allows explicit output format independent of extension" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "diagram.output")
      _, _, status = run_cli("render", "-", "-f", "svg", "-o", path, input: definition)
      expect(status).to eq(0)
      expect(File.read(path)).to include("<svg")
    end
  end

  it "reports warnings and fails strict mode before writing" do
    partial = '{"version":1,"fields":[{"name":"A","bits":8}]}'
    output, error, status = run_cli("render", "-", "--strict", input: partial)
    expect(status).to eq(1)
    expect(output).to be_empty
    expect(error).to include("V-08")
  end

  it "validates all files even after an invalid input" do
    Dir.mktmpdir do |directory|
      first = File.join(directory, "first.yml")
      second = File.join(directory, "second.yml")
      File.write(first, "version: 2\nfields: []\n")
      File.write(second, "version: 1\nfields: [{name: A, bits: 4}]\n")
      _, error, status = run_cli("validate", first, second, "--strict")
      expect(status).to eq(1)
      expect(error).to include(first, second, "V-08")
    end
  end

  it "validates standard input" do
    _, error, status = run_cli("validate", "-", "--input-format", "json", input: definition)
    expect(status).to eq(0)
    expect(error).to be_empty
  end

  it "reports parse errors as invalid definitions" do
    _, error, status = run_cli("render", "-", input: "fields: [")
    expect(status).to eq(1)
    expect(error).not_to be_empty
  end

  [[], ["unknown"], ["render"], ["validate"], ["render", "--unknown"],
   ["render", "-", "-f", "pdf"], ["render", "-", "-f", "png"],
   ["render", "-", "-f", "jpeg", "-o", "-"], ["render", "-", "--preset", "tcp"],
   ["render", "-", "--set", "broken"], ["render", "--preset", "../udp"],
   ["init", "../udp"], ["presets", "extra"], ["render", "-", "--input-format", "csv"]].each do |args|
    it "returns usage status for #{args.inspect}" do
      _, error, status = run_cli(*args, input: definition)
      expect(status).to eq(2)
      expect(error).not_to be_empty
    end
  end

  it "returns I/O status for missing inputs" do
    _, error, status = run_cli("render", "/no-such-bitgram-file.yml")
    expect(status).to eq(4)
    expect(error).to include("no-such-bitgram-file")
  end

  it "returns raster status when the requested converter cannot handle JPEG" do
    Dir.mktmpdir do |directory|
      _, error, status = run_cli("render", "-", "-o", File.join(directory, "a.jpg"),
                                 "--rasterizer", "rsvg", input: definition)
      expect(status).to eq(3)
      expect(error).to match(/jpeg/i)
    end
  end

  it "lists presets and emits a reusable definition" do
    output, _, status = run_cli("presets")
    expect(status).to eq(0)
    expect(output.split).to eq(%w[arp icmp ipv4 ipv6 tcp udp])
    source, _, init_status = run_cli("init", "udp")
    expect(init_status).to eq(0)
    expect(Bitgram.load(source).to_ascii).to eq(Bitgram.preset(:udp).to_ascii)
  end

  it "prints version and environment diagnostics" do
    version, _, status = run_cli("version")
    expect(status).to eq(0)
    expect(version).to include(Bitgram::VERSION)
    output, _, doctor_status = run_cli("doctor")
    expect(doctor_status).to eq(0)
    expect(output).to include("Ruby", "bitgram", "vips", "rsvg", "ImageMagick", "CJK", "png:", "jpeg:")
  end

  it "runs the installed command entrypoint" do
    output, error, status = Open3.capture3(RbConfig.ruby, "-Ilib", "exe/bitgram", "version")
    expect(status.exitstatus).to eq(0)
    expect(error).to be_empty
    expect(output).to include(Bitgram::VERSION)
  end

  it "prints global help and version aliases" do
    expect(run_cli("--help").first).to include("Usage: bitgram")
    expect(run_cli("--version").first).to include(Bitgram::VERSION)
  end

  it "handles malformed and conflicting setting paths" do
    [["--set", "ascii..indent=1"], ["--set", "ascii=bad", "--set", "ascii.indent=1"]].each do |settings|
      expect(run_cli("render", "-", *settings, input: definition).last).to eq(2)
    end
  end

  it "converts decimal settings and rejects values outside their valid range" do
    output, _, status = run_cli("render", "-", "-f", "svg", "--set", "svg.font_size=12.5", input: definition)
    expect(status).to eq(0)
    expect(output).to include("12.5")
    expect(run_cli("render", "-", "--set", "ascii.indent=-1", input: definition).last).to eq(1)
  end

  it "shows internal failure backtraces only with debug" do
    allow(Bitgram).to receive(:preset).and_raise(RuntimeError, "test internal failure")
    _, ordinary, status = run_cli("render", "--preset", "udp")
    _, debug, debug_status = run_cli("render", "--preset", "udp", "--debug")
    expect([status, debug_status]).to eq([70, 70])
    expect(ordinary).to eq("test internal failure\n")
    expect(debug).to include("cli.rb:")
  end

  it "continues validation after missing files" do
    _, error, status = run_cli("validate", "/no-such-bitgram-input", "-", input: "version: 2\nfields: []")
    expect(status).to eq(4)
    expect(error).to include("no-such-bitgram-input", "V-01")
  end

  it "reports malformed standard input during validation" do
    expect(run_cli("validate", "-", input: "fields: [").last).to eq(1)
  end

  it "defaults init to UDP and rejects extra names" do
    expect(run_cli("init").first).to include("title: UDP Header")
    expect(run_cli("init", "udp", "tcp").last).to eq(2)
  end
end
