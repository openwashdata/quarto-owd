# quarto-owd 0.4.0

Follows openwashdata/brand 1.0.0.

- Brand mirror refreshed: Atkinson Hyperlegible Next for text, the
  darkened owd-orange, the new accents and roles, white logo variants and
  alt text.
- Code blocks in the PDF take their fill from the brand
  (`typography.monospace-block.background-color`, the light purple tint)
  through Quarto's own rule; the template no longer sets one. Links are
  underlined, as the brand says.
- Word: the reference document reads the code tint from the brand for
  both code blocks and inline code, names Atkinson Hyperlegible Next with
  Arial as its substitute, and drops font table entries of fonts the
  brand no longer uses.

# quarto-owd 0.3.0

Typst format only.

- With `toc: true` the table of contents sits on the cover page after the
  abstract, and the body still starts on page 1. With `cover: false` it
  stays at the top of the body.
- Tables: bold header cells, a soft grey line under every body row; the
  rule under the header row keeps the text colour (#15).

# quarto-owd 0.2.0

- Cover page: the front matter (title, subtitle, authors, date, abstract)
  sits on a page of its own and the body starts on the next page. In the
  PDF the cover has no footer and page numbers start at 1 with the first
  heading; in Word a page break follows the abstract. `cover: false`
  keeps the one page layout (#13).

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
