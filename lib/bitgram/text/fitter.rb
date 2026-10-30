# frozen_string_literal: true

require_relative "measurer"

module Bitgram
  # @api private
  module Text
    # @api private
    FitResult = Data.define(:lines, :font_size, :strategy, :footnote)

    # @api private
    class Fitter
      attr_reader :footnotes, :issues

      def initialize(measurer:, font_size: nil, min_font_size: nil, footnote_marker: "*{n}")
        @measurer = measurer
        @font_size = font_size
        @min_font_size = min_font_size
        @footnote_marker = footnote_marker.gsub(/\s+/, " ")
        @footnotes = []
        @issues = []
      end

      def fit(text:, inner_width:, order:, **options)
        text = text.gsub(/\s+/, " ").strip
        options[:short] = options[:short].gsub(/\s+/, " ").strip if options[:short]
        order.each do |strategy|
          result = attempt(strategy.to_sym, text, inner_width, options)
          return result if result
        end
        truncate(text, inner_width, options.fetch(:path, "$.fields"))
      end

      private

      def attempt(strategy, text, width, options)
        max_lines = options.fetch(:max_lines, 4)
        short = options[:short]
        case strategy
        when :single then result([text], :single) if fits?(text, width)
        when :short then result([short], :short) if short && fits?(short, width)
        when :shrink then shrink(text, width)
        when :wrap, :vertical then multiline(text, width, max_lines, strategy)
        when :footnote then footnote(options[:description] || text, width, max_lines)
        when :truncate then truncate(text, width, options.fetch(:path, "$.fields"))
        else svg_attempt(strategy, text, width, options)
        end
      end

      # Strategies that need a font size, so only the SVG renderer uses them.
      def svg_attempt(strategy, text, width, options)
        case strategy
        when :footnote_shrink then footnote_shrink(options[:description] || text, width)
        when :rotate then rotate(text, width)
        when :leader then result([text], :leader) if @font_size
        end
      end

      def multiline(text, width, max_lines, strategy)
        lines = strategy == :wrap ? wrap(text, width) : text.scan(/\X/).grep_v(/\s/)
        return unless lines && lines.size <= max_lines && lines.all? { |line| fits?(line, width) }

        result(lines, strategy)
      end

      def fits?(text, width)
        @measurer.width(text) <= width
      end

      def result(lines, strategy, size = @font_size, footnote = nil)
        FitResult.new(lines.freeze, size, strategy, footnote)
      end

      def shrink(text, width)
        return unless @font_size && @min_font_size

        size = @font_size - 0.5
        while size >= @min_font_size
          return result([text], :shrink, size) if @measurer.width(text, size: size) <= width

          size -= 0.5
        end
        nil
      end

      def wrap(text, width)
        tokens = text.scan(/[\p{Han}\p{Hiragana}\p{Katakana}]|[^\s\p{Han}\p{Hiragana}\p{Katakana}]+|\s+/)
        tokens = join_punctuation(tokens)
        lines = []
        line = ""
        tokens.each do |token|
          next if line.empty? && token.match?(/\A\s+\z/)

          if fits?(line + token, width)
            line += token
          else
            lines << line.rstrip unless line.empty?
            line = token.lstrip
            return nil unless fits?(line, width)
          end
        end
        lines << line.rstrip unless line.empty?
        lines.empty? ? [""] : lines
      end

      def join_punctuation(tokens)
        tokens.each_with_object([]) do |token, joined|
          if token.match?(/\A[、。,.)」]/) && !joined.empty?
            joined[-1] += token
          else
            joined << token
          end
        end
      end

      def footnote(body, width, max_lines)
        marker = @footnote_marker.gsub("{n}", (@footnotes.size + 1).to_s)
        lines = fits?(marker, width) ? [marker] : marker.scan(/\X/)
        return unless lines.size <= max_lines && lines.all? { |line| fits?(line, width) }

        @footnotes << "#{marker}: #{body}"
        result(lines, :footnote, @font_size, body)
      end

      # SVG only: the marker kept on one line, at the largest size from font_size down to
      # min_font_size (the same 0.5px steps as shrink) at which it fits.
      def footnote_shrink(body, width)
        marker = @footnote_marker.gsub("{n}", (@footnotes.size + 1).to_s)
        size = largest_size { |candidate| @measurer.width(marker, size: candidate) <= width }
        return unless size

        @footnotes << "#{marker}: #{body}"
        result([marker], :footnote_shrink, size, body)
      end

      # SVG only: the label turned 90 degrees, so its line height must fit the cell's width.
      # Its length sets the row's height (Renderers::Svg::Geometry).
      def rotate(text, width)
        size = largest_size { |candidate| candidate <= width }
        result([text], :rotate, size) if size
      end

      def largest_size
        return unless @font_size && @min_font_size

        size = @font_size
        while size >= @min_font_size
          return size if yield(size)

          size -= 0.5
        end
        nil
      end

      def truncate(text, width, path)
        suffix = fits?("…", width) ? "…" : ""
        remaining = width - @measurer.width(suffix)
        prefix = +""
        text.scan(/\X/) do |char|
          char_width = @measurer.width(char)
          # SVG widths can accumulate subpixel floating-point roundoff.
          break if char_width > remaining + 1e-9

          prefix << char
          remaining -= char_width
        end
        @issues << Issue.new(:warning, "V-09", path, nil, "label was truncated to fit its cell")
        result([prefix + suffix], :truncate)
      end
    end
  end
end
