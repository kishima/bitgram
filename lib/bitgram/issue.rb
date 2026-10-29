# frozen_string_literal: true

module Bitgram
  # A validation or rendering finding, including a JSON path and optional YAML line.
  Issue = Data.define(:severity, :code, :path, :line, :message) do
    # Format the finding for logs and command-line diagnostics.
    def to_s
      [line && "line #{line}:", severity, code, "#{path}:", message].compact.join(" ")
    end
  end
end
