# Command-line reference

`bitgram <command> --help` displays command-specific help.

| Command | Purpose |
|---|---|
| `render INPUT` | Render a YAML or JSON definition |
| `validate INPUT...` | Report all validation issues in each input |
| `presets` | List bundled protocol names |
| `init [PRESET]` | Write a preset definition to stdout; defaults to UDP |
| `doctor` | Report Ruby, converters, CJK fonts, and automatic selections |
| `version` | Print the gem version |

Use `-` as an input to read stdin. Files use their `.yml`, `.yaml`, or `.json` extension; otherwise input beginning with `{` is JSON and other input is YAML. `--input-format yaml|json` overrides detection.

## Rendering options

| Option | Meaning |
|---|---|
| `-f, --format ascii|svg|png|jpeg` | Explicit output format |
| `-o, --output PATH` | Output path; omitted or `-` means stdout |
| `--preset NAME` | Use a bundled definition instead of INPUT |
| `--config PATH` | Shared settings file applied beneath the definition (also accepted by `validate`) |
| `--row-bits N` | Override `layout.row_bits` |
| `--bit-order msb0|lsb0` | Override bit numbering |
| `--ascii-style rfc|unicode` | Choose border characters |
| `--theme NAME_OR_PATH` | SVG theme, also used for raster output |
| `--scale N` | Raster scale, 0.5 through 8 |
| `--rasterizer auto|vips|rsvg|imagemagick` | Choose conversion backend |
| `--set KEY=VALUE` | Override a dotted configuration key; repeatable |
| `--strict` | Treat warnings as failure, before writing output |
| `--debug` | Include a backtrace on failure |

Without `--format`, the output extension selects the format: `.svg`, `.txt`, `.png`, `.jpg`, or `.jpeg`. With no output path, the default is ASCII. PNG and JPEG require a file path.

`--set` takes precedence over dedicated options, regardless of their argument order. Dedicated options override the definition, and the definition overrides the `--config` file (see [Shared settings file](format.md#shared-settings-file)). Values `true` and `false` become booleans, whole numbers become integers, decimal numbers become floats, and other values remain strings. Unknown configuration keys are validation errors.

```sh
bitgram render --preset tcp --set layout.offsets=hex -o tcp.svg
bitgram render header.yml --set svg.font_size=12.5 --set ascii.indent=3
cat header.json | bitgram render - --input-format json -f svg
bitgram validate definitions/*.yml --strict
bitgram render figure.yml --config book.yml -o figure.svg
```

Validation issues go to stderr and include a JSON path and a line number when available. `validate` continues through all supplied files.

| Exit status | Meaning |
|---|---|
| 0 | Success |
| 1 | Parse/validation failure or warnings under `--strict` |
| 2 | Invalid command, arguments, or options |
| 3 | Raster backend missing, unsupported, failed, or timed out |
| 4 | File input/output failure |
| 70 | Unexpected internal error |
