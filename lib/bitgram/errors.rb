# frozen_string_literal: true

module Bitgram
  # Base error for definition and rendering failures.
  class Error < StandardError; end
  # Malformed or unsafe serialized input.
  class ParseError < Error; end

  # Invalid definition; all validation findings are available in #issues.
  class ValidationError < Error
    attr_reader :issues

    def initialize(issues)
      @issues = issues.freeze
      super(issues.join("\n"))
    end
  end

  # The definition cannot be laid out.
  class LayoutError < Error; end
  # The requested output cannot be rendered.
  class RenderError < Error; end
  # Raster conversion failed.
  class RasterizeError < Error; end
  # No installed converter supports the requested format.
  class RasterizerNotFound < RasterizeError; end
  # An external converter exceeded its deadline.
  class RasterizerTimeout < RasterizeError; end
end
