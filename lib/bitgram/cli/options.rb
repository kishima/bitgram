# frozen_string_literal: true

module Bitgram
  # @api private
  class CLI
    private

    def parser_for(command, options)
      OptionParser.new do |parser|
        parser.banner = "Usage: bitgram #{command} #{command == 'validate' ? 'INPUT...' : '[options]'}"
        parser.on("-h", "--help", "Show help") { options[:help] = true }
        parser.on("--debug", "Show failure backtraces") { @debug = true }
        next unless %w[render validate].include?(command)

        parser.on("--strict", "Treat warnings as errors") { options[:strict] = true }
        parser.on("--input-format FORMAT", %w[yaml json], "Input format") do |value|
          options[:input_format] = value.to_sym
        end
        render_options(parser, options) if command == "render"
      end
    end

    def render_options(parser, options)
      parser.on("-f", "--format FORMAT", %w[ascii svg png jpeg]) { |value| options[:format] = value }
      parser.on("-o", "--output PATH") { |value| options[:output] = value }
      parser.on("--preset NAME") { |value| options[:preset] = value }
      {
        "--row-bits N" => ["layout.row_bits", Integer], "--bit-order ORDER" => ["layout.bit_order", String],
        "--ascii-style STYLE" => ["ascii.style", String], "--theme NAME_OR_PATH" => ["svg.theme", String],
        "--scale N" => ["raster.scale", Float], "--rasterizer NAME" => ["raster.rasterizer", String]
      }.each do |flag, (key, type)|
        parser.on(flag, type) { |value| assign(options[:overrides], key, value) }
      end
      parser.on("--set KEY=VALUE") do |value|
        key, raw = value.split("=", 2)
        raise OptionParser::InvalidArgument, "--set requires KEY=VALUE" unless raw

        assign(options[:settings], key, parse_value(raw))
      end
    end

    def assign(target, key, value)
      parts = key.split(".", -1)
      unless parts.all? { |part| /\A[a-z_]+\z/.match?(part) }
        raise OptionParser::InvalidArgument, "invalid setting key: #{key}"
      end

      leaf = parts.pop
      parts.each do |part|
        target[part] ||= {}
        raise OptionParser::InvalidArgument, "conflicting setting key: #{key}" unless target[part].is_a?(Hash)

        target = target[part]
      end
      target[leaf] = value
    end

    def parse_value(value)
      return value == "true" if %w[true false].include?(value)
      return value.to_i if /\A-?\d+\z/.match?(value)
      return value.to_f if /\A-?\d+\.\d+\z/.match?(value)

      value
    end
  end
end
