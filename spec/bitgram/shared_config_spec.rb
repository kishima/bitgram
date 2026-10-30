# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"

RSpec.describe "Shared settings file (--config)" do
  def run_cli(*args)
    output = StringIO.new
    error = StringIO.new
    status = Bitgram::CLI.new(stdin: StringIO.new(""), stdout: output, stderr: error).run(args)
    [output.string, error.string, status]
  end

  let(:dir) { Dir.mktmpdir }
  let(:shared) { write("book.yml", "svg:\n  font_family: M PLUS 1p\n  theme: mono\n  font_size: 12\n") }
  let(:definition) { write("figure.yml", "version: 1\nsvg: { font_size: 14 }\nfields:\n  - { name: A, bits: 32 }\n") }

  after { FileUtils.remove_entry(dir) }

  def write(name, content)
    File.join(dir, name).tap { |path| File.write(path, content) }
  end

  it "applies the shared settings beneath the definition" do
    svg = Bitgram.load_file(definition, config: shared).to_svg
    expect(svg).to include("font-family: &apos;M PLUS 1p&apos;;", "stroke: #000000;")
    expect(svg).to include('font-size="14"')
    expect(svg).not_to include('font-size="12"')
  end

  it "accepts a Hash and leaves the definition's own values in charge" do
    diagram = Bitgram.load({ version: 1, layout: { row_bits: 16 }, fields: [{ name: "A", bits: 16 }] },
                           config: { layout: { row_bits: 8, offsets: "hex" } })
    expect(diagram.layout.document.layout).to include("row_bits" => 16, "offsets" => "hex")
  end

  it "lets command-line overrides win over both" do
    output, error, status = run_cli("render", definition, "--config", shared, "-f", "svg",
                                    "--set", "svg.font_size=10")
    expect([error, status]).to eq(["", 0])
    expect(output).to include('font-size="10"', "&apos;M PLUS 1p&apos;")
  end

  it "is used by validate" do
    partial = write("partial.yml", "version: 1\nfields:\n  - { name: A, bits: 8 }\n")
    quiet = write("quiet.yml", "layout:\n  allow_partial_row: true\n")
    _, warning, = run_cli("validate", partial)
    expect(warning).to include("V-08")
    _, error, status = run_cli("validate", partial, "--config", quiet)
    expect([error, status]).to eq(["", 0])
  end

  it "rejects keys other than configuration sections" do
    bad = write("bad.yml", "fields: []\nsvg: { theme: mono }\n")
    expect { Bitgram.load_file(definition, config: bad) }.to raise_error(Bitgram::ParseError, /only layout.*fields/)
  end

  it "reports invalid values with the settings file's line numbers" do
    bad = write("bad.yml", "svg:\n  theme: mono\n  font_size: 0\n")
    expect { Bitgram.load_file(definition, config: bad) }
      .to raise_error(Bitgram::ParseError, /bad\.yml:3: V-03 \$\.svg\.font_size/)
    _, error, status = run_cli("render", definition, "--config", bad)
    expect(status).to eq(1)
    expect(error).to include("bad.yml:3")
  end
end
