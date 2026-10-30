# frozen_string_literal: true

require "spec_helper"
require "rexml/document"
require "bitgram/renderers/svg/leaders"

RSpec.describe "SVG names of narrow fields" do
  # struct RBasic in mruby, listed from the least significant bit as C declares it.
  def header(fit_order, **svg)
    Bitgram.load({ version: 1, layout: { row_bits: 32, bit_order: "lsb0", field_order: "lsb_first" },
                   svg: { fit_order: fit_order, **svg },
                   fields: [{ name: "tt", bits: 8 }, { name: "gc_color", bits: 3 }, { name: "frozen", bits: 1 },
                            { name: "flags", bits: 20 }] })
  end

  def root(diagram, **options)
    REXML::Document.new(diagram.to_svg(**options)).root
  end

  def field_texts(root, field_id)
    REXML::XPath.match(root, "//g[@data-field-id='#{field_id}']/text")
  end

  it "leader: hangs the name below the row from a line at the middle of the cell" do
    plain = root(header(%w[single shrink truncate]))
    svg = root(header(%w[single shrink leader truncate]))
    expect(field_texts(svg, "frozen")).to be_empty
    line = REXML::XPath.first(svg, "//line[@class='bg-leader']")
    label = REXML::XPath.first(svg, "//text[contains(@class, 'bg-leader-label')]")
    expect(label.text).to eq("frozen")
    # frozen is column 20 (bit 11): 16 margin + 20.5 * 20 bit_width.
    expect([line.attributes["x1"], line.attributes["x2"]]).to eq(%w[426 426])
    expect(line.attributes["y1"].to_f).to be < line.attributes["y2"].to_f
    expect(label.attributes["y"].to_f).to be > line.attributes["y2"].to_f
    # One level below the row: leader_gap 8 plus one line of 13 * 1.2.
    expect(svg.attributes["height"].to_f - plain.attributes["height"].to_f).to be_within(0.01).of(8 + 15.6)
    gap = REXML::XPath.first(root(header(%w[single shrink leader truncate], leader_gap: 2)),
                             "//line[@class='bg-leader']")
    expect(gap.attributes["y2"].to_f - gap.attributes["y1"].to_f).to eq(2)
  end

  it "rotate: turns the name and grows the row to its length" do
    svg = root(header(%w[single shrink rotate truncate]))
    text = field_texts(svg, "frozen").first
    expect(text.text).to eq("frozen")
    expect(text.attributes["transform"]).to start_with("rotate(-90 ")
    # The line height must fit the 12px inside a 20px cell, so 13px shrinks to 12px.
    expect(text.attributes["font-size"]).to eq("12")
    rect = REXML::XPath.first(svg, "//g[@data-field-id='frozen']/rect")
    # 6 characters * 12px * 0.6 + 8 padding = 51.2, above the 36px row_height.
    expect(rect.attributes["height"]).to eq("51.2")
  end

  it "footnote_shrink: keeps the marker on one line and lists the footnote" do
    svg = root(header(%w[single shrink footnote_shrink truncate]))
    text = field_texts(svg, "frozen").first
    expect(text.text).to eq("*1")
    expect(text.attributes["font-size"]).to eq("10")
    expect(REXML::XPath.match(svg, "//g[@class='bg-footnotes']/text").map(&:text)).to eq(["*1: frozen"])
    # The plain footnote strategy splits the same marker over two lines.
    old = root(header(%w[single shrink footnote truncate]))
    expect(REXML::XPath.match(old, "//g[@data-field-id='frozen']//tspan").map(&:text)).to eq(["*", "1"])
  end

  it "falls through when a strategy does not fit, and ASCII ignores the SVG-only strategies" do
    fitter = Bitgram::Text::Fitter.new(measurer: Bitgram::Text::AsciiMeasurer.new)
    expect(fitter.fit(text: "frozen", inner_width: 1, order: %w[rotate leader footnote_shrink truncate]).strategy)
      .to eq(:truncate)
    measurer = Bitgram::Text::SvgMeasurer.new(font_size: 13, ratio: 0.6)
    svg_fitter = Bitgram::Text::Fitter.new(measurer: measurer, font_size: 13, min_font_size: 9)
    expect(svg_fitter.fit(text: "frozen", inner_width: 8, order: %w[rotate footnote_shrink leader]).strategy)
      .to eq(:leader)
  end

  it "keeps values inside the cell when the name hangs below" do
    diagram = Bitgram.load({ version: 1, svg: { fit_order: %w[single leader truncate] },
                             fields: [{ name: "flags", bits: 2, value: 1 }, { name: "rest", bits: 30 }] })
    svg = root(diagram)
    expect(field_texts(svg, "flags").map(&:text)).to eq(["= 1"])
    expect(REXML::XPath.first(svg, "//text[contains(@class, 'bg-leader-label')]").text).to eq("flags")
  end

  def expect_no_crossing(labels)
    labels.each do |label|
      labels.each do |other|
        next if other.equal?(label)

        expect(other.left < label.right && label.left < other.right).to be(false) if other.level == label.level
        expect(label.line_x.between?(other.left, other.right)).to be(false) if other.level < label.level
      end
    end
  end

  it "places neighboring leader names on separate levels without crossing lines" do
    leaders = Bitgram::Renderers::Svg::Leaders
    # Two 40px names on lines 20px apart at the left edge: the right one must stay above.
    pair = leaders.place([[10, "a", 40, 13], [30, "b", 40, 13]], right: 640, space: 4)
    expect_no_crossing(pair)
    expect(pair.map(&:level)).to eq([1, 0])
    # The same at the right edge, and three names in the middle.
    expect_no_crossing(leaders.place([[610, "a", 40, 13], [630, "b", 40, 13]], right: 640, space: 4))
    trio = leaders.place([[300, "a", 30, 13], [320, "b", 30, 13], [340, "c", 30, 13]], right: 640, space: 4)
    expect_no_crossing(trio)
    expect(trio.map(&:level).uniq.size).to be > 1
    edge = leaders.place([[630, "name", 40, 13]], right: 640, space: 4).first
    expect(edge.right).to be <= 640
  end

  it "turns ligatures off with svg.ligatures: false, in CSS and inline styles" do
    diagram = header(%w[single shrink footnote truncate])
    expect(diagram.to_svg).not_to include("font-variant-ligatures")
    off = header(%w[single shrink footnote truncate], ligatures: false)
    expect(off.to_svg).to include("font-variant-ligatures: none;")
    inline = REXML::Document.new(off.to_svg(inline_styles: true)).root
    expect(REXML::XPath.match(inline, "//text").map { |text| text.attributes["style"] })
      .to all(eq("font-variant-ligatures: none"))
  end
end
