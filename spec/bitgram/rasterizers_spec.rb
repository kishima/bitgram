# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "bitgram/rasterizers/registry"

RSpec.describe "Rasterizers" do
  let(:svg) do
    '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10">' \
      '<rect x="5" y="2" width="10" height="6" fill="red"/></svg>'
  end

  def require_converter(name)
    converter = Bitgram::Rasterizers::Registry.all.fetch(name)
    unless converter.available?
      raise "#{name} is required in raster CI" if ENV["REQUIRE_RASTER"] == "1"

      skip "#{name} is unavailable"
    end
    converter
  end

  def check_jpeg_pixels(path)
    if Bitgram::Rasterizers::Registry.all[:vips].available?
      decoded = Vips::Image.new_from_file(path)
      expect([decoded.width, decoded.height]).to eq([40, 20])
      [[0, 0], [39, 0], [0, 19], [39, 19]].each do |x, y|
        expect(decoded.getpoint(x, y).first(3)).to eq([255, 255, 255])
      end
    else
      binary = Bitgram::Util::Command.which("magick") || Bitgram::Util::Command.which("convert")
      dimensions = Bitgram::Util::Command.run([binary, path, "-format", "%w %h", "info:"], stdin_data: "", timeout: 10)
      expect(dimensions).to eq("40 20")
      [[0, 0], [39, 0], [0, 19], [39, 19]].each do |x, y|
        command = [binary, path, "-crop", "1x1+#{x}+#{y}", "+repage", "-depth", "8", "rgb:-"]
        expect(Bitgram::Util::Command.run(command, stdin_data: "", timeout: 10).bytes).to eq([255, 255, 255])
      end
    end
  end

  it "rejects JPEG with the PNG-only converter before invoking it" do
    expect { Bitgram::Rasterizers::Registry.select(:rsvg, format: :jpeg) }
      .to raise_error(Bitgram::RasterizerNotFound, /jpeg/)
  end

  it "provides installation instructions when no converter is available" do
    Bitgram::Rasterizers::Registry.all.each_value { |converter| allow(converter).to receive(:available?).and_return(false) }
    expect { Bitgram::Rasterizers::Registry.select(:auto, format: :png) }
      .to raise_error(Bitgram::RasterizerNotFound, /brew install.*apt-get/m)
  end

  it "chooses the first available converter supporting the requested format" do
    converters = Bitgram::Rasterizers::Registry.all
    allow(converters[:vips]).to receive(:available?).and_return(false)
    allow(converters[:rsvg]).to receive(:available?).and_return(true)
    expect(Bitgram::Rasterizers::Registry.select(:auto, format: :png)).to be_a(Bitgram::Rasterizers::Rsvg)
  end

  it "rejects unknown converters" do
    expect { Bitgram::Rasterizers::Registry.select(:missing, format: :png) }
      .to raise_error(Bitgram::RasterizerNotFound, /missing/)
  end

  it "applies the requested deadline to the initial availability probe" do
    converter = Bitgram::Rasterizers::ImageMagick.new
    allow(Bitgram::Rasterizers::Registry).to receive(:all).and_return({ imagemagick: converter })
    allow(Bitgram::Util::Command).to receive_messages(which: "magick", run: "")
    Bitgram::Rasterizers::Registry.select(:imagemagick, format: :png, timeout: 0.01)
    expect(Bitgram::Util::Command).to have_received(:run)
      .with(["magick", "svg:-", "png:-"], stdin_data: anything, timeout: 0.01)
  end

  %i[vips rsvg imagemagick].each do |name|
    it "produces a correctly scaled PNG with #{name}", :raster do
      converter = require_converter(name)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "image.png")
        converter.rasterize(svg, path: path, format: :png, scale: 2, background: "transparent", quality: 90)
        bytes = File.binread(path)
        expect(bytes.bytes.first(8)).to eq([137, 80, 78, 71, 13, 10, 26, 10])
        expect(bytes.byteslice(16, 8).unpack("NN")).to eq([40, 20])
        expect(converter.version).not_to eq("unavailable")
      end
    end
  end

  %i[vips imagemagick].each do |name|
    it "produces JPEG with #{name}", :raster do
      converter = require_converter(name)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "image.jpg")
        converter.rasterize(svg, path: path, format: :jpeg, scale: 2, background: "#ffffff", quality: 90)
        expect(File.binread(path).bytes.first(3)).to eq([255, 216, 255])
        check_jpeg_pixels(path)
      end
    end
  end
end
