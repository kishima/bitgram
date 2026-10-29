# frozen_string_literal: true

require_relative "base"
require_relative "../util/command"

module Bitgram
  module Rasterizers
    # @api private
    class Rsvg < Base
      def available?
        return @available unless @available.nil?

        @binary = Util::Command.which("rsvg-convert")
        @available = !@binary.nil?
      end

      def supports?(format)
        format.to_sym == :png
      end

      def rasterize(svg, path:, format:, scale:, background:, **)
        check_format(format)
        raise RasterizerNotFound, "rsvg-convert is unavailable" unless available?

        command = [@binary, "--format", "png", "--zoom", scale.to_s, "--output", File.expand_path(path)]
        command.push("--background-color", background) if background && background != "transparent"
        Util::Command.run(command, stdin_data: svg, timeout: @timeout)
      end

      def version
        available? ? Util::Command.run([@binary, "--version"], stdin_data: "", timeout: @timeout).strip : "unavailable"
      end
    end
  end
end
