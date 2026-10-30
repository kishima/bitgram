# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      # Writes a font_family setting as a CSS font-family value.
      #
      # CSS accepts an unquoted family name only when every word is an identifier, so a
      # name such as M PLUS 1p (a word starting with a digit) must be quoted. Names that
      # are already quoted, generic families, and valid identifier sequences are kept as
      # written, so existing settings produce the same output.
      module FontFamily
        GENERIC = %w[serif sans-serif monospace cursive fantasy system-ui ui-serif ui-sans-serif
                     ui-monospace ui-rounded math emoji fangsong inherit initial unset revert].freeze
        IDENTIFIER = /\A(?:--|-?[a-zA-Z_\u0080-\u{10FFFF}])[a-zA-Z0-9_\-\u0080-\u{10FFFF}]*\z/

        module_function

        def css(value)
          split(value.to_s).map { |name| family(name) }.join(", ")
        end

        def family(name)
          return name if name.empty? || quoted?(name) || GENERIC.include?(name.downcase)
          return name if name.split(/\s+/).all? { |word| IDENTIFIER.match?(word) }

          "'#{name.gsub("'", "\\\\'")}'"
        end

        def quoted?(name)
          name.length >= 2 && %w[' "].include?(name[0]) && name[-1] == name[0]
        end

        # Splits at commas outside quoted names and trims each name.
        def split(value)
          names = [+""]
          quote = nil
          value.each_char do |char|
            if quote
              quote = nil if char == quote
            elsif %w[' "].include?(char) && names.last.strip.empty?
              quote = char
            elsif char == ","
              names << +""
              next
            end
            names.last << char
          end
          names.map(&:strip).reject(&:empty?)
        end
      end
    end
  end
end
