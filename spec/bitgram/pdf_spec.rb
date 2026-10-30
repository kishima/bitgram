# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "stringio"
require "tmpdir"
require "bitgram/pdf/chromium"

RSpec.describe "PDF output" do
  # Reads page count, MediaBox and the font file kinds of a PDF with pypdf.
  let(:inspector) do
    <<~PYTHON
      import json, sys, pypdf
      reader = pypdf.PdfReader(sys.argv[1])
      fonts = []
      for page in reader.pages:
          for font in page.get("/Resources", {}).get("/Font", {}).values():
              font = font.get_object()
              descendants = font.get("/DescendantFonts")
              font = descendants[0].get_object() if descendants else font
              descriptor = font["/FontDescriptor"].get_object()
              fonts.append({"name": str(font["/BaseFont"]),
                            "files": [k for k in ("/FontFile", "/FontFile2", "/FontFile3") if k in descriptor]})
      print(json.dumps({"pages": len(reader.pages),
                        "media_box": [float(v) for v in reader.pages[0].mediabox], "fonts": fonts}))
    PYTHON
  end
  let(:definition) do
    { version: 1, title: "PDF", layout: { row_bits: 32, bit_order: "lsb0" }, svg: { font_family: "M PLUS 1p" },
      fields: [{ name: "flags", bits: 20 }, { name: "frozen", bits: 1 }, { name: "gc_color", bits: 3 },
               { name: "tt", bits: 8 }] }
  end

  def chromium
    Bitgram::Pdf::Chromium.locate || skip("Chromium is unavailable")
  end

  def inspect_pdf(path)
    output, status = Open3.capture2e("python3", "-c", inspector, path)
    skip "python3 with pypdf is unavailable: #{output.lines.last}" unless status.success?
    JSON.parse(output)
  rescue Errno::ENOENT
    skip "python3 is unavailable"
  end

  def mplus_installed?
    fc_list = Bitgram::Util::Command.which("fc-list")
    fc_list && Bitgram::Util::Command.run([fc_list, "M PLUS 1p"], stdin_data: "", timeout: 5).include?("M PLUS 1p")
  end

  it "rounds the page up to the page step and keeps the SVG size otherwise" do
    expect(Bitgram::Pdf::Chromium.page_size(149.4, 8)).to eq(152)
    expect(Bitgram::Pdf::Chromium.page_size(672, 8)).to eq(672)
    expect(Bitgram::Pdf::Chromium.page_size(149.4, 1)).to eq(150)
    html = Bitgram::Pdf::Chromium.html("<svg/>", 672, 152)
    expect(html).to include("@page { size: 672px 152px; margin: 0; }", "overflow: hidden")
  end

  it "finds Chromium from the setting, then the environment" do
    expect(Bitgram::Pdf::Chromium.locate("/opt/chrome")).to eq("/opt/chrome")
    previous = ENV.fetch("BITGRAM_CHROME", nil)
    ENV["BITGRAM_CHROME"] = "/env/chrome"
    expect(Bitgram::Pdf::Chromium.locate).to eq("/env/chrome")
  ensure
    ENV["BITGRAM_CHROME"] = previous
  end

  it "reports a missing Chromium as a rasterizer failure" do
    diagram = Bitgram.load(definition)
    Dir.mktmpdir do |dir|
      expect { diagram.save(File.join(dir, "x.pdf"), chrome: File.join(dir, "missing")) }
        .to raise_error(Bitgram::RasterizerNotFound, /missing/)
    end
  end

  it "requires an output path on the command line" do
    error = StringIO.new
    status = Bitgram::CLI.new(stdin: StringIO.new(JSON.generate(definition)), stdout: StringIO.new, stderr: error)
                         .run(%w[render - -f pdf])
    expect(status).to eq(2)
    expect(error.string).to include("pdf requires --output PATH")
  end

  it "writes a one-page PDF whose MediaBox is the page size in points" do
    binary = chromium
    Dir.mktmpdir do |dir|
      path = File.join(dir, "figure.pdf")
      diagram = Bitgram.load(definition)
      diagram.save(path, chrome: binary)
      info = inspect_pdf(path)
      svg = diagram.to_svg
      width, height = %w[width height].map { |key| svg[/<svg [^>]*\b#{key}="([\d.]+)"/, 1].to_f }
      page = [width, height].map { |value| Bitgram::Pdf::Chromium.page_size(value, 8) }
      expect(info["pages"]).to eq(1)
      expect(info["media_box"]).to eq([0, 0, page[0] * 0.75, page[1] * 0.75])
      expect(info["fonts"]).not_to be_empty
      if mplus_installed?
        expect(info["fonts"]).to all(include("files" => ["/FontFile2"]))
        expect(info["fonts"].map { |font| font["name"] }).to all(end_with("+MPLUS1p-Regular"))
      end
    end
  end

  it "renders PDF from the command line with --config" do
    binary = chromium
    Dir.mktmpdir do |dir|
      input = File.join(dir, "figure.json")
      shared = File.join(dir, "book.yml")
      File.write(input, JSON.generate(definition))
      File.write(shared, "pdf:\n  chrome: #{binary}\n  page_step: 1\n")
      output = File.join(dir, "figure.pdf")
      error = StringIO.new
      status = Bitgram::CLI.new(stdout: StringIO.new, stderr: error).run(["render", input, "--config", shared,
                                                                          "-o", output])
      expect([error.string, status]).to eq(["", 0])
      expect(inspect_pdf(output)["pages"]).to eq(1)
    end
  end
end
