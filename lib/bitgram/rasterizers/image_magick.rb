# frozen_string_literal: true

require_relative "base"
require_relative "../util/command"

module Bitgram
  module Rasterizers
    # @api private
    class ImageMagick < Base
      def available?
        return @available unless @available.nil?

        @binary = Util::Command.which("magick") || Util::Command.which("convert")
        @available = false
        return false unless @binary

        Util::Command.run([@binary, "svg:-", "png:-"], stdin_data: PROBE, timeout: @timeout)
        @available = true
      rescue RasterizeError
        false
      end

      def rasterize(svg, path:, format:, scale:, background:, quality:)
        check_format(format)
        raise RasterizerNotFound, "ImageMagick with SVG support is unavailable" unless available?

        color = background == "transparent" ? "none" : background || "none"
        command = [@binary, "-density", (96 * scale).to_s, "-background", color, "svg:-"]
        command << "-flatten" unless color == "none"
        command.push("-quality", quality.to_s, "#{format}:#{File.expand_path(path)}")
        Util::Command.run(command, stdin_data: svg, timeout: @timeout)
      end

      def version
        if available?
          Util::Command.run([@binary, "-version"], stdin_data: "",
                                                   timeout: @timeout).lines.first.strip
        else
          "unavailable"
        end
      end
    end
  end
end
