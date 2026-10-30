# frozen_string_literal: true

require "spec_helper"
require "rexml/document"

RSpec.describe "Per-field bit_numbers" do
  # Word Boxing in mruby (include/mruby/boxing_word.h): the upper bits drawn as one "…" cell,
  # then the low 8 bits one by one, in two rows.
  let(:rows) do
    [%w[0 0 0 0 0 0 0 0], %w[0 0 0 0 0 1 0 0]].flat_map do |bits|
      bits.map { |bit| { name: bit, bits: 1 } }.unshift({ name: "…", bits: 2, bit_numbers: false })
    end
  end
  let(:definition) do
    { version: 1, layout: { row_bits: 10, bit_order: "lsb0", row_labels: %w[nil false] }, fields: rows }
  end

  def root(data, **options)
    REXML::Document.new(Bitgram.load(data).to_svg(**options)).root
  end

  def numbers(svg)
    REXML::XPath.match(svg, "//text[@class='bg-bit-number']").map(&:text)
  end

  def tick_xs(svg)
    REXML::XPath.match(svg, "//g[@class='bg-row']").map do |row|
      REXML::XPath.match(row, "line[@class='bg-tick']").map { |line| line.attributes["x1"].to_f }
    end
  end

  it "leaves out the numbers above the field and the ticks inside it" do
    svg = root(definition)
    expect(numbers(svg)).to eq(%w[7 6 5 4 3 2 1 0])
    # The default draws all ten numbers and the nine boundaries 1..9 in each row.
    plain = root(definition.merge(fields: rows.map { |field| field.except(:bit_numbers) }))
    expect(numbers(plain)).to eq(%w[9 8 7 6 5 4 3 2 1 0])
    expect(tick_xs(plain).map(&:size)).to eq([9, 9])
    # Boundary 1 (inside "…") is gone in both rows; 2..9 remain. bit_width is 20 by default.
    left = tick_xs(plain).first.min - 20
    expect(tick_xs(svg).map { |xs| xs.map { |x| ((x - left) / 20).round } }).to eq([(2..9).to_a] * 2)
    # The line of numbers keeps its height.
    expect(svg.attributes["height"]).to eq(plain.attributes["height"])
  end

  it "follows the field in the first row only for the numbers, and in every row for the ticks" do
    fields = [{ name: "A", bits: 4 }, { name: "B", bits: 4, bit_numbers: false }, { name: "C", bits: 8 }]
    svg = root({ version: 1, layout: { row_bits: 8 }, fields: fields })
    expect(numbers(svg)).to eq(%w[0 1 2 3])
    expect(tick_xs(svg).map(&:size)).to eq([4, 7])
    second = root({ version: 1, layout: { row_bits: 8 }, fields: [fields[2], fields[0], fields[1]] })
    expect(numbers(second)).to eq(%w[0 1 2 3 4 5 6 7])
    expect(tick_xs(second).map(&:size)).to eq([7, 4])
  end

  it "leaves out the same numbers in ASCII" do
    header = Bitgram.load(definition).to_ascii.lines.first(2).map(&:rstrip)
    expect(header.last.split).to eq(%w[7 6 5 4 3 2 1 0])
    expect(header.last.index("7")).to eq(Bitgram.load(definition.merge(fields: rows.map do |field|
      field.except(:bit_numbers)
    end)).to_ascii.lines[1].index("7"))
  end

  it "keeps the ids of untitled diagrams that do not use it, and rejects a non-boolean" do
    base = { version: 1, fields: [{ name: "A", bits: 32 }] }
    # The id upstream eeb5ae3 gives this definition (docs/worklog/2026-10-30-book-b1-b3.md).
    expect(Bitgram.load(base).to_svg).to include('id="bitgram-408ce7c0-diagram"')
    expect(Bitgram.load(version: 1, fields: [{ name: "A", bits: 32, bit_numbers: true }]).to_svg)
      .to include('id="bitgram-408ce7c0-diagram"')
    expect(Bitgram.load(version: 1, fields: [{ name: "A", bits: 32, bit_numbers: false }]).to_svg)
      .not_to include('id="bitgram-408ce7c0-diagram"')
    expect { Bitgram.load(version: 1, fields: [{ name: "A", bits: 32, bit_numbers: "no" }]) }
      .to raise_error(Bitgram::ValidationError)
  end
end
