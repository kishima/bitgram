# frozen_string_literal: true

require "optparse"
require_relative "rasterizers/registry"

module Bitgram
  # @api private
  class CLI
    COMMANDS = %w[render validate presets init doctor version].freeze
    FORMATS = { ".txt" => "ascii", ".svg" => "svg", ".png" => "png", ".jpg" => "jpeg", ".jpeg" => "jpeg",
                ".pdf" => "pdf" }.freeze

    def initialize(stdin: $stdin, stdout: $stdout, stderr: $stderr)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv)
      args = argv.dup
      @debug = args.delete("--debug")
      return help if %w[-h --help].include?(args.first)
      return version if %w[-v --version].include?(args.first)

      execute(args)
    rescue ValidationError => e
      report_issues(e.issues, @input_name)
      1
    rescue ParseError, LayoutError, RenderError => e
      failure(e, 1)
    rescue OptionParser::ParseError, ArgumentError => e
      failure(e, 2)
    rescue RasterizeError => e
      failure(e, 3)
    rescue SystemCallError, IOError => e
      failure(e, 4)
    rescue StandardError => e
      failure(e, 70)
    end

    private

    def execute(args)
      command = args.shift
      raise OptionParser::InvalidArgument, "expected #{COMMANDS.join(', ')}" unless COMMANDS.include?(command)

      options = { overrides: {}, settings: {} }
      parser = parser_for(command, options)
      parser.parse!(args)
      return @stdout.puts(parser) || 0 if options[:help]

      dispatch(command, args, options)
    end

    def help
      @stdout.puts("Usage: bitgram <command> [options]\n\nCommands: #{COMMANDS.join(', ')}")
      0
    end

    def version
      @stdout.puts(VERSION)
      0
    end

    def dispatch(command, args, options)
      case command
      when "render" then return render(args, options)
      when "validate" then return validate(args, options)
      when "init" then return init(args)
      end

      simple_command(command, args)
    end

    def simple_command(command, args)
      raise OptionParser::InvalidArgument, "unexpected arguments: #{args.join(' ')}" unless args.empty?

      case command
      when "presets" then @stdout.puts(Bitgram.presets)
      when "doctor" then doctor
      when "version" then return version
      end
      0
    end

    def render(args, options)
      diagram = render_input(args, options)
      output = options[:output]
      format = output_format(options)
      rendered = format == "ascii" ? diagram.to_ascii : diagram.to_svg
      report_issues(diagram.issues, @input_name)
      return 1 if options[:strict] && !diagram.issues.empty?

      write_output(diagram, rendered, output, format)
      0
    end

    def render_input(args, options)
      preset = options[:preset]
      expected = preset ? 0 : 1
      raise OptionParser::InvalidArgument, "provide one INPUT or --preset NAME" unless args.length == expected

      check_preset(preset) if preset
      output_format(options)
      @input_name = preset ? "preset:#{preset}" : args.first
      overrides = Config.deep_merge(options[:overrides], options[:settings])
      return Bitgram.preset(preset, config: options[:config], **overrides) if preset

      read_diagram(args.first, options, overrides)
    end

    def output_format(options)
      output = options[:output]
      format = options[:format] || FORMATS[File.extname(output.to_s).downcase] || "ascii"
      if %w[png jpeg pdf].include?(format) && [nil, "-"].include?(output)
        raise OptionParser::InvalidArgument, "#{format} requires --output PATH"
      end

      format
    end

    def write_output(diagram, rendered, output, format)
      if [nil, "-"].include?(output)
        @stdout.write(rendered)
      elsif %w[ascii svg].include?(format)
        File.write(output, rendered)
      else
        diagram.save(output, format: format.to_sym)
      end
    end

    def read_diagram(path, options, overrides = {})
      if path == "-"
        input = @stdin.read(Loader::MAX_BYTES + 1)
        return Bitgram.load(input, format: options[:input_format], config: options[:config], **overrides)
      end

      Bitgram.load_file(path, format: options[:input_format], config: options[:config], **overrides)
    end

    def validate(args, options)
      raise OptionParser::MissingArgument, "INPUT" if args.empty?

      codes = args.map do |path|
        issues = if path == "-"
                   read_diagram(path, options).issues
                 else
                   Bitgram.validate_file(path, format: options[:input_format], config: options[:config])
                 end
        report_issues(issues, path)
        issues.any? { |issue| issue.severity == :error || options[:strict] } ? 1 : 0
      rescue ValidationError => e
        report_issues(e.issues, path)
        1
      rescue ParseError => e
        failure(e, 1)
      rescue SystemCallError, IOError => e
        failure(e, 4)
      end
      codes.max
    end

    def init(args)
      raise OptionParser::InvalidArgument, "init accepts at most one PRESET" if args.length > 1

      name = args.first || "udp"
      check_preset(name)
      @stdout.write(File.read(File.join(__dir__, "presets", "#{name}.yml"), encoding: "UTF-8"))
      0
    end

    def check_preset(name)
      return if Bitgram.presets.include?(name)

      raise OptionParser::InvalidArgument, "unknown preset #{name.inspect}; choose #{Bitgram.presets.join(', ')}"
    end

    def report_issues(issues, filename)
      issues.each do |issue|
        location = [filename, issue.line].compact.join(":")
        @stderr.puts("#{location}: #{issue.severity} #{issue.code} #{issue.path}: #{issue.message}")
      end
    end

    def failure(error, code)
      @stderr.puts(error.message)
      @stderr.puts(error.backtrace) if @debug
      code
    end
  end
end

require_relative "cli/options"
require_relative "cli/doctor"
