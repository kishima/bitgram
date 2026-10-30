# frozen_string_literal: true

require "spec_helper"
require "rexml/document"

RSpec.describe "layout.field_order" do
  # struct RBasic in mruby: enum mrb_vtype tt:8; unsigned int gc_color:3; frozen:1; flags:20
  let(:header) do
    { version: 1, layout: { row_bits: 32, bit_order: "lsb0", field_order: "lsb_first" },
      fields: [{ name: "tt", bits: 8 }, { name: "gc_color", bits: 3 }, { name: "frozen", bits: 1 },
               { name: "flags", bits: 20 }] }
  end

  def columns(result)
    result.rows.map { |row| row.cells.map { |cell| [cell.field.name, cell.col, cell.bits] } }
  end

  it "keeps declaration order left to right by default" do
    result = Bitgram.load(header.merge(layout: { row_bits: 32 })).layout
    expect(columns(result)).to eq([[["tt", 0, 8], ["gc_color", 8, 3], ["frozen", 11, 1], ["flags", 12, 20]]])
  end

  it "places the first field at the least significant bits with lsb_first" do
    result = Bitgram.load(header).layout
    expect(columns(result)).to eq([[["flags", 0, 20], ["frozen", 20, 1], ["gc_color", 21, 3], ["tt", 24, 8]]])
    # With lsb0 numbering, column c shows bit 31 - c, so tt covers bits 7..0 at the right edge.
    tt = result.rows.first.cells.last
    expect((tt.col...(tt.col + tt.bits)).map { |col| 31 - col }).to eq([7, 6, 5, 4, 3, 2, 1, 0])
  end

  it "draws tt at the right edge of the SVG under bit numbers 7 to 0" do
    root = REXML::Document.new(Bitgram.load(header).to_svg).root
    rect = REXML::XPath.first(root, "//g[@data-field-id='tt']/rect")
    numbers = REXML::XPath.match(root, "//g[@class='bg-bit-numbers']/text")
    left = rect.attributes["x"].to_f
    right = left + rect.attributes["width"].to_f
    inside = numbers.select { |text| text.attributes["x"].to_f.between?(left, right) }.map(&:text)
    expect(inside).to eq(%w[7 6 5 4 3 2 1 0])
  end

  it "fills rows in declaration order and mirrors each row, splitting across rows" do
    result = Bitgram.load(version: 1, layout: { row_bits: 8, field_order: "lsb_first" },
                          fields: [{ name: "a", bits: 4 }, { name: "b", bits: 8 }, { name: "c", bits: 4 }]).layout
    expect(columns(result)).to eq([[["b", 0, 4], ["a", 4, 4]], [["c", 0, 4], ["b", 4, 4]]])
    expect(result.rows.map(&:offset_bits)).to eq([0, 8])
    expect(result.rows.first.cells.first.range).to eq(0...4)
  end

  it "leaves the gap of a partial last row on the left in SVG and ASCII" do
    diagram = Bitgram.load(version: 1, layout: { row_bits: 8, field_order: "lsb_first", allow_partial_row: true },
                           fields: [{ name: "a", bits: 4 }, { name: "b", bits: 2 }])
    expect(columns(diagram.layout)).to eq([[["b", 2, 2], ["a", 4, 4]]])
    expect(diagram.to_ascii).to eq(<<~TEXT)
       0
       0 1 2 3 4 5 6 7
      +-+-+-+-+-+-+-+-+
      |   | b |   a   |
      +-+-+-+-+-+-+-+-+
    TEXT
    root = REXML::Document.new(diagram.to_svg(margin: 0)).root
    xs = %w[b a].map { |id| REXML::XPath.first(root, "//g[@data-field-id='#{id}']/rect").attributes["x"].to_f }
    expect(xs).to eq([2 * 20, 4 * 20])
  end

  it "rejects unknown orders" do
    issues = Bitgram::Validator.new.call({ "version" => 1, "layout" => { "field_order" => "reverse" },
                                           "fields" => [{ "name" => "A", "bits" => 32 }] })
    expect(issues.map { |issue| [issue.code, issue.path] }).to include(["V-03", "$.layout.field_order"])
  end
end
