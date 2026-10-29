# frozen_string_literal: true

require "spec_helper"
require "bitgram/renderers/ascii"
require "unicode/display_width"

RSpec.describe "ASCII golden files" do
  def expect_golden(name, actual)
    path = File.expand_path("../../fixtures/golden/#{name}", __dir__)
    File.write(path, actual) if ENV["UPDATE_GOLDEN"] == "1"
    expect(actual).to eq(File.read(path))
  end

  styles = %w[rfc unicode]
  %w[tcp udp ipv4 ipv6 icmp arp].each do |preset|
    styles.each do |style|
      it "renders #{preset} with #{style} borders" do
        text = Bitgram.preset(preset).to_ascii(style: style)
        filename = style == "rfc" ? "#{preset}.txt" : "#{preset}_unicode.txt"
        expect_golden(filename, text)
        expect(text.lines.drop(2).map { |line| Unicode::DisplayWidth.of(line.chomp) }).to all(eq(65))
        expect(text.lines).to all(satisfy { |line| line.chomp == line.rstrip })
      end
    end
  end

  it "renders Japanese, footnotes, indentation, offsets, and lsb0" do
    japanese = Bitgram.load(version: 1, fields: [{ name: "送信元ポート", bits: 16 }, { name: "宛先ポート", bits: 16 }])
    expect_golden("japanese.txt", japanese.to_ascii)
    footnote = Bitgram.load(version: 1, fields: [{ name: "有効", bits: 1 }, { name: "Data", bits: 31 }])
    expect_golden("footnote.txt", footnote.to_ascii)
    expect_golden("indent3.txt", Bitgram.preset(:udp).to_ascii(indent: 3))
    raw = { version: 1, layout: { row_bits: 16, bit_order: :lsb0, offsets: :hex },
            fields: [{ name: "A", bits: 8 }, { name: "B", bits: 24 }] }
    expect_golden("offset_lsb0.txt", Bitgram.load(raw).to_ascii)
  end
end
