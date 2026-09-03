#!/usr/bin/env Rscript
# Regenerate the styles of _extensions/owd/reference.docx from _brand/_brand.yml.
# Run from the repository root:
#
#   Rscript tools/make-reference-docx.R
#
# Only word/styles.xml and word/theme/theme1.xml change. Every edit sets an
# attribute or replaces a child in place, so running twice gives the same
# file, and a header or footer added in Word is left alone.
source("tools/docx-utils.R")

brand_path <- "_brand/_brand.yml"
docx <- "_extensions/owd/reference.docx"
if (!file.exists(docx)) stop(docx, " missing. Run tools/bootstrap-reference-docx.R first.", call. = FALSE)
if (!file.exists(brand_path)) stop(brand_path, " missing. Run: quarto use brand openwashdata/brand", call. = FALSE)

`%||%` <- function(a, b) if (is.null(a)) b else a

# Brand values ----------------------------------------------------------------
brand <- brand.yml::read_brand_yml(brand_path)
color <- function(name) hex_clean(brand.yml::brand_color_pluck(brand, name))
typography <- brand$typography
base_font <- typography$base$family %||% stop("brand has no typography.base.family")
heading_font <- typography$headings$family %||% base_font
mono_font <- typography$monospace$family %||% "Courier New"
heading_weight <- as.numeric(typography$headings$weight %||% 700)
line_height <- as.numeric(typography$base[["line-height"]] %||% typography$base$line_height %||% 1.5)

primary <- color("primary")
ink <- color("foreground")
link_color <- if (is.null(typography$link$color)) color("info") else hex_clean(typography$link$color)
table_head_fill <- mix_with_white(primary, share = 0.85)
code_fill <- "F2F2F2"

message("Brand: ", base_font, " / ", heading_font, " ", heading_weight, " / ", mono_font,
        "; primary #", primary, ", ink #", ink, ", link #", link_color)

# Unpack ----------------------------------------------------------------------
dir <- tempfile("refdocx")
zip::unzip(docx, exdir = dir)
styles_path <- file.path(dir, "word", "styles.xml")
theme_path <- file.path(dir, "word", "theme", "theme1.xml")
styles <- xml2::read_xml(styles_path)

style <- function(id) {
  node <- xml2::xml_find_first(styles, sprintf("//w:style[@w:styleId='%s']", id))
  if (inherits(node, "xml_missing")) stop("style ", id, " not found in reference.docx")
  node
}
rpr_of <- function(node) ensure_child(node, "w:rPr", ORDER_STYLE)
ppr_of <- function(node) ensure_child(node, "w:pPr", ORDER_STYLE)
set_line <- function(ppr, twentieths) {
  set_attrs(ensure_child(ppr, "w:spacing", ORDER_PPR),
            "w:line" = as.character(twentieths), "w:lineRule" = "auto")
}

# Document defaults: explicit brand fonts, ink text ---------------------------
defaults <- xml2::xml_find_first(styles, "//w:docDefaults/w:rPrDefault/w:rPr")
set_run_props(defaults, font = base_font, color = ink)

# No style may point at theme fonts: a theme reference beats an explicit font,
# and a later edit in Word would silently reintroduce Aptos.
for (rf in xml2::xml_find_all(styles, "//w:rFonts")) {
  drop_attrs(rf, c("w:asciiTheme", "w:hAnsiTheme", "w:cstheme", "w:eastAsiaTheme"))
}

# Body: line height on Normal; single spacing where 1.5 would look wrong -----
set_line(ppr_of(style("Normal")), round(240 * line_height))
set_line(ppr_of(style("Compact")), 240)

# Headings and title block ---------------------------------------------------
bold_headings <- heading_weight >= 600
for (id in c(paste0("Heading", 1:9), paste0("Heading", 1:9, "Char"), "Title", "TitleChar", "TOCHeading")) {
  set_run_props(rpr_of(style(id)), font = heading_font, color = primary, bold = bold_headings)
}
for (id in c("Subtitle", "SubtitleChar")) {
  set_run_props(rpr_of(style(id)), font = heading_font, color = ink, bold = FALSE)
}

# Links and code -------------------------------------------------------------
set_run_props(rpr_of(style("Hyperlink")), color = link_color)
set_run_props(rpr_of(style("VerbatimChar")), font = mono_font)

source_code <- xml2::xml_find_first(styles, "//w:style[@w:styleId='SourceCode']")
if (inherits(source_code, "xml_missing")) {
  w_ns <- xml2::xml_ns(styles)[["w"]]
  fragment <- xml2::read_xml(sprintf(
    '<w:style xmlns:w="%s" w:type="paragraph" w:customStyle="1" w:styleId="SourceCode">
       <w:name w:val="Source Code"/>
       <w:basedOn w:val="Normal"/>
       <w:pPr/>
       <w:rPr/>
     </w:style>', w_ns))
  xml2::xml_add_child(styles, fragment)
  source_code <- xml2::xml_find_first(styles, "//w:style[@w:styleId='SourceCode']")
}
code_ppr <- ppr_of(source_code)
set_attrs(ensure_child(code_ppr, "w:wordWrap", ORDER_PPR), "w:val" = "0")
set_attrs(ensure_child(code_ppr, "w:shd", ORDER_PPR), "w:val" = "clear", "w:color" = "auto", "w:fill" = code_fill)
set_attrs(ensure_child(code_ppr, "w:spacing", ORDER_PPR),
          "w:before" = "120", "w:after" = "120", "w:line" = "240", "w:lineRule" = "auto")
set_run_props(rpr_of(source_code), font = mono_font, size_halfpt = 20)

# Captions -------------------------------------------------------------------
for (id in c("Caption", "ImageCaption", "TableCaption")) {
  set_run_props(rpr_of(style(id)), italic = TRUE, size_halfpt = 20)
}

# Tables: bold first row on a light primary tint -----------------------------
table_style <- style("Table")
old <- xml2::xml_find_all(table_style, "./w:tblStylePr[@w:type='firstRow']")
xml2::xml_remove(old)
w_ns <- xml2::xml_ns(styles)[["w"]]
first_row <- xml2::read_xml(sprintf(
  '<w:tblStylePr xmlns:w="%s" w:type="firstRow">
     <w:rPr><w:b/><w:bCs/></w:rPr>
     <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="%s"/></w:tcPr>
   </w:tblStylePr>', w_ns, table_head_fill))
xml2::xml_add_child(table_style, first_row)

xml2::write_xml(styles, styles_path)

# Theme fonts, for styles a maintainer adds in Word later --------------------
theme <- xml2::read_xml(theme_path)
xml2::xml_set_attr(xml2::xml_find_first(theme, "//a:majorFont/a:latin"), "typeface", heading_font)
xml2::xml_set_attr(xml2::xml_find_first(theme, "//a:minorFont/a:latin"), "typeface", base_font)
xml2::write_xml(theme, theme_path)

zip_docx(dir, docx)
message("Wrote ", docx)
