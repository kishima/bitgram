# frozen_string_literal: true

module Bitgram
  module Renderers
    class Ascii
      # @api private
      module BoxChars
        module_function

        def border(width, above:, below:, unicode:)
          return "#{'+-' * width}+" unless unicode

          top = above.nil?
          bottom = below.nil?
          left, right = if top
                          %w[┌ ┐]
                        else
                          (bottom ? %w[└ ┘] : %w[├ ┤])
                        end
          upper = boundaries(above)
          lower = boundaries(below)
          middle = (1...(2 * width)).map do |column|
            next "─" if column.odd?

            up = upper.include?(column / 2)
            down = lower.include?(column / 2)
            if up
              down ? "┼" : "┴"
            else
              (down ? "┬" : "─")
            end
          end.join
          left + middle + right
        end

        def boundaries(row)
          return [] unless row

          row.cells.flat_map { |cell| [cell.col, cell.col + cell.bits] }
        end
      end
    end
  end
end
