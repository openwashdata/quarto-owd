# quarto-owd 0.1.0

First release.

- `owd-typst`: PDF through Typst. Reads the brand at render time: brand
  fonts, headings and the title rule in the primary colour, links in the
  link colour, code blocks tinted from the primary colour, the medium logo
  once in the title block, white pages, A4 with 25 mm margins, a footer
  with `footer-text` and page numbers.
- `owd-docx`: Word through a `reference.docx` whose styles are generated
  from the brand by `tools/make-reference-docx.R`.
- `_brand/` mirrors openwashdata/brand; `template.qmd` is the starter
  document and the CI smoke test.
- Works on Quarto 1.8 with an explicit `brand:` key and on Quarto 1.9
  without one.
