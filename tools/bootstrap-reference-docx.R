#!/usr/bin/env Rscript
# Run once, from the repository root, to create _extensions/owd/reference.docx
# from pandoc's default reference document, on A4 with 25 mm margins:
#
#   Rscript tools/bootstrap-reference-docx.R [--force]
#
# Afterwards only tools/make-reference-docx.R touches the file, and only its
# styles and theme fonts. A header or footer added in Word survives.
source("tools/docx-utils.R")

out <- "_extensions/owd/reference.docx"
force <- "--force" %in% commandArgs(trailingOnly = TRUE)
if (file.exists(out) && !force) {
  stop(out, " exists. Pass --force to start over from pandoc's default.", call. = FALSE)
}

quarto <- find_quarto()
default_docx <- tempfile(fileext = ".docx")
status <- system2(quarto, c("pandoc", "-o", shQuote(default_docx),
                            "--print-default-data-file", "reference.docx"))
if (status != 0 || !file.exists(default_docx)) stop("pandoc did not write the default reference.docx")

dir <- tempfile("bootstrap")
zip::unzip(default_docx, exdir = dir)

# A4 and 20 mm margins (twentieths of a point: 20 mm = 1134).
document <- xml2::read_xml(file.path(dir, "word", "document.xml"))
sect <- xml2::xml_find_first(document, "//w:sectPr")
set_attrs(ensure_child(sect, "w:pgSz", c("w:footnotePr", "w:endnotePr", "w:type", "w:pgSz", "w:pgMar")),
          "w:w" = "11906", "w:h" = "16838")
set_attrs(ensure_child(sect, "w:pgMar", c("w:footnotePr", "w:endnotePr", "w:type", "w:pgSz", "w:pgMar")),
          "w:top" = "1134", "w:right" = "1134", "w:bottom" = "1134", "w:left" = "1134",
          "w:header" = "709", "w:footer" = "709", "w:gutter" = "0")
xml2::write_xml(document, file.path(dir, "word", "document.xml"))

zip_docx(dir, out)
message("Wrote ", out, " (A4, 20 mm margins). Now run: Rscript tools/make-reference-docx.R")
