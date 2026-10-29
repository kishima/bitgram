# frozen_string_literal: true

require "spec_helper"
require "bitgram/renderers/ascii"
require "unicode/display_width"

RSpec.describe Bitgram::Renderers::Ascii do
  def diagram(fields, **extra)
    Bitgram.load({ "version" => 1, "fields" => fields.map do |name, bits|
      { "name" => name, "bits" => bits }
    end, **extra.transform_keys(&:to_s) })
  end

  it "renders the UDP RFC golden exactly" do
    result = diagram([["Source Port", 16], ["Destination Port", 16], ["Length", 16], ["Checksum", 16],
                      ["Data", "variable"]])
    expected = <<~TEXT
       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |          Source Port          |       Destination Port        |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |            Length             |           Checksum            |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      .                                                               .
      .                             Data                              .
      .                                                               .
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    TEXT
    expect(result.to_ascii).to eq(expected)
  end

  it "selects Unicode junctions from adjacent boundaries" do
    result = diagram([["A", 16], ["B", 16], ["C", 32], %w[Data variable]])
    lines = result.to_ascii(style: :unicode).lines.map(&:chomp)
    expect(lines[2]).to eq("┌#{'─' * 31}┬#{'─' * 31}┐")
    expect(lines[4]).to eq("├#{'─' * 31}┴#{'─' * 31}┤")
    expect(lines[-2]).to eq("┊#{' ' * 29}Data#{' ' * 30}┊")
    expect(lines.last).to eq("└#{'─' * 63}┘")
  end

  it "centres Japanese and vertical flags without changing the grid width" do
    result = diagram([["CWR", 1], ["送信元ポート", 7], ["Data", 24]])
    lines = result.to_ascii.lines.map(&:chomp)
    expect(lines.drop(2).map { |line| Unicode::DisplayWidth.of(line) }).to all(eq(65))
    expect(lines[3]).to start_with("|C|")
    expect(lines[4]).to start_with("|W|")
    expect(lines[5]).to start_with("|R|")
  end

  it "draws a multi-row block with internal side marks" do
    lines = diagram([["Address", 128]]).to_ascii.lines.map(&:chomp)
    expect(lines.size).to eq(11)
    expect(lines[6]).to eq("+#{' ' * 28}Address#{' ' * 28}+")
    expect(lines[4]).to start_with("+")
  end

  it "renders offsets, lsb0, indentation, title and notes" do
    result = diagram([["A", 16], ["B", 16]], title: "Header", notes: ["A note"],
                                             layout: { "row_bits" => 16, "offsets" => "hex", "bit_order" => "lsb0" })
    text = result.to_ascii(indent: 3, title: :top)
    expect(text.lines.first).to eq("   Header\n")
    expect(text).to include("   0x00 |", "   0x02 |", "   A note\n")
    expect(text.lines[2]).to include("5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0")
    expect(text.lines).to all(satisfy { |line| line.chomp == line.rstrip })
  end

  it "uses explicit variable edges and pads partial rows" do
    result = diagram([%w[Data variable]])
    expect(result.to_ascii(variable_edge: :colon)).to include(":#{' ' * 63}:\n")
    expect(result.to_ascii(variable_edge: :slash)).to include("/#{' ' * 63}/\n", "\\#{' ' * 29}Data#{' ' * 30}\\\n")
    expect(diagram([["A", 8]]).to_ascii.lines.last.chomp.size).to eq(65)
  end

  it "indents every physical line of multiline notes" do
    result = diagram([["A", 32]], notes: ["first\nsecond"])
    expect(result.to_ascii(indent: 3)).to end_with("   first\n   second\n")
  end
end
