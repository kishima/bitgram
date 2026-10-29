# frozen_string_literal: true

module Bitgram
  # @api private
  class Normalizer
    def call(raw)
      data = Config.deep_merge(Config::DEFAULTS, Config.stringify(raw))
      used = data.fetch("fields").filter_map { |field| field["id"] }.to_h { |id| [id, true] }
      fields = data["fields"].each_with_index.map do |field, i|
        normalize_field(field, i, used, data["layout"]["row_bits"])
      end
      Config.deep_freeze(data)
      Model::Document.new(title: data["title"], description: data["description"],
                          layout: data["layout"], ascii: data["ascii"], svg: data["svg"], raster: data["raster"],
                          fields: fields.freeze, notes: data.fetch("notes", []).freeze)
    end

    private

    def normalize_field(field, index, used, row_bits)
      id = field["id"] || unique_id(field["name"], index, used)
      variable = field["bits"] == "variable"
      Config.deep_freeze(field)
      Model::Field.new(id: id.freeze, name: field["name"], short: field["short"],
                       bits: variable ? nil : field.fetch("bits") { field["bytes"] * 8 }, variable: variable,
                       display_bits: field.fetch("display_bits", row_bits), description: field["description"],
                       value: field["value"], reserved: field.fetch("reserved", false),
                       optional: field.fetch("optional", false),
                       classes: Array(field["class"]).flat_map(&:split).map(&:freeze).freeze,
                       fill: field["fill"])
    end

    def unique_id(name, index, used)
      base = Config.slug(name)
      base = "field-#{index + 1}" if base.empty?
      id = base
      suffix = 1
      while used[id]
        suffix += 1
        id = "#{base}-#{suffix}"
      end
      used[id] = true
      id
    end
  end
end
