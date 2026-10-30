# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      class Geometry
        attr_reader :width, :height, :gutter, :title_height, :header_height, :row_heights, :band_heights, :x, :y

        # band_heights: space below each row for what is drawn under its cells (leader names).
        def initialize(result, options, fits, footnotes, measurer, band_heights: nil)
          @result = result
          @options = options
          @measurer = measurer
          measure_header(measurer)
          @row_heights = result.rows.each_with_index.map { |row, index| row_height(row, fits[index]) }
          @band_heights = band_heights || Array.new(@row_heights.size, 0)
          @x = options["margin"] + gutter
          @y = options["margin"] + title_height + header_height
          @width = (options["margin"] * 2) + gutter + (result.document.layout["row_bits"] * options["bit_width"])
          @height = (options["margin"] * 2) + title_height + header_height + table_height + footer_height(footnotes)
        end

        # Rows and the bands below them.
        def table_height
          row_heights.sum + band_heights.sum
        end

        # Vertical space a fitted label takes inside its cell: its lines, or its length when
        # it is turned (rotate). A leader name is drawn below the row and takes none.
        def fit_height(fit, scale = 1)
          size = (fit.font_size || @options["font_size"]) * scale
          case fit.strategy
          when :leader then 0
          when :rotate then @measurer.width(fit.lines.first, size: size)
          else fit.lines.length * size * 1.2
          end
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
            [label, value].compact.sum { |fit| fit_height(fit) } + 8
          end.max || 0
          base = @options["row_height"] * (row.kind == :variable ? 1.5 : row.span)
          [base, content_height].max
        end
      end
    end
  end
end
