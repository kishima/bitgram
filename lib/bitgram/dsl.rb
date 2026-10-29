# frozen_string_literal: true

module Bitgram
  # Builds a definition for the regular validation pipeline.
  # @api private
  class DSL
    def initialize(title: nil)
      @data = { "version" => 1, "title" => title, "layout" => {}, "fields" => [] }.compact
    end

    def row_bits(value)
      @data["layout"]["row_bits"] = value
    end

    def bit_order(value)
      @data["layout"]["bit_order"] = value.to_s
    end

    def field(name, **options)
      @data["fields"] << { "name" => name, **options.transform_keys(&:to_s) }
    end

    def reserved(bits, name: "Reserved")
      field(name, bits: bits, reserved: true)
    end

    def variable(name, **)
      field(name, **, bits: "variable")
    end

    def to_h
      @data
    end
  end
end
