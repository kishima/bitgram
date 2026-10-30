# Definition format, version 1

Definitions may be YAML, JSON, or Ruby Hashes. The editor schema is [bitgram.schema.json](../schema/bitgram.schema.json). Unknown keys are errors, with spelling suggestions when available. All names and descriptions are plain text, never HTML or executable code.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/ydah/bitgram/main/schema/bitgram.schema.json
version: 1
title: CTRL Register
layout:
  row_bits: 16
  bit_order: lsb0
fields:
  - { name: EN, bits: 1, description: Enable }
  - { name: MODE, bits: 3 }
  - { name: Reserved, bits: 4, reserved: true }
  - { name: DIV, bits: 8 }
notes:
  - Reset values depend on the device.
```

## Top level

| Key | Type | Default |
|---|---|---|
| `version` | Integer; required, must be `1` | — |
| `fields` | Nonempty array; required, at most 10,000 fields | — |
| `title` | String, at most 256 characters | None |
| `description` | String, used in SVG accessibility text | None |
| `layout`, `ascii`, `svg`, `raster` | Configuration objects below | Built-in settings |
| `notes` | Array of strings shown below the drawing | `[]` |

## Fields

| Key | Type and meaning | Default |
|---|---|---|
| `name` | Required string, 1–256 characters | — |
| `bits` | Positive integer up to 524,288, or `variable` | — |
| `bytes` | Positive integer up to 65,536, multiplied by eight | — |
| `id` | Unique string matching `[a-z0-9][a-z0-9_-]*` | Slug from name, with numeric suffix if needed |
| `short` | Short label, at most 64 characters | None |
| `description` | Tooltip and footnote text | None |
| `value` | String or integer, shown as a fixed value | None |
| `reserved` | Boolean; SVG hatch fill | `false` |
| `optional` | Boolean; SVG dashed border | `false` |
| `display_bits` | Positive integer up to 128, illustrative variable-field width | `layout.row_bits` |
| `class` | String or array of strings; SVG classes | None |
| `fill` | Color override | Theme |

Specify exactly one of `bits` and `bytes`. Fixed fields wrap across row boundaries. A field beginning at a row boundary and spanning an exact multiple of at least two rows becomes one tall block when `merge_rows` is enabled.

A variable field without `display_bits` must begin at a row boundary and occupies a variable-length row. Set `display_bits` to place variable fields beside each other:

```yaml
fields:
  - { name: Options, bits: variable, display_bits: 24 }
  - { name: Padding, bits: variable, display_bits: 8 }
