# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Bitgram::Diagram do
  it "saves text and SVG using extension detection and returns the path" do
    Dir.mktmpdir do |dir|
      diagram = Bitgram.preset(:udp)
      %w[txt svg].each do |extension|
        path = File.join(dir, "diagram.#{extension}")
        expect(diagram.save(path)).to eq(path)
        expect(File.read(path)).to eq(extension == "txt" ? diagram.to_ascii : diagram.to_svg)
      end
      expect { diagram.save(File.join(dir, "x.pdf")) }.to raise_error(ArgumentError)
    end
  end

  it "reports truncation once without mutating the document or its original options" do
    diagram = Bitgram.load(version: 1, layout: { row_bits: 1 }, fields: [{ name: "ABCDE", bits: 1 }])
    2.times { diagram.to_ascii(fit_order: [:truncate]) }
    expect(diagram.issues.count { |issue| issue.code == "V-09" }).to eq(1)
    expect(diagram.layout.document.ascii["fit_order"]).to include("footnote")
  end

  it "rejects excessive raster dimensions and transparent JPEG before invoking converters" do
    diagram = Bitgram.preset(:udp)
    expect { diagram.save("unused.jpg", background: "transparent") }.to raise_error(Bitgram::RenderError, /transparent/)
    expect { diagram.save("unused.png", bit_width: 1024, row_height: 4096, scale: 8) }
      .to raise_error(Bitgram::RenderError, /50 million pixels/)
    expect(File).not_to exist("unused.jpg")
    expect(File).not_to exist("unused.png")
  end
end
