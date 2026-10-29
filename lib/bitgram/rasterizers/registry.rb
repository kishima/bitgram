# frozen_string_literal: true

require_relative "vips"
require_relative "rsvg"
require_relative "image_magick"

module Bitgram
  module Rasterizers
    # @api private
    module Registry
      INSTALL = "Install a rasterizer: macOS: brew install vips librsvg imagemagick; " \
                "Ubuntu: sudo apt-get install libvips-dev librsvg2-bin imagemagick. " \
                "For vips, also add gem 'ruby-vips' to your Gemfile."

      module_function

      def all
        @all ||= { vips: Vips.new, rsvg: Rsvg.new, imagemagick: ImageMagick.new }
      end

      def select(name = :auto, format:, timeout: 30)
        candidates = name.to_s == "auto" ? all.values : [all[name.to_sym]].compact
        converter = candidates.find do |item|
          item.timeout = timeout
          item.supports?(format) && item.available?
        end
        raise RasterizerNotFound, "No #{name} rasterizer available for #{format}. #{INSTALL}" unless converter

        converter.dup.tap { |selected| selected.timeout = timeout }
      end
    end
  end
end
