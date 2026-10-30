# Ruby API

```ruby
require "bitgram"

diagram = Bitgram.load_file("header.yml")
diagram = Bitgram.load('{"version":1,"fields":[{"name":"A","bits":32}]}', format: :json)
diagram = Bitgram.load({ version: 1, fields: [{ name: "A", bytes: 4 }] })
diagram = Bitgram.preset(:tcp)
```

`Bitgram.load` accepts a YAML/JSON string or a Ruby Hash. `load_file` reads UTF-8 files, and `preset` loads a bundled protocol. Nested override hashes passed to the loading APIs are merged into the definition and validated. The `config:` keyword (a path or a Hash holding only `layout`, `ascii`, `svg`, and `raster`) supplies shared settings beneath the definition, as `--config` does: `Bitgram.load_file("figure.yml", config: "book.yml")`.

```ruby
diagram = Bitgram.preset(:udp, layout: { offsets: "hex" })
puts diagram.to_ascii
puts diagram.to_ascii(style: :unicode, indent: 3)
svg = diagram.to_svg(theme: "dark", id_prefix: "example-1")
diagram.save("header.txt")
diagram.save("header.svg", theme: "mono")
diagram.save("header.png", scale: 2)
diagram.save("header.jpg", quality: 85, background: "#ffffff")
```

Renderer keywords override the corresponding `ascii`, `svg`, or `raster` section. `save` infers its format from the filename; `format: :svg` explicitly selects a format. PNG/JPEG always render SVG with inline styles first. JPEG rejects a transparent background.

## Validation and layout

```ruby
issues = Bitgram.validate_file("header.yml")
issues.each { |issue| warn "#{issue.severity} #{issue.code} #{issue.path}: #{issue.message}" }

begin
  diagram = Bitgram.load_file("header.yml")
rescue Bitgram::ValidationError => error
  error.issues.each { |issue| warn issue.message }
end

diagram.to_ascii
diagram.issues # Includes rendering warnings such as truncated labels.
diagram.layout.rows.each do |row|
  p [row.index, row.kind, row.span, row.offset_bits]
  row.cells.each { |cell| p [cell.field.id, cell.col, cell.bits, cell.part, cell.range] }
end
```

`Issue` exposes `severity`, `code`, `path`, `line`, and `message`. `validate_file` returns issues for invalid input without requiring exception handling. Loading invalid definitions raises `ValidationError`; malformed input raises `ParseError`. Rendering errors use `RenderError`; raster errors use `RasterizeError`, `RasterizerNotFound`, or `RasterizerTimeout`. Filesystem failures retain their standard Ruby exceptions.

The layout uses bits, independently of text columns and pixels. `row.kind` is `:normal`, `:block`, or `:variable`; a block's `span` gives its logical row count. A cell's `range` is relative to its field, and `part` is `:whole`, `:head`, `:middle`, or `:tail`. Offsets after variable-length data are `nil`. Models and layout results are immutable.

## DSL

```ruby
diagram = Bitgram.define(title: "CTRL Register") do
  row_bits 16
  bit_order :lsb0
  field "EN", bits: 1, description: "Enable"
  field "MODE", bits: 3
  reserved 4
  field "DIV", bits: 8
  variable "Data"
end
```

The DSL builds a Hash and runs it through the same validator as YAML and JSON. `field` accepts the field options in the [format reference](format.md). `reserved(bits, name: "Reserved")` sets `reserved: true`; `variable(name, **options)` sets `bits: "variable"`.

Public compatibility covers methods on `Bitgram`, `Diagram`, `Issue`, layout result/row/cell objects, and the `Bitgram::Error` hierarchy. Internal loaders, validators, fitters, renderers, and converters are private APIs.
