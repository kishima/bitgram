# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      class Geometry
        attr_reader :width, :height, :gutter, :title_height, :header_height, :row_heights, :x, :y

        def initialize(result, options, fits, footnotes, measurer)
          @result = result
          @options = options
          measure_header(measurer)
          @row_heights = result.rows.each_with_index.map { |row, index| row_height(row, fits[index]) }
          @x = options["margin"] + gutter
          @y = options["margin"] + title_height + header_height
          @width = (options["margin"] * 2) + gutter + (result.document.layout["row_bits"] * options["bit_width"])
          @height = (options["margin"] * 2) + title_height + header_height + row_heights.sum + footer_height(footnotes)
        end

        private

        def footer_height(footnotes)
          footnotes.empty? ? 0 : 8 + (footnotes.length * @options["font_size"] * 1.4)
        end

        def measure_header(measurer)
          result = @result
          options = @options
          @title_height = options["show_title"] && result.document.title ? (options["font_size"] * 2) + 2 : 0
          @header_height = if result.document.layout["bit_numbers"]
                             options["bit_number_style"] == "rfc" ? 36 : 24
                           else
                             0
                           end
          @gutter = if result.document.layout["offsets"] == "none"
                      0
                    else
                      result.rows.map { |row| measurer.width(result.offset_label(row)) }.max.to_f + 12
                    end
        end

        def row_height(row, fits)
          content_height = fits.map do |label, value|
            [label, value].compact.sum { |fit| fit.lines.length * (fit.font_size || @options["font_size"]) * 1.2 } + 8
          end.max || 0
          base = @options["row_height"] * (row.kind == :variable ? 1.5 : row.span)
          [base, content_height].max
        end
      end
    end
  end
end
