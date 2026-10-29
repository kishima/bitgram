# frozen_string_literal: true

module Bitgram
  module Layout
    # A field segment in bit coordinates. Ranges are relative to its field.
    Cell = Data.define(:field, :col, :bits, :part, :range)
  end
end
