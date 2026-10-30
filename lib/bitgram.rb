# frozen_string_literal: true

require_relative "bitgram/version"
require_relative "bitgram/errors"
require_relative "bitgram/issue"
require_relative "bitgram/config"
require_relative "bitgram/loader"
require_relative "bitgram/validator"
require_relative "bitgram/model/field"
require_relative "bitgram/model/document"
require_relative "bitgram/normalizer"
require_relative "bitgram/layout/engine"
require_relative "bitgram/diagram"

# Declarative packet and bit-field diagrams with shared layout across output formats.
module Bitgram
  autoload :CLI, "bitgram/cli"
  # Load a YAML/JSON string or Ruby Hash and apply nested configuration overrides.
  # @param config [String, Hash, nil] shared settings file (or Hash) applied beneath the definition
  # @return [Diagram]
  def self.load(input = nil, format: nil, config: nil, **overrides)
    if input.nil?
      input = overrides
      overrides = {}
    end
    source = if input.is_a?(Hash)
               Loader::Source.new(Config.stringify(input), {},
                                  nil)
             else
               Loader.new.load_string(input, format: format)
             end
    build(source, overrides, config)
  end

  # Load a definition from disk.
  # @param config [String, Hash, nil] shared settings file (or Hash) applied beneath the definition
  # @return [Diagram]
  def self.load_file(path, format: nil, config: nil, **overrides)
    build(Loader.new.load_file(path, format: format), overrides, config)
  end

  # Validate a file without raising definition or parse exceptions.
  # @return [Array<Issue>]
  def self.validate_file(path, format: nil, config: nil, **overrides)
    source = Loader.new.load_file(path, format: format)
    Validator.new(line_map: source.line_map).call(compose(source.data, overrides, config))
  rescue ParseError => e
    [Issue.new(:error, "PARSE", "$", nil, e.message)]
  end

  # Names of bundled protocol definitions.
  # @return [Array<String>]
  def self.presets
    Dir[File.join(__dir__, "bitgram/presets/*.yml")].map { |path| File.basename(path, ".yml") }.sort
  end

  # Load a bundled protocol definition.
  # @return [Diagram]
  def self.preset(name, **overrides)
    raise ArgumentError, "unknown preset: #{name}; choose #{presets.join(', ')}" unless presets.include?(name.to_s)

    load_file(File.join(__dir__, "bitgram/presets/#{name}.yml"), **overrides)
  end

  # Build a definition with the Ruby DSL, using the same validation as file inputs.
  # @return [Diagram]
  def self.define(**, &)
    require_relative "bitgram/dsl"
    dsl = DSL.new(**)
    dsl.instance_eval(&)
    load(dsl.to_h)
  end

  # @api private
  # Settings layer from lowest to highest: built-in defaults (Normalizer), the shared config,
  # the definition, then overrides (dedicated CLI options, --set, API keywords).
  def self.compose(data, overrides, config)
    return data unless data.is_a?(Hash)

    data = Config.deep_merge(Config.read_shared(config), data) if config
    Config.deep_merge(data, Config.stringify(overrides))
  end
  private_class_method :compose

  # @api private
  def self.build(source, overrides, config = nil)
    data = compose(source.data, overrides, config)
    issues = Validator.new(line_map: source.line_map).call(data)
    raise ValidationError, issues if issues.any? { |issue| issue.severity == :error }

    Diagram.new(Normalizer.new.call(data), issues: issues, source: Config.deep_freeze(Config.stringify(data)))
  end
  private_class_method :build
end
