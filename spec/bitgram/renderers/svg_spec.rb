# frozen_string_literal: true

require "spec_helper"
require "rexml/document"
require "tempfile"

RSpec.describe "SVG rendering" do
  def diagram(fields = [{ name: "Source Port", bits: 16 }, { name: "Destination Port", bits: 16 }], **options)
    Bitgram.load({ version: 1, title: "UDP Header", fields: fields, **options })
  end

  def xml(svg)
    REXML::Document.new(svg)
  end

  it "renders deterministic XML with accessible labels and bit positions" do
    output = diagram.to_svg
    expect(output).to eq(diagram.to_svg)
    root = xml(output).root
    expect(root.name).to eq("svg")
    expect(root.attributes["viewBox"]).to eq("0 0 672 120")
    expect(root.attributes["role"]).to eq("img")
    expect(REXML::XPath.match(root, "//g[@class='bg-field']").length).to eq(2)
    expect(REXML::XPath.match(root, "//g[@class='bg-bit-numbers']/text").length).to eq(32)
  end

  it "escapes labels, attributes, titles and descriptions" do
    source = diagram([{ name: '<script>"&', bits: 32, description: "</title><script>alert(1)</script>" }])
    root = xml(source.to_svg(id_prefix: "custom"))
    expect(REXML::XPath.match(root, "//script")).to be_empty
    ids = REXML::XPath.match(root, "//*[@id]").map { |node| node.attributes["id"] }
    expect(ids.uniq).to eq(ids)
    expect(ids).to all(start_with("custom-"))
  end

  it "renders blocks, variable edges, reserved hatching, optional borders and values" do
    source = diagram([{ name: "Address", bits: 64, reserved: true, optional: true },
                      { name: "Version", bits: 32, value: 4 }, { name: "Data", bits: "variable" }])
    root = xml(source.to_svg)
    expect(REXML::XPath.match(root, "//rect[@stroke-dasharray='4 3']").length).to be >= 1
    expect(REXML::XPath.match(root, "//rect[@fill='url(#udp-header-hatch)']").length).to eq(1)
    expect(REXML::XPath.match(root, "//path").length).to eq(2)
    expect(REXML::XPath.match(root, "//text").map(&:text)).to include("= 4")
    expect(source.to_svg).not_to include("dominant-baseline", "writing-mode")
  end

  it "uses inline theme colors and disables automatic dark mode for raster compatibility" do
    output = diagram.to_svg(theme: "auto", inline_styles: true)
    expect(output).not_to include("<style", "@media")
    expect(output).to include('stroke="#1f2328"')
    expect(diagram.to_svg(theme: "auto")).to include("@media (prefers-color-scheme: dark)")
    expect(diagram.to_svg(theme: "dark")).to include("#0d1117")
  end

  it "supports RFC headers, offsets, lsb0, hidden titles and hidden ticks" do
    source = diagram([{ name: "A", bits: 32 }, { name: "B", bits: 32 }], layout: { offsets: "hex", bit_order: "lsb0" })
    output = source.to_svg(bit_number_style: "rfc", show_title: false, ticks: false)
    expect(output).to include("0x00", "0x04")
    expect(output).not_to include('class="bg-title"', 'class="bg-tick"')
    expect(xml(output).root.attributes["width"].to_f).to be > 672
  end

  it "applies custom theme palettes and class overrides below field fills" do
    Tempfile.create(["theme", ".yml"]) do |file|
      file.write("palette: ['#123456']\nclasses:\n  header:\n    fill: '#654321'\n")
      file.flush
      source = diagram([{ name: "A", bits: 8 }, { name: "B", bits: 8, class: "header" },
                        { name: "C", bits: 16, class: "header", fill: "red" }])
      output = source.to_svg(theme: file.path)
      expect(output).to include('fill="#123456"', 'fill="#654321"', 'fill="red"')
    end
  end

  it "rejects unsafe theme CSS" do
    Tempfile.create(["theme", ".yml"]) do |file|
      file.write("text: 'red; background: url(https://example.com)'\n")
      file.flush
      expect { diagram.to_svg(theme: file.path) }.to raise_error(Bitgram::RenderError, /color/)
    end
  end

  it "bounds nesting in theme files before deserializing them" do
    Tempfile.create(["theme", ".yml"]) do |file|
      file.write("palette: #{'[' * 25}red#{']' * 25}")
      file.flush
      expect { diagram.to_svg(theme: file.path) }.to raise_error(Bitgram::RenderError, /nesting/)
    end
  end

  it "renders notes and footnotes with correct canvas height" do
    source = diagram([{ name: "送信元ポート", bits: 1 }, { name: "Rest", bits: 31 }], notes: ["A note"])
    output = source.to_svg(fit_order: %w[footnote truncate])
    expect(output).to include("*1: 送信元ポート", "A note")
    expect(xml(output).root.attributes["height"].to_f).to be > 120
  end

  it "uses a stable content digest when there is no ASCII title" do
    source = Bitgram.load(version: 1, fields: [{ name: "A", bits: 32 }])
    output = source.to_svg
    expect(output).to match(/id="bitgram-[0-9a-f]{8}-title"/)
    expect(source.to_svg).to eq(output)
  end

  it "keeps theme selectors valid for IDs containing periods" do
    output = diagram.to_svg(id_prefix: "example.diagram")
    css = REXML::XPath.first(xml(output), "//style").text
    expect(css).to include('[id="example.diagram-diagram"]')
  end

  it "keeps theme selectors valid for titles starting with digits" do
    output = diagram(title: "2026 Header").to_svg
    css = REXML::XPath.first(xml(output), "//style").text
    expect(css).to include('[id="2026-header-diagram"]')
  end

  it "fits multiline labels and reports last-resort truncation" do
    source = diagram([{ name: "CWR", bits: 1 }, { name: "Rest", bits: 31 }])
    root = xml(source.to_svg)
    expect(REXML::XPath.match(root, "//tspan").map(&:text)).to include("C", "W", "R")
    source.to_svg(fit_order: ["truncate"])
    expect(source.issues.map(&:code)).to include("V-09")
  end

  %w[udp tcp ipv4 ipv6 icmp arp].each do |preset|
    it "matches the #{preset} SVG golden" do
      output = Bitgram.preset(preset).to_svg
      path = File.expand_path("../../fixtures/golden/#{preset}.svg", __dir__)
      File.write(path, output) if ENV["UPDATE_GOLDEN"] == "1"
      expect(output).to eq(File.read(path))
    end
  end

  { "theme_dark" => { theme: "dark" }, "inline_styles" => { inline_styles: true } }.each do |name, options|
    it "matches the #{name} SVG golden" do
      output = diagram.to_svg(**options)
      path = File.expand_path("../../fixtures/golden/#{name}.svg", __dir__)
      File.write(path, output) if ENV["UPDATE_GOLDEN"] == "1"
      expect(output).to eq(File.read(path))
    end
  end
end
