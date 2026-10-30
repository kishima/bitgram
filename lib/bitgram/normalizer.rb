# frozen_string_literal: true

module Bitgram
  # @api private
  class Normalizer
    def call(raw)
      data = Config.deep_merge(Config::DEFAULTS, Config.stringify(raw))
      ids = Config.field_ids(data.fetch("fields"))
      row_bits = data["layout"]["row_bits"]
      fields = data["fields"].zip(ids).map { |field, field_id| normalize_field(field, field_id, row_bits) }
      Config.deep_freeze(data)
      Model::Document.new(title: data["title"], description: data["description"],
                          layout: data["layout"], ascii: data["ascii"], svg: data["svg"], raster: data["raster"],
                          fields: fields.freeze, notes: data.fetch("notes", []).freeze,
                          annotations: data.fetch("annotations", []).map { |item| normalize_annotation(item) }.freeze)
    end

    private

    def normalize_field(field, field_id, row_bits)
      variable = field["bits"] == "variable"
      Config.deep_freeze(field)
      Model::Field.new(id: field_id.freeze, name: field["name"], short: field["short"],
                       bits: variable ? nil : field.fetch("bits") { field["bytes"] * 8 }, variable: variable,
                       display_bits: field.fetch("display_bits", row_bits), description: field["description"],
                       value: field["value"], reserved: field.fetch("reserved", false),
                       optional: field.fetch("optional", false),
                       classes: Array(field["class"]).flat_map(&:split).map(&:freeze).freeze,
                       fill: field["fill"])
    end

    # Values become strings; style defaults to boxed.
    def normalize_annotation(item)
      Model::Annotation.new(label: item["label"], values: item["values"].transform_values(&:to_s).freeze,
                            per_bit: item.fetch("per_bit", false), style: item.fetch("style", "boxed"),
                            fill: item["fill"])
    end
  end
end
