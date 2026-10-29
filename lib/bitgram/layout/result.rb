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
