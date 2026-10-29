# frozen_string_literal: true

require_relative "base"

module Bitgram
  module Rasterizers
    # @api private
    class Vips < Base
      def available?
        return @available unless @available.nil?

        @available = false
        require "vips"
        ::Vips::Image.svgload_buffer(PROBE)
        @available = true
      rescue LoadError, StandardError
        false
      end

      def rasterize(svg, path:, format:, scale:, background:, quality:)
        check_format(format)
        raise RasterizerNotFound, "ruby-vips with SVG support is unavailable" unless available?

        image = ::Vips::Image.svgload_buffer(svg, scale: scale)
        image = image.flatten(background: rgb(background)) if background && background != "transparent"
        if format.to_sym == :png
          image.pngsave(path)
        else
          image.jpegsave(path, Q: quality)
        end
      rescue StandardError => e
        raise if e.is_a?(Bitgram::Error)

        raise RasterizeError, "vips failed: #{e.message}"
      end

      def version
        available? ? "libvips #{::Vips.version_string}, svgload: yes" : "unavailable"
      end

      private

      def rgb(color)
        # Let the SVG backend interpret the same validated CSS colors as the diagram.
        swatch = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">' \
                 "<rect width=\"1\" height=\"1\" fill=\"#{color}\"/></svg>"
        ::Vips::Image.svgload_buffer(swatch).getpoint(0, 0).first(3)
      end
    end
  end
end
