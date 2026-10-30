# frozen_string_literal: true

module Bitgram
  module Renderers
    class Svg
      # @api private
      # Places the names of fields fitted with the `leader` strategy below their row. Each
      # name hangs from a vertical line starting at the middle of its cell's bottom edge.
      # A name goes on the first level (line of text below the row) where it overlaps no
      # other name, its line crosses no name above it, and it covers no line going further
      # down. It is centered on its line, or else starts or ends a space beside the line.
      class Leaders
        Label = Data.define(:line_x, :left, :level, :text, :size, :width) do
          def right = left + width
          def center = left + (width / 2.0)
        end

        # Orders to try: [sort direction, alignments in order of preference]. A greedy pass
        # can block a line with a name placed before it (two names wider than the cells they
        # hang from), so the passes go both ways and the best result is kept.
        PASSES = [[1, %i[center start end]], [-1, %i[start center end]], [1, %i[end center start]]].freeze

        # @param items [Array<Array>] [line_x, text, text_width, size] for each leader in the row
        # @param right [Numeric] right edge of the drawing area; names are kept inside 0..right
        # @param space [Numeric] the least horizontal space between two names
        # @return [Array<Label>] the pass with the fewest crossed lines, then the fewest levels
        def self.place(items, right:, space:)
          PASSES.map { |direction, alignments| pass(items, direction, alignments, right, space) }
                .min_by { |labels, crossed| [crossed, labels.map(&:level).max] }.first
        end

        def self.pass(items, direction, alignments, right, space)
          placed = []
          crossed = 0
          items.sort_by { |line_x, *| direction * line_x }.each do |line_x, text, width, size|
            lefts = alignments.map do |alignment|
              left = { center: line_x - (width / 2.0), start: line_x - space, end: line_x + space - width }[alignment]
              left.clamp(0, [right - width, 0].max)
            end
            label, blocked = choose(placed, lefts, space) do |left, level|
              Label.new(line_x, left, level, text, size, width)
            end
            placed << label
            crossed += 1 if blocked
          end
          [placed.sort_by(&:line_x), crossed]
        end

        def self.choose(placed, lefts, space)
          (0..placed.size).each do |level|
            lefts.each do |left|
              label = yield(left, level)
              return [label, false] if free?(placed, label, space)
            end
          end
          # Every level down to one below all placed names is blocked (a name above covers this
          # line at each level): go one level further and let the line cross that name.
          [yield(lefts.first, placed.size + 1), true]
        end

        def self.free?(placed, label, space)
          placed.none? do |other|
            (other.level == label.level && other.left - space < label.right && label.left - space < other.right) ||
              (other.level < label.level && other.left - space < label.line_x && label.line_x < other.right + space) ||
              (other.level > label.level && label.left - space < other.line_x && other.line_x < label.right + space)
          end
        end
        private_class_method :pass, :choose, :free?
      end
    end
  end
end
