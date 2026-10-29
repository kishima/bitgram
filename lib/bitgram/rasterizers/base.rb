# frozen_string_literal: true

module Bitgram
  # @api private
  module Rasterizers
    # @api private
    class Base
      PROBE = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>'

      attr_writer :timeout

      def initialize(timeout: 30)
        @timeout = timeout
      end

      def name
        self.class.name.split("::").last.downcase
      end

      def available?
        raise NotImplementedError
      end

      def supports?(format)
        %i[png jpeg].include?(format.to_sym)
      end

      def rasterize(*)
        raise NotImplementedError
      end

      def version
        "unknown"
      end

      private

      def check_format(format)
        raise RasterizeError, "#{name} does not support #{format}" unless supports?(format)
      end
    end
  end
end
