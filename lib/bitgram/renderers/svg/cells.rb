# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      module Cells
        private

        def draw_cell(cell, row, y, height, fits)
          field = cell.field
          x = @geometry.x + (cell.col * @options["bit_width"])
          width = cell.bits * @options["bit_width"]
          attributes = { class: (["bg-field"] + field.classes).join(" "), "data-field-id": field.id,
                         "data-bits": field.variable? ? "variable" : field.bits, "data-part": cell.part }
          @output << "<g #{XmlBuilder.attributes(attributes)}>"
          label = "#{field.name} (#{field.variable? ? 'variable' : field.bits} bits)"
          label += ": #{field.description}" if field.description
          emit("title", {}, label)
          draw_rectangle(field, row, x: x, y: y, width: width, height: height)
          draw_label(fits, x + (width / 2.0), y + (height / 2.0))
          @output << "</g>"
        end

        def draw_rectangle(field, row, x:, y:, width:, height:)
          rectangle = { class: "bg-cell", x: x, y: y, width: width, height: height,
                        fill: @theme.field_fill(field, @field_indexes.fetch(field.id)),
                        stroke: @theme["stroke"], "stroke-width": 1 }
          rectangle["stroke-dasharray"] = "4 3" if field.optional
          if row.kind == :variable
            rectangle[:stroke] = "none"
            rectangle[:class] += " bg-variable-cell"
          end
          emit("rect", rectangle)
          if field.reserved
            emit("rect",
                 { class: "bg-hatch-overlay", x: x, y: y, width: width, height: height, fill: "url(##{@prefix}-hatch)",
                   "pointer-events": "none" })
          end
          draw_variable_edges(field, x, y, width, height) if row.kind == :variable
        end

        def draw_variable_edges(field, x, y, width, height)
          emit("line", { class: "bg-edge", x1: x, y1: y, x2: x + width, y2: y, stroke: @theme["stroke"] })
          emit("line",
               { class: "bg-edge", x1: x, y1: y + height, x2: x + width, y2: y + height, stroke: @theme["stroke"] })
          [x, x + width].each do |edge|
            steps = 6
            path = "M #{fmt(edge)} #{fmt(y)}"
            (1..steps).each do |index|
              delta = if index == steps
                        0
                      else
                        (index.odd? ? 2 : -2)
                      end
              path += " L #{fmt(edge + delta)} #{fmt(y + (height * index / steps))}"
            end
            emit("path",
                 { class: "bg-edge", d: path, fill: "none", stroke: @theme["stroke"],
                   "stroke-dasharray": field.optional ? "4 3" : nil })
          end
        end

        def draw_label(fits, x, center)
          sizes = fits.each_with_index.map do |fit, index|
            fit && ((fit.font_size || @options["font_size"]) * (index.zero? ? 1 : 0.85))
          end
          total = fits.each_with_index.sum { |fit, index| fit ? fit.lines.length * sizes[index] * 1.2 : 0 }
          top = center - (total / 2.0)
          fits.each_with_index do |fit, index|
            next unless fit

            size = sizes[index]
            baseline = top + (size * 0.95)
            klass = index.zero? ? "bg-label" : "bg-value"
            draw_label_lines(fit.lines, x, baseline, size, klass)
            top += fit.lines.length * size * 1.2
          end
        end

        def draw_label_lines(lines, x, baseline, size, klass)
          if lines.length == 1
            emit("text", text_attributes(klass, size).merge(x: x, y: baseline), lines.first)
          else
            @output << "<text #{XmlBuilder.attributes(text_attributes(klass, size))}>"
            lines.each_with_index { |line, index| emit("tspan", { x: x, y: baseline + (index * size * 1.2) }, line) }
            @output << "</text>"
          end
        end
      end
    end
  end
end
