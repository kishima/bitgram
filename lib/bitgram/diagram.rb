# frozen_string_literal: true

module Bitgram
  # A validated diagram with shared logical layout and format-specific rendering.
  class Diagram
    # @api private
    def initialize(document, issues: [], source: nil)
      @document = document
      @issues = issues.dup
      @source = source
    end

    # Logical bit coordinates for custom renderers and inspection.
    # @return [Layout::Result]
    def layout
      @layout ||= Layout::Engine.new.call(@document)
    end

    # Validation warnings and findings collected during rendering.
    # @return [Array<Issue>]
    def issues
      (@issues + layout.issues).uniq.freeze
    end

    # Render RFC or Unicode text. Keywords override the definition's ascii section.
    # @return [String]
    def to_ascii(**options)
      render(:ascii, options).first
    end

    # Render SVG. Keywords override the definition's svg section.
    # @return [String]
    def to_svg(**options)
      render(:svg, options).first
    end

    # Write a diagram, inferring format from the extension unless specified.
    # @param path [String] output filename
    # @param format [Symbol, nil] ascii, svg, png, jpeg, or pdf
    # @return [String] output filename
    def save(path, format: nil, **options)
      format = (format || File.extname(path.to_s).delete_prefix(".")).to_s
      format = { "txt" => "ascii", "jpg" => "jpeg" }.fetch(format, format)
      case format
      when "ascii" then File.write(path, to_ascii(**options))
      when "svg" then File.write(path, to_svg(**options))
      when "png", "jpeg" then save_raster(path, format.to_sym, options)
      when "pdf" then save_pdf(path, options)
      else raise ArgumentError, "unknown output format: #{format}"
      end
      path.to_s
    end

    private

    def render(kind, options)
      validate_options(kind, options)
      require_relative "renderers/#{kind}"
      klass = kind == :ascii ? Renderers::Ascii : Renderers::Svg
      renderer = klass.new(layout, **options)
      output = renderer.render
      @issues |= renderer.issues
      [output, renderer]
    end

    def validate_options(kind, options)
      raw = Config.deep_merge(@source || { "version" => 1, "fields" => [] }, kind.to_s => Config.stringify(options))
      errors = Validator.new.call(raw).select { |issue| issue.severity == :error }
      raise ValidationError, errors unless errors.empty?
    end

    # PDF options: pdf section keys and raster.timeout; everything else goes to the SVG renderer.
    def save_pdf(path, options)
      pdf_keys = Config::DEFAULTS["pdf"].keys + ["chrome"]
      grouped = options.group_by do |key, _|
        next :pdf if pdf_keys.include?(key.to_s)

        key.to_s == "timeout" ? :raster : :svg
      end.transform_values(&:to_h)
      validate_options(:pdf, grouped.fetch(:pdf, {}))
      validate_options(:raster, grouped.fetch(:raster, {}))
      config = Config.deep_merge(Config::DEFAULTS["pdf"], (@source || {}).fetch("pdf", {}))
      config = Config.deep_merge(config, Config.stringify(grouped.fetch(:pdf, {})))
      timeout = Config.deep_merge(@document.raster, Config.stringify(grouped.fetch(:raster, {})))["timeout"]
      svg, renderer = render(:svg, grouped.fetch(:svg, {}).merge(inline_styles: true))

      require_relative "pdf/chromium"
      printer = Pdf::Chromium.new(binary: Pdf::Chromium.locate(config["chrome"]), timeout: timeout,
                                  sandbox: config["sandbox"])
      printer.write(svg, width: renderer.width, height: renderer.height, path: path.to_s,
                         page_step: config["page_step"])
    end

    def save_raster(path, format, options)
      svg_keys = Config::DEFAULTS["svg"].keys + ["id_prefix"]
      svg_options, raster_options = options.partition { |key, _| svg_keys.include?(key.to_s) }.map(&:to_h)
      validate_options(:raster, raster_options)
      config = Config.deep_merge(@document.raster, Config.stringify(raster_options))
      background = config.fetch("background", format == :jpeg ? "#ffffff" : "transparent")
      raise RenderError, "JPEG cannot use a transparent background" if format == :jpeg && background == "transparent"

      svg, renderer = render(:svg, svg_options.merge(inline_styles: true))
      if renderer.width * renderer.height * (config["scale"]**2) > 50_000_000
        raise RenderError, "output exceeds 50 million pixels; lower raster.scale"
      end

      require_relative "rasterizers/registry"
      converter = Rasterizers::Registry.select(config["rasterizer"], format: format, timeout: config["timeout"])
      converter.rasterize(svg, path: path.to_s, format: format, scale: config["scale"],
                               background: background, quality: config["quality"])
    end
  end
end
