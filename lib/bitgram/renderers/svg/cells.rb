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

        # names: false for text that is not a field's name (annotation rows), which
        # svg.field_font_weight leaves alone.
        def draw_label(fits, x, center, names: true)
          scales = fits.each_index.map { |index| index.zero? ? 1 : 0.85 }
          total = fits.each_with_index.sum { |fit, index| fit ? @geometry.fit_height(fit, scales[index]) : 0 }
          top = center - (total / 2.0)
          fits.each_with_index do |fit, index|
            next unless fit

            size = (fit.font_size || @options["font_size"]) * scales[index]
            style = label_style(index.zero?, size, names)
            extent = @geometry.fit_height(fit, scales[index])
            case fit.strategy
            when :leader then nil # Drawn below the row (Svg#draw_leaders).
            when :rotate then draw_rotated(fit.lines.first, x, top + (extent / 2.0), size, style)
            else draw_label_lines(fit.lines, x, top + (size * 0.95), size, style)
            end
            top += extent
          end
        end

        # The first text of a cell is its name (bg-label), the second its value (bg-value).
        def label_style(name, size, names)
          text_attributes(name ? "bg-label" : "bg-value", size, bold: names && name && field_bold?)
        end

        # Reads from bottom to top. The baseline sits 0.35em from the middle, as for offsets.
        def draw_rotated(text, x, middle, size, style)
          baseline = x + (size * 0.35)
          attributes = style.merge(x: baseline, y: middle, transform: "rotate(-90 #{fmt(baseline)} #{fmt(middle)})")
          emit("text", attributes, text)
        end

        def draw_label_lines(lines, x, baseline, size, style)
          if lines.length == 1
            emit("text", style.merge(x: x, y: baseline), lines.first)
          else
            @output << "<text #{XmlBuilder.attributes(style)}>"
            lines.each_with_index { |line, index| emit("tspan", { x: x, y: baseline + (index * size * 1.2) }, line) }
            @output << "</text>"
          end
        end

        # svg.field_font_weight: bold sets the names of fields in bold (the book's draw.io
        # figures do). Unset or normal writes nothing, as before.
        def field_bold?
          @options["field_font_weight"] == "bold"
        end
      end
    end
  end
end