```

Offsets become unknown after a variable-length field. A variable field extending beyond the remaining display width produces a warning.

## Layout

| Key | Values | Default |
|---|---|---|
| `row_bits` | Integer, 1–128 | `32` |
| `bit_order` | `msb0`, `lsb0` | `msb0` |
| `bit_numbers` | Boolean | `true` |
| `offsets` | `none`, `dec`, `hex` | `none` |
| `merge_rows` | Boolean | `true` |
| `split_label` | `range`, `first`, `repeat` | `range` |
| `split_suffix` | Range template with `{from}` and `{to}` | `" [{from}:{to}]"` |
| `allow_partial_row` | Boolean; suppress the incomplete-final-row warning | `false` |

Bit numbering is local to each row and does not reorder fields. `lsb0` places bit zero on the right. Split ranges remain relative to the field, regardless of numbering direction. `first` labels subsequent pieces `(cont.)`; `repeat` repeats the field name. Offset labels count bytes, or bits with a `b` suffix when a row starts between byte boundaries.

## ASCII

| Key | Values | Default |
|---|---|---|
| `style` | `rfc`, `unicode` | `rfc` |
| `indent` | Nonnegative integer | `0` |
| `variable_edge` | `dot`, `colon`, `slash` | `dot` |
| `max_label_lines` | Positive integer | `4` |
| `ambiguous_width` | `1`, `2` | `1` |
| `fit_order` | Array of fitting strategies | See below |
| `footnote_marker` | Template with `{n}` | `"*{n}"` |
| `title` | `none`, `top`, `bottom` | `none` |

Each bit occupies two columns. Labels use Unicode display width, including CJK text. Output uses LF, has no trailing spaces, and ends in one newline. Indentation applies to headers, borders, labels, notes, and footnotes. Unicode borders assume a terminal that displays ambiguous border glyphs in one column.

## SVG

| Key | Values | Default |
|---|---|---|
| `theme` | `default`, `mono`, `dark`, `auto`, or a local YAML theme path | `default` |
| `bit_width` | Positive number, pixels per bit | `20` |
| `row_height` | Positive number, base row height | `36` |
| `margin` | Nonnegative number, outer pixels | `16` |
| `font_family` | Font stack string; names that CSS cannot take unquoted (such as `M PLUS 1p`) are quoted on output | `Helvetica, Arial, 'Noto Sans CJK JP', sans-serif` |
| `font_size` | Positive number, pixels | `13` |
| `min_font_size` | Positive number, shrink limit | `9` |
| `char_width_ratio` | Positive number, half-width character size relative to font size | `0.6` |
| `bit_number_style` | `full`, `rfc` | `full` |
| `ticks` | Boolean | `true` |
| `show_title` | Boolean | `true` |
| `inline_styles` | Boolean | `false` |
| `id_prefix` | Prefix for all SVG IDs | Title slug or definition digest |
| `fit_order` | Array of fitting strategies | See below |

SVG includes accessible title and description elements, field IDs, and tooltips. For repeated identical diagrams embedded in one HTML page, provide a distinct `id_prefix` for each copy. Output IDs and numeric formatting are deterministic. Raster conversion always uses inline attributes; the `auto` theme uses the default light palette during conversion.

Themes define `background`, `stroke`, `text`, `header_text`, `cell_fill`, `reserved_fill`, `hatch`, `palette` (an array of colors), and `classes` (class-name objects containing a `fill`). A field's explicit fill wins over theme colors. `auto` switches default/dark palettes using `prefers-color-scheme` CSS.

Colors accept hex, color names, `rgb()`, and `rgba()`. Font names must not contain CSS/XML delimiters (`;`, braces, angle brackets, or backslashes). External resources and CSS URLs are not allowed.

`font_family` is a comma-separated list. A family name is written to CSS as given when it is already quoted, is a generic family (`sans-serif`, `monospace`, ...), or consists only of CSS identifiers (`Noto Sans`). Any other name is wrapped in single quotes, so `font_family: M PLUS 1p` works without writing `"'M PLUS 1p'"`; a word beginning with a digit (`1p`) is not an identifier and would otherwise make the whole declaration invalid.

## Label fitting

ASCII tries `single`, `wrap`, `short`, `vertical`, `footnote`, then `truncate`. SVG tries `shrink` after `single`. A custom `fit_order` changes this order. Wrapping respects words and permits breaks between CJK characters; narrow fields can stack characters vertically. Shrinking uses 0.5-pixel steps. Footnotes are numbered in row order, using `description` or the full field name. Truncation produces warning `V-09`.

## Raster

| Key | Values | Default |
|---|---|---|
| `scale` | Number, 0.5–8 | `2` |
| `background` | Color, or `transparent` for PNG only | PNG: transparent; JPEG: white |
| `quality` | Integer, 1–100 | `90` |
| `rasterizer` | `auto`, `vips`, `rsvg`, `imagemagick` | `auto` |
| `timeout` | Positive number, seconds | `30` |

Automatic selection chooses the first available backend supporting the requested format: vips, rsvg (PNG only), then ImageMagick. Output is limited to 50 million pixels; lower `scale` for large diagrams. Native converters and CJK fonts must be installed separately.

## Shared settings file

Settings common to many diagrams (fonts, sizes, theme) can live in one file that holds only the `layout`, `ascii`, `svg`, and `raster` sections, passed with `--config PATH` or the `config:` keyword of the Ruby API:

```yaml
# book.yml
svg:
  font_family: M PLUS 1p
  theme: mono
```

Settings are combined in this order, later ones winning: built-in defaults, the shared settings file, the definition, dedicated command-line options, then `--set`. The file is validated with the same schema as a definition's sections, and errors carry the file's own line numbers. Any other top-level key, such as `fields`, is an error. A theme path inside the file is resolved like any other theme path, from the current directory.

## Diagnostics and limits

| Code | Meaning |
|---|---|
| `V-01` | Unsupported format version |
| `V-02` | Unknown key |
| `V-03` | Invalid type, range, or enumeration |
| `V-04` | Missing or conflicting `bits`/`bytes` |
| `V-05` | Duplicate explicit ID |
| `V-06` | Full-width variable field starts mid-row |
| `V-07` | Resource limit exceeded |
| `V-08` | Incomplete final row (warning) |
| `V-09` | Label truncated (warning) |
| `V-10` | Variable display width crosses a row (warning) |

Validation collects all errors, with JSON paths and YAML line numbers where available. Input strings and files are limited to 1 MiB; definitions to 10,000 fields and 4,096 logical rows. JSON nesting is limited to 20. YAML aliases and Ruby object tags are rejected. The schema URL is solely an editor hint; bitgram makes no network requests.
