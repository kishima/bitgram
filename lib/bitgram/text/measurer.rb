# frozen_string_literal: true

require "unicode/display_width"

module Bitgram
  module Text
    # @api private
    class AsciiMeasurer
      def initialize(ambiguous: 1)
        @display_width = Unicode::DisplayWidth.new(ambiguous: ambiguous, emoji: :all)
      end

      def width(string)
        @display_width.of(string)
      end
    end

    # @api private
    class SvgMeasurer < AsciiMeasurer
      def initialize(font_size:, ratio:, ambiguous: 1)
        super(ambiguous: ambiguous)
        @font_size = font_size
        @ratio = ratio
      end

      def width(string, size: @font_size)
        super(string) * size * @ratio
      end
    end
  end
end
