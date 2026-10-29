# frozen_string_literal: true

require "did_you_mean"

module Bitgram
  # @api private
  # Uses the shipped schema for structural checks, then checks relationships between fields.
  class Validator
    SCHEMA = Config.deep_freeze(JSON.parse(File.read(File.expand_path("../../schema/bitgram.schema.json", __dir__))))

    def initialize(line_map: {})
      @line_map = line_map
    end

    def call(data)
      @issues = []
      check(data, SCHEMA, "$")
      check_fields(data) if data.is_a?(Hash) && data["fields"].is_a?(Array)
      @issues
    end

    private

    def add(code, path, message, severity = :error)
      parent = path
      until @line_map.key?(parent) || parent == "$" || parent.empty?
        ancestor = parent.sub(/(?:\.[^.\[]+|\[\d+\])\z/, "")
        parent = ancestor == parent ? "$" : ancestor
      end
      @issues << Issue.new(severity, code, path, @line_map[parent], message)
    end

    def check(value, rule, path)
      rule = SCHEMA.fetch("$defs").fetch(rule["$ref"].split("/").last) if rule["$ref"]
      if rule["type"] && Array(rule["type"]).none? { |type| type_match?(value, type) }
        add("V-03", path, "must be #{Array(rule['type']).join(' or ')}")
        return
      end
      check_scalar(value, rule, path)
      check_object(value, rule, path) if value.is_a?(Hash)
      check_array(value, rule, path) if value.is_a?(Array)
      check_choice(value, rule, path) if rule["oneOf"]
    end

    def check_choice(value, rule, path)
      if path.match?(/\A\$\.fields\[\d+\]\z/)
        add("V-04", path, "specify exactly one of bits and bytes") unless (value.keys & %w[bits bytes]).size == 1
      elsif rule["oneOf"].count { |branch| matches?(value, branch) } != 1
        add("V-03", path, "value does not match an allowed type or range")
      end
    end

    def type_match?(value, type)
      case type
      when "object" then value.is_a?(Hash)
      when "array" then value.is_a?(Array)
      when "string" then value.is_a?(String)
      when "integer" then value.is_a?(Integer)
      when "number" then value.is_a?(Numeric) && value.real? && value.finite?
      when "boolean" then [true, false].include?(value)
      end
    end

    def matches?(value, rule)
      previous = @issues
      @issues = []
      check(value, rule, "$")
      @issues.empty?
    ensure
      @issues = previous
    end

    def check_scalar(value, rule, path)
      if rule.key?("const") && value != rule["const"]
        add(path == "$.version" ? "V-01" : "V-03", path, "must equal #{rule['const'].inspect}")
      end
      add("V-03", path, "must be one of #{rule['enum'].join(', ')}") if rule["enum"] && !rule["enum"].include?(value)
      check_number(value, rule, path) if value.is_a?(Numeric)
      check_string(value, rule, path) if value.is_a?(String)
    end

    def check_number(value, rule, path)
      unless value.real? && value.finite?
        add("V-03", path, "must be finite")
        return
      end
      add("V-03", path, "must be at least #{rule['minimum']}") if rule["minimum"] && value < rule["minimum"]
      add("V-07", path, "must be at most #{rule['maximum']}") if rule["maximum"] && value > rule["maximum"]
    end

    def check_string(value, rule, path)
      unless value.valid_encoding? && !value.match?(/[\x00-\x08\x0b\x0c\x0e-\x1f\uFFFE\uFFFF]/)
        add("V-03", path,
            "must be valid UTF-8 text without control characters")
        return
      end
      if rule["minLength"] && value.length < rule["minLength"]
        add("V-03", path,
            "must have at least #{rule['minLength']} characters")
      end
      if rule["maxLength"] && value.length > rule["maxLength"]
        add("V-07", path,
            "must have at most #{rule['maxLength']} characters")
      end
      pattern = rule["pattern"]
      return unless pattern && !Regexp.new("\\A#{pattern.delete_prefix('^').delete_suffix('$')}\\z").match?(value)

      add("V-03", path,
          "invalid format")
    end

    def check_object(value, rule, path)
      properties = rule.fetch("properties", {})
      if rule["additionalProperties"] == false
        (value.keys - properties.keys).each do |key|
          hint = DidYouMean::SpellChecker.new(dictionary: properties.keys).correct(key.to_s).first
          add("V-02", "#{path}.#{key}", "unknown key #{key.inspect}#{" (did you mean #{hint.inspect}?)" if hint}")
        end
      end
      Array(rule["required"]).each { |key| add("V-03", "#{path}.#{key}", "is required") unless value.key?(key) }
      properties.each { |key, child| check(value[key], child, "#{path}.#{key}") if value.key?(key) }
    end

    def check_array(value, rule, path)
      add("V-03", path, "must not be empty") if rule["minItems"] && value.size < rule["minItems"]
      if rule["maxItems"] && value.size > rule["maxItems"]
        add("V-07", path,
            "too many items (maximum #{rule['maxItems']})")
        return
      end
      add("V-03", path, "items must be unique") if rule["uniqueItems"] && value.uniq.size != value.size
      value.each_with_index { |item, i| check(item, rule["items"], "#{path}[#{i}]") } if rule["items"]
    end

    def check_fields(data)
      return if data["fields"].size > 10_000

      fields = data["fields"].grep(Hash)
      seen = {}
      fields.each_with_index do |field, i|
        id = field["id"]
        add("V-05", "$.fields[#{i}].id", "duplicate id #{id.inspect}") if id && seen[id]
        seen[id] = true if id
      end
      return if @issues.any? { |issue| issue.severity == :error }

      check_positions(fields, data.fetch("layout", {}))
    end

    def check_positions(fields, layout)
      width = layout.fetch("row_bits", 32)
      pos = 0
      fields.each_with_index do |field, i|
        variable = field["bits"] == "variable"
        bits = variable ? field.fetch("display_bits", width) : field.fetch("bits") { field["bytes"] * 8 }
        check_variable(field, i, pos, width, bits) if variable
        pos += bits
      end
      add("V-07", "$.fields", "diagram exceeds 4096 logical rows") if (pos.to_f / width).ceil > 4096
      return unless pos % width != 0 && !layout["allow_partial_row"]

      add("V-08", "$.fields", "last row is #{pos % width}/#{width} bits; set layout.allow_partial_row to silence",
          :warning)
    end

    def check_variable(field, index, position, width, bits)
      if !field.key?("display_bits") && position % width != 0
        add("V-06", "$.fields[#{index}]", "full-width variable field must start at a row boundary")
      elsif bits > width - (position % width)
        add("V-10", "$.fields[#{index}].display_bits", "variable field extends past the row boundary", :warning)
      end
    end
  end
end
