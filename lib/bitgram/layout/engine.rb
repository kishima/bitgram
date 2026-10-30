# frozen_string_literal: true

require_relative "cell"
require_relative "row"
require_relative "result"

module Bitgram
  module Layout
    # @api private
    class Engine
      def call(document)
        @document = document
        @width = document.layout.fetch("row_bits")
        @rows = []
        @pending = []
        @col = @position = @row_position = 0
        document.fields.each { |field| place(field) }
        append_row(:normal) unless @pending.empty?
        rows = document.layout["field_order"] == "lsb_first" ? @rows.map { |row| mirror(row) } : @rows
        Result.new(document, rows.freeze, [].freeze)
      end

      private

      def place(field)
        if @col.zero? && field.variable? && field.display_bits == @width
          @pending << Cell.new(field, 0, @width, :whole, nil)
          append_row(:variable)
          @position = @row_position = nil
        elsif block?(field)
          @pending << Cell.new(field, 0, @width, :whole, 0...field.bits)
          append_row(:block, field.bits / @width)
          @position += field.bits if @position
          @row_position = @position
        else
          place_segments(field)
        end
      end

      def block?(field)
        @document.layout["merge_rows"] && @col.zero? && !field.variable? &&
          field.bits >= 2 * @width && (field.bits % @width).zero?
      end

      def place_segments(field)
        consumed = 0
        while consumed < field.width_bits
          take = [field.width_bits - consumed, @width - @col].min
          range = field.variable? ? nil : consumed...(consumed + take)
          @pending << Cell.new(field, @col, take, part_of(consumed, take, field.width_bits), range)
          @col += take
          consumed += take
          next unless @col == @width

          append_row(:normal)
          @row_position = @position && !field.variable? ? @position + consumed : nil
        end
        @position = field.variable? || @position.nil? ? nil : @position + field.bits
      end

      def append_row(kind, span = 1)
        @rows << Row.new(@rows.size, kind, @pending.freeze, span, @row_position)
        @pending = []
        @col = 0
      end

      # lsb_first: fields are listed from the least significant bit, as C declares bit-fields.
      # Rows are filled in the same order as msb_first, then each row is drawn right to left,
      # so the first field ends at the row's right edge. A partial last row keeps its gap on
      # the left (the missing high bits).
      def mirror(row)
        cells = row.cells.reverse.map { |cell| cell.with(col: @width - cell.col - cell.bits) }
        row.with(cells: cells.freeze)
      end

      def part_of(consumed, take, total)
        return :whole if consumed.zero? && take == total
        return :head if consumed.zero?

        consumed + take == total ? :tail : :middle
      end
    end
  end
end
