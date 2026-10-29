# frozen_string_literal: true

require "spec_helper"
require "bitgram/layout/engine"

RSpec.describe Bitgram::Layout::Engine do
  def layout_for(lengths, **layout)
    fields = lengths.map.with_index do |length, index|
      { "name" => "Field #{index}", **(length.is_a?(Hash) ? length : { "bits" => length }) }
    end
    Bitgram.load({ "version" => 1, "layout" => layout.transform_keys(&:to_s), "fields" => fields }).layout
  end

  it "places whole fields into successive rows" do
    result = layout_for([16, 16, 16, 16])
    expect(result.rows.map(&:offset_bits)).to eq([0, 32])
    expect(result.rows.map { |row| row.cells.map(&:col) }).to eq([[0, 16], [0, 16]])
    expect(result.rows.flat_map(&:cells).map(&:part)).to all(eq(:whole))
  end

  it "splits fields at a row boundary with relative ranges" do
    result = layout_for([8, 8, 48])
    expect(result.rows.map { |row| row.cells.map(&:bits) }).to eq([[8, 8, 16], [32]])
    expect(result.rows.last.cells.first.range).to eq(16...48)
    expect(result.cell_label(result.rows.last.cells.first)).to eq("Field 2 [16:47]")
  end

  it "keeps the final partial row" do
    result = layout_for([48])
    expect(result.rows.map { |row| row.cells.first.bits }).to eq([32, 16])
    expect(result.rows.map { |row| row.cells.first.part }).to eq(%i[head tail])
  end

  it "merges aligned multiples into one block and can disable merging" do
    merged = layout_for([128])
    expect(merged.rows.map(&:kind)).to eq([:block])
    expect(merged.rows.first.span).to eq(4)
    split = layout_for([128], merge_rows: false)
    expect(split.rows.map { |row| row.cells.first.part }).to eq(%i[head middle middle tail])
  end

  it "packs explicit variable widths and loses offsets after them" do
    variable = { "bits" => "variable", "display_bits" => 24 }
    result = layout_for([8, variable, 32])
    expect(result.rows.map(&:offset_bits)).to eq([0, nil])
    expect(result.rows.first.cells.last.range).to be_nil
    expect(layout_for([variable, { "bits" => "variable", "display_bits" => 8 }]).rows.size).to eq(1)
  end

  it "retains the known starting offset of a full variable row" do
    result = layout_for([32, "variable", 32])
    expect(result.rows.map(&:kind)).to eq(%i[normal variable normal])
    expect(result.rows.map(&:offset_bits)).to eq([0, 32, nil])
  end

  it "supports alternate row widths and label policies" do
    result = layout_for([4, 4, 16], row_bits: 8, merge_rows: false, split_label: "first")
    expect(result.rows.size).to eq(3)
    expect(result.cell_label(result.rows.last.cells.first)).to eq("(cont.)")
    repeated = layout_for([48], split_label: "repeat", bit_order: "lsb0")
    expect(repeated.cell_label(repeated.rows.last.cells.first)).to eq("Field 0")
  end

  it "formats decimal, hexadecimal and non-byte offsets" do
    result = layout_for([32, 32], offsets: "hex")
    expect(result.rows.map { |row| result.offset_label(row) }).to eq(%w[0x00 0x04])
    bits = layout_for([12, 12], row_bits: 12, offsets: "dec")
    expect(bits.rows.map { |row| bits.offset_label(row) }).to eq(%w[0 12b])
  end

  it "preserves widths, order and offsets for 1,000 seeded random definitions" do
    random = Random.new(20_261_029)
    1_000.times do
      width = [8, 16, 32, 64].sample(random: random)
      lengths = Array.new(random.rand(1..30)) { random.rand(1..(width * 3)) }
      result = layout_for(lengths, row_bits: width, allow_partial_row: true)
      cells = result.rows.flat_map(&:cells)
      expect(cells.map { |cell| cell.field.id }.chunk(&:itself).map(&:first)).to eq(result.document.fields.map(&:id))
      result.rows.each_with_index do |row, index|
        expect(row.cells.first.col).to eq(0)
        row.cells.each_cons(2) { |left, right| expect(left.col + left.bits).to eq(right.col) }
        expect(row.cells.sum(&:bits)).to(index == result.rows.size - 1 ? be <= width : eq(width))
        expect(row.span).to be >= (row.kind == :block ? 2 : 1)
      end
      result.document.fields.each do |field|
        total = result.rows.sum do |row|
          row.cells.select { |cell| cell.field == field }.sum { |cell| cell.bits * row.span }
        end
        expect(total).to eq(field.width_bits)
      end
    end
  end
end
