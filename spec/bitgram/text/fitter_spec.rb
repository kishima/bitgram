# frozen_string_literal: true

require "spec_helper"
require "bitgram/text/fitter"
require "timeout"

RSpec.describe Bitgram::Text::Fitter do
  let(:order) { %w[single wrap short vertical footnote truncate] }
  let(:fitter) { described_class.new(measurer: Bitgram::Text::AsciiMeasurer.new) }

  def fit_label(text, width, **options)
    fitter.fit(text: text, inner_width: width, order: order, **options)
  end

  it "fits ordinary labels without changing them" do
    expect(fit_label("Source Port", 31).lines).to eq(["Source Port"])
    expect(fit_label("Source Port", 31).strategy).to eq(:single)
  end

  it "wraps words and CJK characters without splitting Latin words" do
    expect(fit_label("Data Offset", 7).lines).to eq(%w[Data Offset])
    expect(fit_label("送信元ポート", 7).lines).to eq(%w[送信元 ポート])
    expect(fit_label("Acknowledgment", 7, short: "Ack").strategy).to eq(:short)
  end

  it "uses vertical Latin labels and footnotes for too-wide Japanese characters" do
    expect(fit_label("CWR", 1).lines).to eq(%w[C W R])
    result = fit_label("送信元ポート", 1, description: "Source port")
    expect(result.strategy).to eq(:footnote)
    expect(result.lines).to eq(["*", "1"])
    expect(fitter.footnotes).to eq(["*1: Source port"])
  end

  it "truncates and reports V-09 only as the last resort" do
    result = fitter.fit(text: "VeryLongIdentifierName", inner_width: 5, order: %w[single truncate])
    expect(result.lines).to eq(["Very…"])
    expect(fitter.issues.map(&:code)).to eq(["V-09"])
  end

  it "shrinks SVG labels in half-pixel steps" do
    measurer = Bitgram::Text::SvgMeasurer.new(font_size: 13, ratio: 0.6)
    svg_fitter = described_class.new(measurer: measurer, font_size: 13, min_font_size: 9)
    result = svg_fitter.fit(text: "Source Port", inner_width: 72, order: %w[single shrink wrap])
    expect(result.strategy).to eq(:shrink)
    expect(result.font_size).to eq(10.5)
  end

  it "counts graphemes and respects ambiguous character width" do
    expect(Bitgram::Text::AsciiMeasurer.new.width("e\u0301")).to eq(1)
    expect(Bitgram::Text::AsciiMeasurer.new(ambiguous: 2).width("α")).to eq(2)
    expect(fit_label("A B", 1).lines).to eq(%w[A B])
  end

  it "keeps punctuation off the start of wrapped CJK lines" do
    result = fit_label("送信元、宛先。", 6)
    expect(result.lines).to eq(["送信", "元、宛", "先。"])
    expect(result.lines).to all(satisfy { |line| !line.match?(/\A[、。]/) })
  end

  it "supports explicit strategy order and custom numbered footnotes" do
    first = fitter.fit(text: "Very long name", short: "Short", inner_width: 5, order: %w[short single])
    expect(first.lines).to eq(["Short"])
    custom = described_class.new(measurer: Bitgram::Text::AsciiMeasurer.new, footnote_marker: "[{n}]")
    2.times { custom.fit(text: "長い名前", inner_width: 3, order: %w[footnote]) }
    expect(custom.footnotes).to eq(["[1]: 長い名前", "[2]: 長い名前"])
  end

  it "handles a marker or ellipsis wider than the cell" do
    wide = described_class.new(measurer: Bitgram::Text::AsciiMeasurer.new(ambiguous: 2), footnote_marker: "注{n}")
    fitted = wide.fit(text: "長い名前", inner_width: 1, order: %w[footnote truncate])
    expect(fitted.lines).to eq([""])
    expect(wide.footnotes).to be_empty
    expect(wide.issues.first.code).to eq("V-09")
  end

  it "normalizes whitespace in short labels and footnote markers" do
    short = fitter.fit(text: "Very long name", short: "A\nB", inner_width: 3, order: %w[short])
    expect(short.lines).to eq(["A B"])
    custom = described_class.new(measurer: Bitgram::Text::AsciiMeasurer.new, footnote_marker: "*\n{n}")
    marker = custom.fit(text: "Long name", inner_width: 3, order: %w[footnote])
    expect(marker.lines).to eq(["* 1"])
  end

  it "truncates a large fixed value without repeatedly measuring the entire value" do
    diagram = Bitgram.load(version: 1, ascii: { fit_order: ["truncate"] },
                           fields: [{ name: "A", bits: 32, value: "X" * 100_000 }])
    output = Timeout.timeout(1) { diagram.to_ascii }
    expect(output.lines[3].chomp).to eq("|A (=#{'X' * 58}…|")
  end

  it "preserves complete graphemes when truncating" do
    result = fitter.fit(text: "e\u0301👩‍💻日本語", inner_width: 4, order: ["truncate"])
    expect(result.lines).to eq(["e\u0301👩‍💻…"])
  end

  it "retains SVG characters at the exact fractional width boundary" do
    measurer = Bitgram::Text::SvgMeasurer.new(font_size: 13, ratio: 0.6)
    svg_fitter = described_class.new(measurer: measurer)
    result = svg_fitter.fit(text: "abcdef", inner_width: 39, order: ["truncate"])
    expect(result.lines).to eq(["abcd…"])
  end

  it "handles long zero-width prefixes in linear time" do
    prefix = "\u200b" * 20_000
    result = Timeout.timeout(1) { fitter.fit(text: "#{prefix}ABCDE", inner_width: 4, order: ["truncate"]) }
    expect(result.lines).to eq(["#{prefix}ABC…"])
  end
end
