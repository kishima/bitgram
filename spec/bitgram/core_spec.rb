# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "timeout"

RSpec.describe "Loading and validation" do
  let(:definition) { { "version" => 1, "fields" => [{ "name" => "A", "bits" => 32 }] } }

  it "rejects hostile unknown-key paths without looping" do
    definition["["] = 1
    expect { Timeout.timeout(1) { Bitgram.load(definition) } }.to raise_error(Bitgram::ValidationError)
    expect { Timeout.timeout(1) { Bitgram.load(JSON.generate(definition)) } }.to raise_error(Bitgram::ValidationError)
  end

  it "reports invalid encodings and XML characters as validation issues" do
    definition["fields"].first["id"] = "\xff".dup.force_encoding("UTF-8")
    expect { Bitgram.load(definition) }.to raise_error(Bitgram::ValidationError)
    definition["fields"].first.delete("id")
    definition["fields"].first["name"] = "A\uFFFF"
    expect { Bitgram.load(definition) }.to raise_error(Bitgram::ValidationError)
  end

  it "normalizes binary UTF-8 strings in Hash inputs" do
    definition["fields"].first["name"] = "日本語".b
    expect(Bitgram.load(definition).to_ascii).to include("日本語")
  end

  it "stops validating oversized field arrays after reporting their resource limit" do
    definition["fields"] = Array.new(10_001)
    expect { Bitgram.load(definition) }.to raise_error(Bitgram::ValidationError) { |error|
      expect(error.issues.size).to eq(1)
      expect(error.issues.first.code).to eq("V-07")
    }
  end

  it "loads hashes, JSON, and YAML to equal immutable documents" do
    expect(Bitgram).to respond_to(:load)
    hash = Bitgram.load(definition).layout.document
    expect(Bitgram.load(JSON.generate(definition)).layout.document).to eq(hash)
    expect(Bitgram.load(YAML.dump(definition)).layout.document).to eq(hash)
    expect(hash.fields.first.name).to be_frozen
    expect(hash.layout).to be_frozen
    expect(definition).not_to be_frozen
  end

  it "reports every invalid key and value with YAML paths and lines" do
    expect(Bitgram).to respond_to(:load)
    expect do
      Bitgram.load("version: 2\nfields:\n  - name: A\n    bitz: 2\n")
    end.to raise_error(Bitgram::ValidationError) { |e|
             expect(e.issues.map(&:code)).to include("V-01",
                                                     "V-02", "V-04")
             expect(e.issues.find { |i|
               i.code == "V-02"
             }.message).to include("bits")
             expect(e.issues.map(&:line)).to all(be_a(Integer))
           }
  end

  it "normalizes bytes, symbol keys, variable fields, and collision-free IDs" do
    expect(Bitgram).to respond_to(:load)
    fields = Bitgram.load(version: 1, fields: [
                            { name: "A", bytes: 4 }, { name: "A", bits: 32, id: "a" },
                            { name: "日本語", bits: :variable }
                          ]).layout.document.fields
    expect(fields.map(&:id)).to eq(%w[a-2 a field-3])
    expect(fields.first.bits).to eq(32)
    expect(fields.last).to be_variable
  end

  it "rejects YAML aliases, objects, excessive nesting, and oversized input" do
    expect(Bitgram).to respond_to(:load)
    ["--- !ruby/object:Object {}", "a: &a []\nb: *a", ("[" * 25) + ("]" * 25), " " * 1_048_577].each do |input|
      expect { Bitgram.load(input) }.to raise_error(Bitgram::ParseError)
    end
  end

  it "rejects cycles without changing the caller's input" do
    expect(Bitgram).to respond_to(:load)
    definition["cycle"] = definition
    expect { Bitgram.load(definition) }.to raise_error(Bitgram::ParseError)
  end

  it "warns for partial rows and validates variable alignment and row limits" do
    expect(Bitgram).to respond_to(:load)
    definition["fields"][0]["bits"] = 8
    expect(Bitgram.load(definition).issues.map(&:code)).to include("V-08")
    definition["fields"] << { "name" => "Data", "bits" => "variable" }
    expect { Bitgram.load(definition) }.to raise_error(Bitgram::ValidationError) { |e| expect(e.issues.map(&:code)).to include("V-06") }
    definition["fields"] = [{ "name" => "Huge", "bits" => 524_288 }]
    expect { Bitgram.load(definition) }.to raise_error(Bitgram::ValidationError) { |e| expect(e.issues.map(&:code)).to include("V-07") }
  end

  it "validates renderer overrides and unsafe styles" do
    expect(Bitgram).to respond_to(:load)
    diagram = Bitgram.load(definition)
    expect { diagram.to_ascii(indent: -1) }.to raise_error(Bitgram::ValidationError)
    expect { diagram.to_svg(font_family: "a;fill:red") }.to raise_error(Bitgram::ValidationError)
    expect { diagram.to_svg(bit_width: Float::INFINITY) }.to raise_error(Bitgram::ValidationError)
  end

  it "returns parse issues from validate_file instead of raising" do
    expect(Bitgram).to respond_to(:validate_file)
    Tempfile.create(["invalid", ".yml"]) do |file|
      file.write("x: [")
      file.flush
      expect(Bitgram.validate_file(file.path).first.severity).to eq(:error)
    end
  end
end
