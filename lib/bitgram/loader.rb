# frozen_string_literal: true

require "json"
require "yaml"

module Bitgram
  # @api private
  class Loader
    MAX_BYTES = 1024 * 1024
    Source = Data.define(:data, :line_map, :filename)

    def load_file(path, format: nil)
      content = File.open(path, "r:UTF-8") { |file| file.read(MAX_BYTES + 1) }
      format ||= :json if File.extname(path).downcase == ".json"
      load_string(content, format: format, filename: path.to_s)
    end

    def load_string(str, format: nil, filename: nil)
      raise ParseError, "input too large (> 1 MiB)" if str.bytesize > MAX_BYTES
      raise ParseError, "input must be valid UTF-8" unless str.dup.force_encoding("UTF-8").valid_encoding?

      str = str.dup.force_encoding("UTF-8")
      format = (format || (str.lstrip.start_with?("{", "[") ? :json : :yaml)).to_sym
      case format
      when :json then Source.new(JSON.parse(str, max_nesting: 20), {}, filename)
      when :yaml, :yml
        map = {}
        ast = Psych.parse_stream(str, filename: filename)
        raise ParseError, "expected one YAML document" if ast.children.length > 1

        walk(ast.children.first&.root, "$", map, 0)
        data = YAML.safe_load(str, permitted_classes: [], aliases: false, filename: filename)
        Source.new(data, map, filename)
      else raise ArgumentError, "unknown input format: #{format}"
      end
    rescue JSON::ParserError, Psych::Exception, EncodingError => e
      raise ParseError, "#{filename || '<input>'}: #{e.message}"
    end

    private

    def walk(node, path, map, depth)
      return unless node
      raise ParseError, "input nesting exceeds 20 levels" if depth > 20

      map[path] = node.start_line + 1
      case node
      when Psych::Nodes::Mapping
        node.children.each_slice(2) do |key, value|
          raise ParseError, "YAML mapping keys must be scalar strings" unless key.is_a?(Psych::Nodes::Scalar)

          walk(value, "#{path}.#{key.value}", map, depth + 1)
        end
      when Psych::Nodes::Sequence
        node.children.each_with_index { |child, i| walk(child, "#{path}[#{i}]", map, depth + 1) }
      end
    end
  end
end
