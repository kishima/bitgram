# frozen_string_literal: true

module Bitgram
  # @api private
  module Config
    module_function

    def deep_freeze(value)
      case value
      when Hash then value.each do |key, item|
        key.freeze
        deep_freeze(item)
      end
      when Array then value.each { |item| deep_freeze(item) }
      end
      value.freeze
    end

    DEFAULTS = {
      "layout" => { "row_bits" => 32, "bit_order" => "msb0", "bit_numbers" => true,
                    "offsets" => "none", "merge_rows" => true, "split_label" => "range",
                    "split_suffix" => " [{from}:{to}]", "allow_partial_row" => false },
      "ascii" => { "style" => "rfc", "indent" => 0, "variable_edge" => "dot", "max_label_lines" => 4,
                   "ambiguous_width" => 1, "fit_order" => %w[single wrap short vertical footnote truncate],
                   "footnote_marker" => "*{n}", "title" => "none" },
      "svg" => { "theme" => "default", "bit_width" => 20, "row_height" => 36, "margin" => 16,
                 "font_family" => "Helvetica, Arial, 'Noto Sans CJK JP', sans-serif", "font_size" => 13,
                 "min_font_size" => 9, "char_width_ratio" => 0.6, "bit_number_style" => "full",
                 "ticks" => true, "show_title" => true, "inline_styles" => false,
                 "fit_order" => %w[single shrink wrap short vertical footnote truncate] },
      "raster" => { "scale" => 2, "quality" => 90, "rasterizer" => "auto", "timeout" => 30 },
      # page_step: Chromium 153 reproduced page sizes that are multiples of 8 CSS px (6pt) exactly
      # in the PDF MediaBox and moved others by up to about 1px, sometimes downward (measured
      # 2026-10-30, docs/worklog/2026-10-30-book-b1-b3.md).
      "pdf" => { "page_step" => 8, "sandbox" => true }
    }.then { |defaults| deep_freeze(defaults) }

    SHARED_SECTIONS = %w[layout ascii svg raster pdf].freeze

    # Read a shared settings file (or Hash) holding only configuration sections, such as
    # the fonts and colors common to every diagram in a book. Values are validated against
    # the definition schema and reported with the settings file's own line numbers.
    def read_shared(config)
      source = config.is_a?(Hash) ? Loader::Source.new(stringify(config), {}, nil) : Loader.new.load_file(config.to_s)
      name = source.filename || "<config>"
      data = source.data
      raise ParseError, "#{name}: config must be an object" unless data.is_a?(Hash)

      unknown = data.keys - SHARED_SECTIONS
      unless unknown.empty?
        raise ParseError, "#{name}: config may contain only #{SHARED_SECTIONS.join(', ')} (found #{unknown.join(', ')})"
      end

      check_shared(data, source.line_map, name)
      data
    end

    def check_shared(data, line_map, name)
      probe = { "version" => 1, "fields" => [{ "name" => "probe", "bits" => 1 }] }.merge(data)
      errors = Validator.new(line_map: line_map).call(probe).select { |issue| issue.severity == :error }
      return if errors.empty?

      raise ParseError, errors.map { |issue|
        "#{[name, issue.line].compact.join(':')}: #{issue.code} #{issue.path}: #{issue.message}"
      }.join("\n")
    end

    def deep_merge(base, extra)
      base.merge(extra) do |_key, old, new|
        old.is_a?(Hash) && new.is_a?(Hash) ? deep_merge(old, new) : new
      end
    end

    def stringify(value, depth = 0)
      raise ParseError, "input nesting exceeds 20 levels (or contains a cycle)" if depth > 20

      case value
      when Hash
        value.to_h { |key, item| [key.to_s, stringify(item, depth + 1)] }
      when Array then value.map { |item| stringify(item, depth + 1) }
      when Symbol then value.to_s
      when String then value.dup.force_encoding(Encoding::UTF_8)
      when Numeric, true, false, nil then value
      else raise ParseError, "unsupported input type: #{value.class}"
      end
    end

    def slug(text)
      text.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end
  end
end
