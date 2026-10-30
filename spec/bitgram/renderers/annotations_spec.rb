# frozen_string_literal: true

require "spec_helper"
require "rexml/document"
require "json_schemer"
require "pathname"

RSpec.describe "Annotation lines and row labels" do
  # The operand of OP_ENTER (include/mruby/proc.h, MRB_ASPEC_*), for
  # def f1(a, b, c = 1, *rest, d, k: 2, **kw, &blk) -> ENTER 2:1:1:1:1:1:1:0 (0x83087).
  let(:enter) do
    { version: 1, title: "ENTER",
      layout: { row_bits: 24, bit_order: "lsb0", row_labels: ["欄"], bit_numbers_label: "bit" },
      fields: [{ name: "n", bits: 1 }, { name: "m1", bits: 5 }, { name: "o", bits: 5 }, { name: "r", bits: 1 },
               { name: "m2", bits: 5 }, { name: "k", bits: 5 }, { name: "d", bits: 1 }, { name: "b", bits: 1 }],
      annotations: [
        { label: "例のビット列", per_bit: true,
          values: { n: "0", m1: "00010", o: "00001", r: "1", m2: "00001", k: "00001", d: "1", b: "1" } },
        { label: "欄の値", fill: "#e6e6e6", values: { n: 0, m1: 2, o: 1, r: 1, m2: 1, k: 1, d: 1, b: 1 } },
        { label: "ダンプの順", style: "plain", values: { m1: 1, o: 2, r: 3, m2: 4, k: 5, d: 6, b: 7, n: 8 } }
      ] }
  end

  def root(definition, **options)
    REXML::Document.new(Bitgram.load(definition).to_svg(**options)).root
  end

  def texts(node, xpath)
    REXML::XPath.match(node, xpath).map(&:text)
  end

  it "draws one line per annotation under the row, with its label on the left" do
    svg = root(enter)
    lines = REXML::XPath.match(svg, "//g[@class='bg-annotation']")
    expect(lines.size).to eq(3)
    expect(texts(lines[0], "text[@class='bg-offset']")).to eq(["例のビット列"])
    expect(texts(lines[0], "text[@class='bg-label']").join).to eq("000010000011000010000111")
    expect(REXML::XPath.match(lines[0], "rect").size).to eq(24)
    expect(texts(lines[1], "text[@class='bg-label']")).to eq(%w[0 2 1 1 1 1 1 1])
    expect(REXML::XPath.match(lines[1], "rect").map { |rect| rect.attributes["fill"] }.uniq).to eq(["#e6e6e6"])
    expect(texts(lines[2], "text[@class='bg-label']")).to eq(%w[8 1 2 3 4 5 6 7])
    expect(REXML::XPath.match(lines[2], "rect")).to be_empty
    # Three lines of row_height 36 below the 36px row.
    plain = root(enter.except(:annotations))
    expect(svg.attributes["height"].to_f - plain.attributes["height"].to_f).to eq(3 * 36)
  end

  it "puts row labels and the bit-number label in the left-hand column" do
    svg = root(enter)
    expect(texts(svg, "//g[@class='bg-row']/text[@class='bg-offset']")).to eq(["欄"])
    expect(texts(svg, "//text[contains(@class, 'bg-bit-numbers-label')]")).to eq(["bit"])
    labels = Bitgram.load(version: 1, layout: { row_bits: 8, offsets: "dec", row_labels: ["first"] },
                          fields: [{ name: "A", bits: 8 }, { name: "B", bits: 8 }]).to_ascii
    # A row without a label keeps its offset.
    expect(labels.lines.grep(/A|B/).map { |line| line.split("|").first.strip }).to eq(%w[first 1])
  end

  it "takes per_bit characters for each piece of a field split over rows" do
    pieces = lambda do |order|
      definition = { version: 1, layout: { row_bits: 4, field_order: order, allow_partial_row: true },
                     fields: [{ name: "x", bits: 6 }],
                     annotations: [{ per_bit: true, values: { x: "abcdef" } }] }
      REXML::XPath.match(root(definition), "//g[@class='bg-annotation']").map do |line|
        texts(line, "text[@class='bg-label']").join
      end
    end
    # msb_first: the first row holds the most significant bits.
    expect(pieces.call("msb_first")).to eq(%w[abcd ef])
    # lsb_first: the first row holds the least significant bits, drawn at its right edge.
    expect(pieces.call("lsb_first")).to eq(%w[cdef ab])
  end

  it "writes annotation lines in ASCII without borders" do
    ascii = Bitgram.load(enter).to_ascii
    expect(ascii).to include("例のビット列  0 0 0 0 1 0 0 0 0 0 1 1 0 0 0 0 1 0 0 0 0 1 1 1")
    expect(ascii).to include("bit  3 2 1 0")
    expect(ascii.lines.grep(/ダンプの順/).first).to match(/ダンプの順  8 +1 +2 +3 +4 +5 +6 7$/)
  end

  it "rejects unknown field ids and per_bit values of the wrong length" do
    bad = enter.merge(annotations: [{ values: { zz: 1 } }, { per_bit: true, values: { m1: "01" } }])
    issues = Bitgram::Validator.new.call(Bitgram::Config.stringify(bad))
    expect(issues.map { |issue| [issue.code, issue.path] })
      .to eq([["V-03", "$.annotations[0].values.zz"], ["V-03", "$.annotations[1].values.m1"]])
    expect(issues.last.message).to include("5 characters")
    expect { Bitgram.load(bad) }.to raise_error(Bitgram::ValidationError)
    # Ids made from names count as well.
    named = { version: 1, fields: [{ name: "Source Port", bits: 32 }],
              annotations: [{ values: { "source-port" => 1 } }] }
    expect(Bitgram::Validator.new.call(Bitgram::Config.stringify(named))).to be_empty
  end

  it "agrees with the JSON schema on the shape of annotations" do
    schema = JSONSchemer.schema(Pathname("schema/bitgram.schema.json"))
    good = Bitgram::Config.stringify(enter)
    expect(schema.valid?(good)).to be(true)
    [{ "annotations" => [{ "label" => "x" }] }, { "annotations" => [{ "values" => { "Bad Key" => 1 } }] },
     { "annotations" => [{ "values" => { "n" => true } }] }, { "annotations" => [{ "values" => {}, "style" => "x" }] },
     { "layout" => { "row_labels" => [1] } }].each do |change|
      data = good.merge(change)
      errors = Bitgram::Validator.new.call(data).select { |issue| issue.severity == :error }
      expect([schema.valid?(data), errors.empty?]).to eq([false, false])
    end
  end

  it "keeps the ids of untitled diagrams without annotations, and changes them with annotations" do
    base = { version: 1, fields: [{ name: "A", bits: 32 }] }
    # The id upstream eeb5ae3 gives this definition (docs/worklog/2026-10-30-book-b1-b3.md).
    expect(Bitgram.load(base).to_svg).to include('id="bitgram-408ce7c0-diagram"')
    expect(Bitgram.load(base.merge(annotations: [{ values: { a: 1 } }])).to_svg)
      .not_to include('id="bitgram-408ce7c0-diagram"')
  end
end
