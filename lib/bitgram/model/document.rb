# frozen_string_literal: true

module Bitgram
  module Model
    # @api private
    Document = Data.define(:title, :description, :layout, :ascii, :svg, :raster, :fields, :notes, :annotations)

    # @api private
    # A line of text under the fields: per field (values keyed by field id), or per bit.
    Annotation = Data.define(:label, :values, :per_bit, :style, :fill)
  end
end
