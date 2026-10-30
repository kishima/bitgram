# frozen_string_literal: true

require "digest"
require "json"
require_relative "../text/fitter"
require_relative "svg/xml_builder"
require_relative "svg/theme"
require_relative "svg/font_family"
require_relative "svg/geometry"
require_relative "svg/decorations"
require_relative "svg/cells"
require_relative "svg/leaders"
require_relative "svg/annotations"

module Bitgram
  # @api private
  module Renderers
    # @api private
    class Svg
      include Decorations
      include Cells
      include Annotations

      attr_reader :issues, :width, :height

      def initialize(result, **options)
        @result = result
        @document = result.document
        @options = @document.svg.merge(options.transform_keys(&:to_s).transform_values do |value|
          value.is_a?(Symbol) ? value.to_s : value
        end)
        @issues = []
      end

      def render
        prepare
        @output = []
        attributes = { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 #{fmt(width)} #{fmt(height)}",
                       width: width, height: height, role: "img", "aria-labelledby": "#{@prefix}-title #{@prefix}-desc",
                       class: "bitgram", id: "#{@prefix}-diagram" }
        @output << "<svg #{XmlBuilder.attributes(attributes)}>"
        emit("title", { id: "#{@prefix}-title" }, @document.title || "Bit-field diagram")
        emit("desc", { id: "#{@prefix}-desc" }, @document.description || "Bit-field layout")
        draw_definitions
        draw_styles unless @options["inline_styles"]
        draw_header
        draw_rows
        draw_footer
        @output << "</svg>"
        @issues = @fitter.issues
        "#{@output.join("\n")}\n"
      end

      private

      def prepare
        selected_theme = @options["theme"] == "auto" ? "default" : @options["theme"]
        @theme = Theme.new(selected_theme)
        @prefix = @options["id_prefix"] || default_prefix
        @field_indexes = @document.fields.each_with_index.to_h { |field, index| [field.id, index] }
        @measurer = Text::SvgMeasurer.new(font_size: @options["font_size"], ratio: @options["char_width_ratio"])
        @fitter = Text::Fitter.new(measurer: @measurer, font_size: @options["font_size"],
                                   min_font_size: @options["min_font_size"],
                                   footnote_marker: @document.ascii["footnote_marker"])
        @fits = @result.rows.map { |row| row.cells.map { |cell| fit_cell(cell) } }
        @footer = @fitter.footnotes + @document.notes
        measure
      end

      def measure
        @annotation_boxes = fit_annotations
        @leaders = @result.rows.each_with_index.map { |row, index| place_leaders(row, @fits[index]) }
        @geometry = Geometry.new(@result, @options, @fits, @footer, @measurer,
                                 band_heights: @leaders.map { |labels| leader_band(labels) + annotation_height })
        @width = @geometry.width
        @height = @geometry.height
      end

      def fit_cell(cell)
        inner_width = [(cell.bits * @options["bit_width"]) - 8, 0].max
        label = @result.cell_label(cell)
        if cell.part != :whole && @document.layout["split_label"] == "range" && @measurer.width(label) > inner_width
          label = cell.field.name
        end
        arguments = { inner_width: inner_width, max_lines: @document.ascii["max_label_lines"],
                      order: @options["fit_order"], path: "$.fields[#{@field_indexes.fetch(cell.field.id)}].name" }
        fit = @fitter.fit(text: label, short: cell.field.short, description: cell.field.description, **arguments)
        value = cell.field.value
        # A value stays inside its cell; only the name can hang below the row.
        unless value.nil?
          value_fit = @fitter.fit(text: "= #{value}", **arguments, order: arguments[:order] - ["leader"])
        end
        [fit, value_fit]
      end

      # Leader names, with x relative to the left edge of the cells.
      def place_leaders(row, fits)
        items = row.cells.zip(fits).filter_map do |cell, (fit, _value)|
          next unless fit.strategy == :leader

          line_x = (cell.col + (cell.bits / 2.0)) * @options["bit_width"]
          [line_x, fit.lines.first, @measurer.width(fit.lines.first), @options["font_size"]]
        end
        return [] if items.empty?

        Leaders.place(items, right: @document.layout["row_bits"] * @options["bit_width"], space: @measurer.width(" "))
      end

      # The gap above the first level of names, then one line (font_size * 1.2, the pitch of
      # wrapped labels) per level.
      def leader_band(labels)
        return 0 if labels.empty?

        leader_gap + ((labels.map(&:level).max + 1) * @options["font_size"] * 1.2)
      end

      # Default 8: the space bitgram leaves between the rows and the footnotes (Geometry#footer_height).
      def leader_gap
        @options.fetch("leader_gap", 8)
      end

      def default_prefix
        slug = @document.title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
        return slug unless slug.empty?

        content = @document.to_h.merge(fields: @document.fields.map(&:to_h))
        # Annotations came after the digest was defined; leave them out when there are none so
        # that ids of diagrams without them stay as they were.
        content = if @document.annotations.empty?
                    content.except(:annotations)
                  else
                    content.merge(annotations: @document.annotations.map(&:to_h))
                  end
        "bitgram-#{Digest::SHA256.hexdigest(JSON.generate(content))[0, 8]}"
      end

      def draw_rows
        @output << '<g class="bg-rows">'
        y = @geometry.y
        @result.rows.each_with_index do |row, index|
          row_height = @geometry.row_heights[index]
          attributes = { class: "bg-row", "data-row": row.index,
                         "data-offset": row.offset_bits && (row.offset_bits / 8.0) }
          @output << "<g #{XmlBuilder.attributes(attributes)}>"
          row.cells.each_with_index { |cell, col| draw_cell(cell, row, y, row_height, @fits[index][col]) }
          draw_ticks(row, y, row_height) if @options["ticks"]
          draw_gutter_label(@result.gutter_label(row), y, row_height)
          draw_leaders(@leaders[index], y + row_height)
          draw_annotations(@annotation_boxes[index], y + row_height + leader_band(@leaders[index]))
          @output << "</g>"
          y += row_height + @geometry.band_heights[index]
        end
        @output << "</g>"
      end

      def draw_footer
        return if @footer.empty?

        y = @geometry.y + @geometry.table_height + 8 + @options["font_size"]
        @output << '<g class="bg-footnotes">'
        @footer.each do |line|
          emit("text", text_attributes("bg-footnote").merge(x: @geometry.x, y: y, "text-anchor": "start"), line)
          y += @options["font_size"] * 1.4
        end
        @output << "</g>"
      end

      def draw_leaders(labels, bottom)
        labels.each do |label|
          top = bottom + leader_gap + (label.level * label.size * 1.2)
          emit("line", { class: "bg-leader", x1: @geometry.x + label.line_x, y1: bottom,
                         x2: @geometry.x + label.line_x, y2: top, stroke: @theme["stroke"], "stroke-width": 1 })
          emit("text", text_attributes("bg-label bg-leader-label", label.size)
                         .merge(x: @geometry.x + label.center, y: top + (label.size * 0.95)), label.text)
        end
      end

      def text_attributes(klass, size = @options["font_size"])
        attributes = { class: klass, "font-size": size, "text-anchor": "middle" }
        if @options["inline_styles"]
          attributes[:"font-family"] = FontFamily.css(@options["font_family"])
          attributes[:fill] = @theme["text"]
          attributes[:style] = "font-variant-ligatures: none" if @options["ligatures"] == false
        end
        attributes
      end

      def emit(name, attributes = {}, text = nil)
        @output << XmlBuilder.element(name, attributes, text)
      end

      def fmt(value)
        XmlBuilder.number(value)
      end
    end
  end
end
