# frozen_string_literal: true

require_relative "../../loader"

module Bitgram
  module Renderers
    class Svg
      # @api private
      class Theme
        COLORS = %w[background stroke text header_text cell_fill reserved_fill hatch].freeze
        COLOR = /\A(?:\#[0-9a-fA-F]{3}|\#[0-9a-fA-F]{6}|\#[0-9a-fA-F]{8}|[a-zA-Z]+|rgba?\([0-9., %]+\))\z/
        DIRECTORY = File.expand_path("../../themes", __dir__)

        attr_reader :data

        def initialize(name)
          defaults = read(File.join(DIRECTORY, "default.yml"))
          path = %w[default dark mono].include?(name.to_s) ? File.join(DIRECTORY, "#{name}.yml") : name.to_s
          @data = defaults.merge(read(path))
          validate
        end

        def [](key)
          data.fetch(key)
        end

        def field_fill(field, index)
          classes = field.classes.filter_map { |name| self["classes"][name]&.fetch("fill", nil) }
          palette = self["palette"]
          field.fill || classes.last || (palette[index % palette.size] unless palette.empty?) ||
            self[field.reserved ? "reserved_fill" : "cell_fill"]
        end

        private

        def read(path)
          result = Loader.new.load_file(path).data
          raise RenderError, "theme must be an object" unless result.is_a?(Hash)

          result
        rescue ParseError => e
          raise RenderError, "invalid theme: #{e.message}"
        end

        def validate
          unknown = data.keys - COLORS - %w[palette classes]
          raise RenderError, "unknown theme keys: #{unknown.join(', ')}" unless unknown.empty?
          raise RenderError, "theme palette must be an array" unless self["palette"].is_a?(Array)
          raise RenderError, "theme classes must be an object" unless self["classes"].is_a?(Hash)

          COLORS.each { |key| validate_color(self[key]) }
          self["palette"].each { |color| validate_color(color) }
          self["classes"].each do |name, rules|
            unless name.is_a?(String) && /\A[a-zA-Z_][a-zA-Z0-9_-]*\z/.match?(name) &&
                   rules.is_a?(Hash) && (rules.keys - ["fill"]).empty?
              raise RenderError, "theme class must have a safe name and fill property"
            end

            rules.each_value { |color| validate_color(color) }
          end
        end

        def validate_color(color)
          raise RenderError, "invalid theme color: #{color.inspect}" unless color.is_a?(String) && COLOR.match?(color)
        end
      end
    end
  end
end
