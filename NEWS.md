# quarto-owd 0.1.0

First release.

- `owd-typst`: PDF through Typst. Reads the brand at render time: brand
  fonts, headings and the title rule in the primary colour, links in the
  link colour, code blocks tinted from the primary colour, the medium logo
  once in the title block, white pages, A4 with 25 mm margins, a footer
  with `footer-text` and page numbers.
- `owd-docx`: Word through a `reference.docx` whose styles are generated
  from the brand by `tools/make-reference-docx.R`. A4 with 20 mm margins,
  1.15 line height, data tables with all borders and a tinted header row
  (style `OwdTable`, assigned by a filter), brand fonts with Arial and
  Courier New as substitutes when they are not installed.
- `_brand/` mirrors openwashdata/brand; `template.qmd` is the starter
  document.
- Works on Quarto 1.8 with an explicit `brand:` key and on Quarto 1.9
  without one.
