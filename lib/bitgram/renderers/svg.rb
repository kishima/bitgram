# frozen_string_literal: true

require "digest"
require "json"
require_relative "../text/fitter"
require_relative "svg/xml_builder"
require_relative "svg/theme"
require_relative "svg/geometry"
require_relative "svg/decorations"
require_relative "svg/cells"

module Bitgram
  # @api private
  module Renderers
    # @api private
    class Svg
      include Decorations
      include Cells

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
        @geometry = Geometry.new(@result, @options, @fits, @footer, @measurer)
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
        value_fit = @fitter.fit(text: "= #{value}", **arguments) unless value.nil?
        [fit, value_fit]
      end

      def default_prefix
        slug = @document.title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
        return slug unless slug.empty?

        content = @document.to_h.merge(fields: @document.fields.map(&:to_h))
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
          draw_offset(row, y, row_height)
          @output << "</g>"
          y += row_height
        end
        @output << "</g>"
      end

      def draw_footer
        return if @footer.empty?

        y = @geometry.y + @geometry.row_heights.sum + 8 + @options["font_size"]
        @output << '<g class="bg-footnotes">'
        @footer.each do |line|
          emit("text", text_attributes("bg-footnote").merge(x: @geometry.x, y: y, "text-anchor": "start"), line)
          y += @options["font_size"] * 1.4
        end
        @output << "</g>"
      end

      def text_attributes(klass, size = @options["font_size"])
        attributes = { class: klass, "font-size": size, "text-anchor": "middle" }
        if @options["inline_styles"]
          attributes[:"font-family"] = @options["font_family"]
          attributes[:fill] = @theme["text"]
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
