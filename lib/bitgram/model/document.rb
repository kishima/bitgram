# frozen_string_literal: true

module Bitgram
  module Model
    # @api private
    Document = Data.define(:title, :description, :layout, :ascii, :svg, :raster, :fields, :notes)
  end
end
