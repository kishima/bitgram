# frozen_string_literal: true

module Bitgram
  # Logical rows and cells shared by all output formats.
  module Layout
    # A logical row; span counts physical rows in a merged block.
    Row = Data.define(:index, :kind, :cells, :span, :offset_bits)
  end
end
