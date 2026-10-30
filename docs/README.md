# docs

This fork (kishima/bitgram) adds what the book "Deep dive into mruby" needs for its figures. The reference documents describe the fork, including its additions (shared settings file, PDF output, `field_order`, strategies for narrow fields, `ligatures`, `field_font_weight`, `annotations`, `row_labels`); the plans and worklog record how they were made.

## Reference

| File | Contents |
|---|---|
| [format.md](format.md) | Definition format, version 1: fields, layout, annotations, ascii, svg, raster, pdf, shared settings file |
| [cli.md](cli.md) | Command-line reference |
| [ruby-api.md](ruby-api.md) | Ruby API |
| [presets.md](presets.md) | Bundled protocol definitions |
| [development.md](development.md) | Development setup and tests |
| [releasing.md](releasing.md) | Release procedure |

## Plans (`plans/`)

| File | Contents |
|---|---|
| [plans/2026-10-30-book-plan.md](plans/2026-10-30-book-plan.md) | 本の図に使うための改修計画（B1〜B6） |

## Worklog (`worklog/`)

| File | Contents |
|---|---|
| [worklog/2026-10-30-book-b7a.md](worklog/2026-10-30-book-b7a.md) | B7a 欄ごとにビット番号と目盛りを消す（欄の `bit_numbers: false`） |
| [worklog/2026-10-30-book-b6a.md](worklog/2026-10-30-book-b6a.md) | B6a 欄の名前の太字（`field_font_weight`）、目盛り（`ticks`）と題（`show_title`）の確認 |
| [worklog/2026-10-30-book-b4-b5.md](worklog/2026-10-30-book-b4-b5.md) | B4 細い欄の名前（引き出し線、縦書き、1 行の脚注）と合字、B5 欄の下の注記行と行の見出し |
| [worklog/2026-10-30-book-b1-b3.md](worklog/2026-10-30-book-b1-b3.md) | B1 フォント名の引用と共通設定、B2 PDF 出力、B3 欄を LSB から書く |
