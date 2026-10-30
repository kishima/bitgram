# frozen_string_literal: true

module Bitgram
  # @api private
  class CLI
    private

    def doctor
      @stdout.puts("Ruby          #{RUBY_VERSION}\nbitgram       #{VERSION}")
      labels = { vips: "vips", rsvg: "rsvg-convert", imagemagick: "ImageMagick" }
      Rasterizers::Registry.all.each do |name, converter|
        state = converter.available? ? "available (#{converter.version})" : "not found"
        @stdout.puts("#{labels.fetch(name).ljust(14)}#{state}")
      end
      require_relative "../pdf/chromium"
      @stdout.puts("Chromium      #{Pdf::Chromium.locate || 'not found'} (PDF output)")
      @stdout.puts("CJK font      #{cjk_fonts}")
      selections = %i[png jpeg].map do |format|
        "#{format}: #{Rasterizers::Registry.select(:auto, format: format, timeout: 30).name}"
      rescue RasterizerNotFound
        "#{format}: unavailable"
      end
      @stdout.puts("=> #{selections.join(', ')}")
    end

    def cjk_fonts
      executable = Util::Command.which("fc-list")
      return "unknown (fc-list not installed)" unless executable

      fonts = Util::Command.run([executable, ":lang=ja", "family"], stdin_data: "", timeout: 5)
      fonts.strip.empty? ? "not found" : "found (#{fonts.lines.first.strip})"
    rescue RasterizeError
      "unknown (fontconfig failed)"
    end
  end
end
