# frozen_string_literal: true

require "erb"
require "fileutils"
require "tmpdir"
require_relative "../util/command"
require_relative "../renderers/svg/xml_builder"

module Bitgram
  # @api private
  module Pdf
    # @api private
    # Prints an SVG to a one-page PDF with headless Chromium. Text stays text, and fonts are
    # embedded by Chromium (TrueType fonts as /FontFile2 subsets).
    class Chromium
      NAMES = %w[chromium chromium-browser google-chrome google-chrome-stable chrome].freeze
      # Where `npx playwright install chromium` puts its browser.
      PLAYWRIGHT = ".cache/ms-playwright/*/chrome-linux64/chrome"
      ENVIRONMENT = "BITGRAM_CHROME"
      INSTALL = "No Chromium found for PDF output. Set pdf.chrome or #{ENVIRONMENT} to its path, " \
                "put chromium or google-chrome on PATH, or run `npx playwright install chromium`.".freeze

      # @return [String, nil] the first Chromium found: setting, environment, PATH, Playwright cache
      def self.locate(setting = nil)
        return setting if setting

        environment = ENV.fetch(ENVIRONMENT, "")
        return environment unless environment.empty?

        NAMES.each do |name|
          found = Util::Command.which(name)
          return found if found
        end
        playwright
      end

      def self.playwright
        Dir[File.join(Dir.home, PLAYWRIGHT)].select { |path| File.executable?(path) }
                                            .max_by { |path| path[%r{-(\d+)/chrome-linux64/}, 1].to_i }
      rescue ArgumentError
        nil # No home directory.
      end

      attr_reader :binary

      def initialize(binary:, timeout:, sandbox: true)
        @binary = binary
        @timeout = timeout
        @sandbox = sandbox
      end

      # The page is the SVG size rounded up to a multiple of page_step pixels, with the SVG
      # centered on it.
      def write(svg, width:, height:, path:, page_step:)
        raise RasterizerNotFound, INSTALL unless binary
        raise RasterizerNotFound, "Chromium not found at #{binary}" unless File.executable?(binary)

        page = [width, height].map { |value| self.class.page_size(value, page_step) }
        Dir.mktmpdir("bitgram-pdf") do |dir|
          html = File.join(dir, "diagram.html")
          output = File.join(dir, "diagram.pdf")
          File.write(html, self.class.html(svg, *page))
          Util::Command.run(command(html, output), stdin_data: "", timeout: @timeout)
          raise RasterizeError, "#{binary} did not write a PDF" unless File.file?(output)

          FileUtils.cp(output, path)
        end
        path
      end

      def command(html, output)
        flags = ["--headless", "--disable-gpu", "--no-pdf-header-footer", "--print-to-pdf=#{output}"]
        flags << "--no-sandbox" unless @sandbox
        [binary, *flags, file_url(html)]
      end

      def self.page_size(value, step)
        value = Renderers::Svg::XmlBuilder.number(value).to_f # The size written in the SVG.
        (value / step).ceil * step
      end

      def self.html(svg, width, height)
        <<~HTML
          <!doctype html>
          <html><head><meta charset="utf-8"><style>
          @page { size: #{width}px #{height}px; margin: 0; }
          html, body { margin: 0; padding: 0; width: #{width}px; height: #{height}px; overflow: hidden; }
          body { display: flex; align-items: center; justify-content: center; }
          svg { display: block; flex: none; }
          </style></head><body>
          #{svg}</body></html>
        HTML
      end

      private

      def file_url(path)
        "file://#{File.expand_path(path).split('/').map { |part| ERB::Util.url_encode(part) }.join('/')}"
      end
    end
  end
end
