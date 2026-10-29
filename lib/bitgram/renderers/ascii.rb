# frozen_string_literal: true

require_relative "../text/fitter"
require_relative "ascii/box_chars"

module Bitgram
  module Renderers
    # @api private
    class Ascii
      attr_reader :issues

      def initialize(result, **options)
        @result = result
        @document = result.document
        @config = @document.ascii.merge(options.transform_keys(&:to_s))
        @width = @document.layout.fetch("row_bits")
        @unicode = @config["style"].to_s == "unicode"
        @measurer = Text::AsciiMeasurer.new(ambiguous: @config["ambiguous_width"])
        @offset_width = @result.rows.map { |row| @result.offset_label(row).size }.max || 0
        @issues = []
      end

      def render
        @fitter = Text::Fitter.new(measurer: @measurer, footnote_marker: @config["footnote_marker"])
        lines = []
        lines << @document.title if @document.title && @config["title"].to_s == "top"
        lines.concat(header.map { |line| gutter + line }) if @document.layout["bit_numbers"]
        lines.concat(table_lines)
        lines.concat(@fitter.footnotes).concat(@document.notes)
        lines << @document.title if @document.title && @config["title"].to_s == "bottom"
        @issues = @fitter.issues
        indented = lines.flat_map { |line| line.split("\n") }
                        .map { |line| ((" " * @config["indent"]) + line).rstrip }
        "#{indented.join("\n")}\n"
      end

      private

      def table_lines
        lines = []
        @result.rows.each_with_index do |row, index|
          lines << (gutter + border(@result.rows[index - 1], row, top: index.zero?))
          row_lines(row).each_with_index do |line, inner_index|
            offset = inner_index.zero? ? @result.offset_label(row) : ""
            lines << (gutter(offset) + line)
          end
        end
        lines << (gutter + border(@result.rows.last, nil))
        lines
      end

      def gutter(offset = "")
        @offset_width.positive? ? "#{offset.rjust(@offset_width)} " : ""
      end

      def border(above, below, top: false)
        BoxChars.border(@width, above: top ? nil : above, below: below, unicode: @unicode)
      end

      def header
        tens = Array.new((2 * @width) + 1, " ")
        ones = Array.new((2 * @width) + 1, " ")
        @width.times do |column|
          number = @document.layout["bit_order"] == "lsb0" ? @width - 1 - column : column
          tens[(2 * column) + 1, (number / 10).to_s.size] = (number / 10).to_s.chars if (number % 10).zero?
          ones[(2 * column) + 1] = (number % 10).to_s
        end
        [tens.join.rstrip, ones.join.rstrip]
      end

      def row_lines(row)
        fits = row.cells.map { |cell| fit_cell(cell) }
        height = [fits.map { |fit| fit.lines.size }.max, minimum_height(row)].max
        Array.new(height) do |index|
          edge = edge_for(row, index)
          content = row.cells.zip(fits).map do |cell, fit|
            cell_line(cell, fit, index, height) + edge
          end.join
          remaining = @width - row.cells.sum(&:bits)
          content += (" " * ((2 * remaining) - 1)) + edge if remaining.positive?
          edge + content
        end
      end

      def cell_line(cell, fit, index, height)
        line_index = index - ((height - fit.lines.size) / 2)
        label = line_index >= 0 ? fit.lines[line_index].to_s : ""
        center(label, (2 * cell.bits) - 1)
      end

      def minimum_height(row)
        return (2 * row.span) - 1 if row.kind == :block
        return @unicode ? 1 : 3 if row.kind == :variable

        1
      end

      def edge_for(row, index)
        if row.kind == :variable
          return "┊" if @unicode

          return index == 1 ? "\\" : "/" if @config["variable_edge"].to_s == "slash"

          return @config["variable_edge"].to_s == "colon" ? ":" : "."
        end
        return @unicode ? "│" : "+" if row.kind == :block && index.odd?

        @unicode ? "│" : "|"
      end

      def fit_cell(cell)
        width = (2 * cell.bits) - 1
        label = @result.cell_label(cell)
        if cell.part != :whole && @document.layout["split_label"] == "range" && @measurer.width(label) > width
          label = cell.field.name
        end
        label += " (=#{cell.field.value})" unless cell.field.value.nil?
        @fitter.fit(text: label, short: cell.field.short, inner_width: width,
                    max_lines: @config["max_label_lines"], order: @config["fit_order"],
                    description: cell.field.description || cell.field.name,
                    path: "$.fields[#{@document.fields.index(cell.field)}].name")
      end

      def center(text, width)
        padding = [width - @measurer.width(text), 0].max
        (" " * (padding / 2)) + text + (" " * (padding - (padding / 2)))
      end
    end
  end
end
