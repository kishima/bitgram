# frozen_string_literal: true

require "spec_helper"
require "json_schemer"
require "pathname"

RSpec.describe "Definition schema and validation" do
  let(:schema) { JSONSchemer.schema(Pathname("schema/bitgram.schema.json")) }
  let(:expectations) { YAML.safe_load_file("spec/fixtures/invalid/expectations.yml") }

  Dir["spec/fixtures/{valid,invalid}/*.{yml,json}"].each do |path|
    next if File.basename(path) == "expectations.yml"

    it "validates #{path} with consistent paths and schema results" do
      expected = expectations[File.basename(path)] if path.include?("/invalid/")
      issues = Bitgram.validate_file(path)
      if expected
        expect(issues.map { |issue| [issue.code, issue.path] }).to include(expected.values_at("code", "path"))
      else
        expect(issues).to be_empty
      end
      unless expected && expected["schema"] == "skip"
        raw = Bitgram::Loader.new.load_file(path).data
        expect(schema.valid?(raw)).to eq(issues.none? { |issue| issue.severity == :error })
      end
    end
  end

  it "rejects invalid types and boundaries in every configuration section" do
    base = { "version" => 1, "fields" => [{ "name" => "A", "bits" => 32 }] }
    samples = [
      { "fields" => [] }, { "fields" => [nil] }, { "notes" => [123] }, { "version" => nil },
      { "layout" => { "row_bits" => 0, "merge_rows" => "true" } },
      { "ascii" => { "fit_order" => %w[bogus], "ambiguous_width" => 3 } },
      { "svg" => { "font_family" => "x;fill:red", "id_prefix" => "a\nb" } },
      { "raster" => { "scale" => 9, "timeout" => -1, "quality" => 101 } }
    ]
    samples.each do |sample|
      data = base.merge(sample)
      expect(Bitgram::Validator.new.call(data).map(&:severity)).to include(:error)
      expect(schema.valid?(data)).to be false
    end
  end
end
