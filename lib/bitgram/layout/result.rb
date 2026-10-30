# frozen_string_literal: true

module Bitgram
  module Layout
    # The shared, format-independent layout used by all renderers.
    Result = Data.define(:document, :rows, :issues) do
      # @param cell [Cell] segment whose display label is requested
      # @return [String] label including a continuation or relative bit range
      def cell_label(cell)
        name = cell.field.name
        return name if cell.part == :whole

        case document.layout["split_label"]
        when "first" then cell.part == :head ? name : "(cont.)"
        when "repeat" then name
        else
          return name unless cell.range

          name + document.layout["split_suffix"].gsub("{from}", cell.range.begin.to_s)
                         .gsub("{to}", (cell.range.end - 1).to_s)
        end
      end

      # @param row [Row] row whose left-hand label is requested
      # @return [String] the row's entry in layout.row_labels, or else its offset label
      def gutter_label(row)
        document.layout.fetch("row_labels", [])[row.index] || offset_label(row)
      end

      # @return [Array<String>] every label drawn left of the cells: rows, annotation lines and
      #   the bit-number header (layout.bit_numbers_label)
      def gutter_labels
        labels = rows.map { |row| gutter_label(row) } + document.annotations.map { |item| item.label.to_s }
        labels << document.layout["bit_numbers_label"].to_s if document.layout["bit_numbers"]
        labels
      end

      # @return [Boolean] whether anything besides offsets asks for the left-hand column
      def labeled_gutter?
        document.layout.key?("row_labels") || document.layout.key?("bit_numbers_label") ||
          document.annotations.any?(&:label)
      end

      # @param row [Row] row whose starting position is requested
      # @return [String] byte offset, bit offset, or blank if unknown/disabled
      def offset_label(row)
        return "" if row.offset_bits.nil? || document.layout["offsets"] == "none"
        return "#{row.offset_bits}b" unless (row.offset_bits % 8).zero?

        bytes = row.offset_bits / 8
        document.layout["offsets"] == "hex" ? format("0x%02x", bytes) : bytes.to_s
      end
    end
  end
end
