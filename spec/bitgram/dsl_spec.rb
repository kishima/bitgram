# frozen_string_literal: true

RSpec.describe "Ruby DSL" do
  it "builds definitions through the normal validation pipeline" do
    expect(Bitgram.respond_to?(:define)).to be true
    diagram = Bitgram.define(title: "CTRL") do
      row_bits 16
      bit_order :lsb0
      field "EN", bits: 1, description: "Enable"
      field "MODE", bits: 3
      reserved 4
      field "DIV", bits: 8
      variable "Data"
    end
    document = diagram.layout.document
    expect(document.title).to eq("CTRL")
    expect(document.layout["row_bits"]).to eq(16)
    expect(document.layout["bit_order"]).to eq("lsb0")
    expect(document.fields[2].reserved).to be true
    expect(document.fields.last.variable?).to be true
  end

  it "matches the equivalent YAML model" do
    diagram = Bitgram.define(title: "UDP Header") do
      field "Source Port", bits: 16
      field "Destination Port", bits: 16
      field "Length", bits: 16
      field "Checksum", bits: 16
      variable "Data"
    end
    expect(diagram.to_ascii).to eq(Bitgram.preset(:udp).to_ascii)
  end

  it "reports field errors as Issues" do
    expect { Bitgram.define { field "bad", bits: 0 } }.to raise_error(Bitgram::ValidationError) { |error|
      expect(error.issues.map(&:path)).to include("$.fields[0].bits")
    }
  end
end
