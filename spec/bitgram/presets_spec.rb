# frozen_string_literal: true

RSpec.describe "protocol presets" do
  { tcp: 160, udp: 64, ipv4: 160, ipv6: 320, icmp: 64, arp: 224 }.each do |name, bits|
    it "defines #{name} with #{bits} fixed bits" do
      expect(Bitgram.respond_to?(:preset)).to be true
      diagram = Bitgram.preset(name)
      expect(diagram.issues).to be_empty
      fields = diagram.layout.document.fields
      expect(fields.reject(&:variable?).sum(&:bits)).to eq(bits)
    end
  end

  it "models IPv4 Options and Padding in the same row" do
    row = Bitgram.preset(:ipv4).layout.rows[-2]
    expect(row.cells.map { |cell| [cell.field.name, cell.bits] }).to eq([["Options", 24], ["Padding", 8]])
  end

  it "models IPv6 addresses as four-row blocks" do
    rows = Bitgram.preset(:ipv6).layout.rows.select { |row| row.kind == :block }
    expect(rows.map(&:span)).to eq([4, 4])
  end
end
