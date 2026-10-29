# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      module XmlBuilder
        module_function

        def escape(value)
          value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
               .gsub('"', "&quot;").gsub("'", "&apos;")
        end

        def number(value)
          rounded = value.round(2)
          rounded == rounded.round ? rounded.round.to_s : format("%.2f", rounded).sub(/0+\z/, "")
        end

        def attributes(values)
          values.compact.map do |key, value|
            %(#{key}="#{escape(value.is_a?(Numeric) ? number(value) : value)}")
          end.join(" ")
        end

        def element(name, attributes = {}, text = nil)
          attrs = attributes.empty? ? "" : " #{self.attributes(attributes)}"
          text.nil? ? "<#{name}#{attrs}/>" : "<#{name}#{attrs}>#{escape(text)}</#{name}>"
        end
      end
    end
  end
end
