# Bitgram

Generate packet headers, bit fields, and register maps from YAML, JSON, or Ruby. One layout produces RFC-style ASCII, Unicode box drawings, SVG, PNG, and JPEG.

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            Length             |           Checksum            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
.                                                               .
.                             Data                              .
.                                                               .
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

<img src="examples/tcp.svg" alt="TCP header showing ports, sequence numbers, flags, and variable-length data">

## Installation

Requires Ruby 3.3 or later. ASCII and SVG need only the `unicode-display_width` runtime gem.

For a source checkout:

```sh
bundle install
bundle exec rake install
```

Once published on RubyGems:

```sh
gem install bitgram
```

PNG and JPEG need an optional converter. For the preferred vips backend, add `gem "ruby-vips", "~> 2.3"` to your application's Gemfile and install libvips:

```sh
# macOS
brew install vips librsvg imagemagick
# Ubuntu
sudo apt-get install libvips-dev librsvg2-bin imagemagick fonts-noto-cjk
```

Any one supported converter suffices. `rsvg-convert` supports PNG; vips and ImageMagick support PNG and JPEG. Automatic selection tries vips, rsvg, then ImageMagick. Run `bitgram doctor` to inspect availability and Japanese fonts.

## Quick start

Save this as `udp.yml`:

```yaml
version: 1
title: UDP Header
fields:
  - { name: Source Port, bits: 16 }
  - { name: Destination Port, bits: 16 }
  - { name: Length, bits: 16 }
  - { name: Checksum, bits: 16 }
  - { name: Data, bits: variable }
```

```sh
bitgram render udp.yml
bitgram render udp.yml -o udp.svg
bitgram render udp.yml -o udp.png --scale 2
bitgram render --preset tcp --ascii-style unicode
bitgram init ipv6 > ipv6.yml
bitgram validate udp.yml --strict
```

Set `layout.row_bits` for a width other than 32 bits, `layout.bit_order: lsb0` for register numbering, and `layout.offsets: hex` for byte offsets. Fields can use `bytes`, a `short` label, `reserved`, `optional`, and `fill`. See the [format reference](docs/format.md) and [CLI reference](docs/cli.md).

## Ruby API

```ruby
require "bitgram"

diagram = Bitgram.load_file("udp.yml")
puts diagram.to_ascii(style: :unicode)
diagram.save("udp.svg", theme: "dark")
diagram.save("udp.jpg", scale: 2, quality: 85)

register = Bitgram.define(title: "CTRL") do
  row_bits 16
  bit_order :lsb0
  field "EN", bits: 1, description: "Enable"
  field "MODE", bits: 3
  reserved 4
  field "DIV", bits: 8
end
puts register.to_ascii
```

The [Ruby API guide](docs/ruby-api.md) covers diagnostics, overrides, and inspecting the shared layout. [Preset sources](docs/presets.md) document the six bundled protocol definitions.

## Rendering notes

- ASCII uses display widths for Japanese text. Unicode border characters are East Asian Ambiguous: terminals configured to render them as two columns will misalign the borders. Use RFC style or set your terminal's ambiguous width to one.
- PNG/JPEG rendering uses installed fonts. Install a CJK font such as Noto Sans CJK JP for Japanese labels. `bitgram doctor` checks fontconfig when available.
- SVG text measurement estimates font width. Increase `svg.char_width_ratio` or use a monospace font if your chosen font extends beyond a cell.
- YAML aliases and object tags are rejected. Definitions are limited to 1 MiB, 10,000 fields, and 4,096 logical rows; raster output is limited to 50 million pixels. Definitions never cause network requests.

## Development

```sh
bundle install
bundle exec rake
bundle exec rake examples
bundle exec yard doc
```

Enable raster development dependencies with `bundle config set --local with raster`, then run `bundle install`. Raster integration tests skip converters unavailable on the machine; the dedicated CI job installs all three backends. See [release procedures](docs/releasing.md) for publishing setup.

## License

[MIT](LICENSE.txt).
