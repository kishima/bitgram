# Development and verification

Use Ruby 3.3 or newer. Install the development bundle, then run:

```sh
bundle install
bundle exec rake
bundle exec rake benchmark
bundle exec yard doc
bundle exec yard stats --list-undoc
```

The default task runs RSpec and RuboCop. Tests enforce 90% line coverage, compare deterministic golden files, check the JSON Schema against the validator, and exercise 1,000 seeded random layouts. Golden files can be regenerated with `UPDATE_GOLDEN=1 bundle exec rspec`; inspect the resulting text and images before accepting them.

For all native backends, install libvips, librsvg, ImageMagick and CJK fonts as described in the README, then run:

```sh
BUNDLE_WITH=raster bundle install
BUNDLE_WITH=raster REQUIRE_RASTER=1 bundle exec rake
BUNDLE_WITH=raster bundle exec rake examples
```

`REQUIRE_RASTER=1` makes unavailable converters fail the raster tests. Ordinary core development may skip unavailable converters. `RASTER=0 bundle exec rake examples` regenerates text and SVG without PNG.

## Decisions resolving draft inconsistencies

- Aligned fixed fields of at least two complete rows merge into a block when `merge_rows` is enabled, including a 16-bit field in an 8-bit layout. This follows the design algorithm rather than the conflicting P3 case 8 example.
- Unicode full-width variable rows use the compact one-line presentation in design §9.4; RFC rows use the three-line presentation in §9.5.
- Block widths count as `cell.bits * row.span` when checking field-width conservation.
- Repeating an identical SVG on a page requires explicit distinct `id_prefix` values. Deterministic output cannot automatically distinguish identical copies.
- To bound output sizes, the schema also caps indentation (256), label lines (256), bit width (1024 px), row height/margin (4096 px), font size (256 px), ratio (10), timeout (3600 seconds), and description/note lengths (65,536 characters). The schema documents every accepted range.
- The gem version stays unreleased until the maintainer performs the release steps. Implementing the historical milestones does not publish intermediate versions.

The CI configuration covers Ruby 3.3, 3.4 and 4.0 on Linux and macOS, plus all native rasterizers. Actual hosted CI runs, browser-specific rendering checks and RubyGems publication require the repository and publisher setup in [releasing.md](releasing.md).
