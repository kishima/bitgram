# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      module Decorations
        private

        def draw_definitions
          @output << "<defs>"
          attributes = { id: "#{@prefix}-hatch", width: 6, height: 6,
                         patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)" }
          @output << "<pattern #{XmlBuilder.attributes(attributes)}>"
          emit("line", { x1: 0, y1: 0, x2: 0, y2: 6, class: "bg-hatch", stroke: @theme["hatch"], "stroke-width": 1 })
          @output << "</pattern>"
          @output << "</defs>"
        end

        def draw_styles
          css = theme_css(@theme)
          if @options["theme"] == "auto"
            css += "\n@media (prefers-color-scheme: dark) {\n#{theme_css(Theme.new('dark'))}\n}"
          end
          emit("style", {}, css)
        end

        def theme_css(theme)
          selector = %([id="#{@prefix}-diagram"])
          font_family = FontFamily.css(@options["font_family"])
          rules = ["#{selector} { background: #{theme['background']}; }",
                   "#{selector} text { font-family: #{font_family}; fill: #{theme['text']};#{ligatures} }",
                   "#{selector} .bg-cell, #{selector} .bg-edge, #{selector} .bg-tick " \
                   "{ stroke: #{theme['stroke']}; stroke-width: 1; }",
                   "#{selector} .bg-hatch { stroke: #{theme['hatch']}; }",
                   "#{selector} .bg-variable-cell { stroke: none; }",
                   "#{selector} .bg-bit-numbers text, #{selector} .bg-offset { fill: #{theme['header_text']}; }"]
          @document.fields.each_with_index do |field, index|
            rules << %(#{selector} [data-field-id="#{field.id}"] .bg-cell { fill: #{theme.field_fill(field, index)}; })
          end
          rules.join("\n")
        end

        # svg.ligatures: false turns off ligatures such as "fl" and "fi" (code names read better).
        def ligatures
          @options["ligatures"] == false ? " font-variant-ligatures: none;" : ""
        end

        def draw_header
          margin = @options["margin"]
          if @geometry.title_height.positive?
            emit("text", text_attributes("bg-title", @options["font_size"] * 1.2)
                         .merge(x: width / 2.0, y: margin + (@options["font_size"] * 1.4)), @document.title)
          end
          return unless @document.layout["bit_numbers"]

          draw_numbers(margin + @geometry.title_height)
        end

        def draw_numbers(top)
          @output << '<g class="bg-bit-numbers">'
          draw_numbers_label(top)
          hidden = @result.unnumbered_columns
          @document.layout["row_bits"].times do |col|
            next if hidden.include?(col)

            number = @document.layout["bit_order"] == "lsb0" ? @document.layout["row_bits"] - 1 - col : col
            x = @geometry.x + ((col + 0.5) * @options["bit_width"])
            attributes = text_attributes("bg-bit-number", 11).merge(x: x, fill: @theme["header_text"])
            if @options["bit_number_style"] == "rfc"
              emit("text", attributes.merge(y: top + 12), number / 10) if (number % 10).zero?
              emit("text", attributes.merge(y: top + 28), number % 10)
            else
              emit("text", attributes.merge(y: top + 16), number)
            end
          end
          @output << "</g>"
        end

        # layout.bit_numbers_label, on the line of the ones digits, right-aligned like row labels.
        def draw_numbers_label(top)
          label = @document.layout["bit_numbers_label"].to_s
          return if label.empty?

          attributes = text_attributes("bg-bit-number bg-bit-numbers-label", 11)
                       .merge(x: @geometry.x - 8, y: top + (@options["bit_number_style"] == "rfc" ? 28 : 16),
                              "text-anchor": "end", fill: @theme["header_text"])
          emit("text", attributes, label)
        end

        def draw_ticks(row, y, height)
          width = @document.layout["row_bits"]
          (1...width).each do |col|
            next if inside_unnumbered_field?(row, col)

            x = @geometry.x + (col * @options["bit_width"])
            emit("line", { class: "bg-tick", x1: x, y1: y, x2: x, y2: y + 4, stroke: @theme["stroke"] })
          end
          return unless row.kind == :block

          (1...row.span).each do |index|
            boundary = y + (height * index / row.span)
            [@geometry.x, @geometry.x + (width * @options["bit_width"]) - 6].each do |x|
              emit("line", { class: "bg-tick", x1: x, y1: boundary, x2: x + 6, y2: boundary, stroke: @theme["stroke"] })
            end
          end
        end

        # A field with bit_numbers: false does not say how many bits its columns hold, so it gets
        # no ticks inside it either (the boundary at col is inside when a cell covers both sides).
        def inside_unnumbered_field?(row, col)
          row.cells.any? { |cell| !cell.field.bit_numbers && cell.col < col && col < cell.col + cell.bits }
        end

        # A row's offset or row label, or an annotation's label, right-aligned left of the cells.
        def draw_gutter_label(label, y, height)
          return if label.empty?

          baseline = y + ([height, @options["row_height"]].min / 2) + (@options["font_size"] * 0.35)
          attributes = text_attributes("bg-offset").merge(x: @geometry.x - 8, y: baseline,
                                                          "text-anchor": "end", fill: @theme["header_text"])
          emit("text", attributes, label)
        end
      end
    end
  end
end
