# frozen_string_literal: true

module Bitgram
  # @api private
  module Model
    # @api private
    Field = Data.define(:id, :name, :short, :bits, :variable, :display_bits,
                        :description, :value, :reserved, :optional, :classes, :fill,
                        :bit_numbers) do
      def variable? = variable
      def width_bits = variable ? display_bits : bits
    end
  end
end
