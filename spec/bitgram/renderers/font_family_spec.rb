# frozen_string_literal: true

require "spec_helper"
require "bitgram/renderers/svg"

RSpec.describe "SVG font-family quoting" do
  def css(value)
    Bitgram::Renderers::Svg::FontFamily.css(value)
  end

  it "quotes names with a word that is not a CSS identifier" do
    expect(css("M PLUS 1p")).to eq("'M PLUS 1p'")
    expect(css("M PLUS 1p, sans-serif")).to eq("'M PLUS 1p', sans-serif")
    expect(css("1942 report")).to eq("'1942 report'")
  end

  it "keeps quoted names, identifier sequences and generic families as written" do
    expect(css("'M PLUS 1p'")).to eq("'M PLUS 1p'")
    expect(css('"M PLUS 1p", serif')).to eq('"M PLUS 1p", serif')
    expect(css("Helvetica, Arial, 'Noto Sans CJK JP', sans-serif"))
      .to eq("Helvetica, Arial, 'Noto Sans CJK JP', sans-serif")
    expect(css("Noto Sans, monospace")).to eq("Noto Sans, monospace")
  end

  it "does not split at commas inside quotes and escapes embedded quotes" do
    expect(css("'A, B', C")).to eq("'A, B', C")
    expect(css("O'Neil 2, Arial")).to eq("'O\\'Neil 2', Arial")
  end

  it "writes the quoted name into both the style sheet and inline attributes" do
    diagram = Bitgram.load({ version: 1, fields: [{ name: "A", bits: 32 }], svg: { font_family: "M PLUS 1p" } })
    expect(diagram.to_svg).to include("font-family: &apos;M PLUS 1p&apos;;")
    expect(diagram.to_svg(inline_styles: true)).to include('font-family="&apos;M PLUS 1p&apos;"')
  end
end
