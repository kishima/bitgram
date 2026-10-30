# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      # Lines of text under each row of fields (the top-level `annotations`), one svg.row_height
      # high each, with their labels in the left-hand column.
      module Annotations
        # Annotation text is short (a value, a bit). In a box it shrinks, then is cut (V-09).
        FIT_ORDER = %w[single shrink truncate].freeze

        private

        # @return [Array<Array<Array>>] per row, per annotation: [col, bits, fit] boxes
        def fit_annotations
          @result.rows.map do |row|
            @document.annotations.each_with_index.map do |annotation, index|
              row.cells.flat_map { |cell| annotation_boxes(annotation, index, cell) }
            end
          end
        end

        def annotation_boxes(annotation, index, cell)
          text = annotation.values[cell.field.id]
          return [] if text.nil?

          path = "$.annotations[#{index}].values.#{cell.field.id}"
          if annotation.per_bit
            annotation_bits(text, cell).each_with_index.map do |char, bit|
              annotation_box(annotation, char, cell.col + bit, 1, path)
            end
          elsif %i[whole head].include?(cell.part)
            [annotation_box(annotation, text, cell.col, cell.bits, path)]
          else
            []
          end
        end

        # The characters of a per_bit value under this cell. The value is written most
        # significant bit first. A cell's range counts from the first bits placed: the most
        # significant with msb_first, the least significant with lsb_first.
        def annotation_bits(text, cell)
          chars = text.scan(/\X/)
          return chars.first(cell.bits) unless cell.range

          start = if @document.layout["field_order"] == "lsb_first"
                    chars.size - cell.range.end
                  else
                    cell.range.begin
                  end
          chars[start, cell.bits]
        end

        def annotation_box(annotation, text, col, bits, path)
          inner_width = [(bits * @options["bit_width"]) - 8, 0].max
          return [col, bits, plain_fit(text, bits * @options["bit_width"])] if annotation.style == "plain"

          [col, bits, @fitter.fit(text: text, inner_width: inner_width, order: FIT_ORDER, path: path)]
        end

        # Plain text has no box to stay inside: it shrinks (0.5px steps, down to min_font_size)
        # to fit the cell's whole width, and is never cut; at min_font_size it may run past the
        # cell into the space beside it.
        def plain_fit(text, width)
          size = @options["font_size"]
          size -= 0.5 while size - 0.5 >= @options["min_font_size"] && @measurer.width(text, size: size) > width
          Text::FitResult.new([text].freeze, size, :plain, nil)
        end

        def annotation_height
          @document.annotations.size * @options["row_height"]
        end

        def draw_annotations(boxes, top)
          height = @options["row_height"]
          @document.annotations.zip(boxes).each_with_index do |(annotation, row_boxes), index|
            y = top + (index * height)
            @output << %(<g class="bg-annotation" data-annotation="#{index}">)
            draw_gutter_label(annotation.label.to_s, y, height)
            row_boxes.each { |col, bits, fit| draw_annotation_box(annotation, col, bits, fit, y) }
            @output << "</g>"
          end
        end

        def draw_annotation_box(annotation, col, bits, fit, y)
          x = @geometry.x + (col * @options["bit_width"])
          width = bits * @options["bit_width"]
          height = @options["row_height"]
          if annotation.style == "boxed"
            emit("rect", { class: "bg-annotation-cell", x: x, y: y, width: width, height: height,
                           fill: annotation.fill || @theme["cell_fill"], stroke: @theme["stroke"], "stroke-width": 1 })
          end
          draw_label([fit], x + (width / 2.0), y + (height / 2.0), names: false)
        end
      end
    end
  end
end
