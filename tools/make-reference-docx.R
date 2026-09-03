#!/usr/bin/env Rscript
# Regenerate the styles of _extensions/owd/reference.docx from _brand/_brand.yml.
# Run from the repository root:
#
#   Rscript tools/make-reference-docx.R
#
# word/styles.xml, word/theme/theme1.xml, word/fontTable.xml and the page
# margins in word/document.xml change. Every edit sets an attribute or
# replaces a child in place, so running twice gives the same file, and a
# header or footer added in Word is left alone.
source("tools/docx-utils.R")

brand_path <- "_brand/_brand.yml"
docx <- "_extensions/owd/reference.docx"
if (!file.exists(docx)) stop(docx, " missing. Run tools/bootstrap-reference-docx.R first.", call. = FALSE)
if (!file.exists(brand_path)) stop(brand_path, " missing. Run: quarto use brand openwashdata/brand", call. = FALSE)

`%||%` <- function(a, b) if (is.null(a)) b else a

# Brand values ----------------------------------------------------------------
brand <- brand.yml::read_brand_yml(brand_path)
# Roles resolve through the package; palette names carry underscores there
# (owd-purple becomes owd_purple), so try the palette first.
color <- function(name) {
  if (grepl("^#", name)) return(hex_clean(name))
  pal <- brand$color$palette[[gsub("-", "_", name)]]
  if (!is.null(pal)) return(hex_clean(pal))
  hex_clean(brand.yml::brand_color_pluck(brand, name))
}
typography <- brand$typography
base_font <- typography$base$family %||% stop("brand has no typography.base.family")
heading_font <- typography$headings$family %||% base_font
mono_font <- typography$monospace$family %||% "Courier New"
heading_weight <- as.numeric(typography$headings$weight %||% 700)
# The brand's base line height (1.5) is a screen value; Word documents use
# Word's own default so more text fits a page.
line_height <- 1.15
margin_twips <- 1134  # 20 mm

primary <- color("primary")
ink <- color("foreground")
link_color <- if (is.null(typography$link$color)) color("info") else color(typography$link$color)
table_head_fill <- mix_with_white(primary, share = 0.85)
# Code backgrounds follow the brand's monospace roles when set, else a light
# grey. The package spells the roles monospace_block and background_color.
role_background <- function(role) {
  node <- typography[[role]] %||% typography[[gsub("_", "-", role)]]
  value <- node[["background_color"]] %||% node[["background-color"]]
  if (is.null(value)) NULL else color(value)
}
code_block_fill <- role_background("monospace_block") %||% "F2F2F2"
code_inline_fill <- role_background("monospace_inline")

message("Brand: ", base_font, " / ", heading_font, " ", heading_weight, " / ", mono_font,
        "; primary #", primary, ", ink #", ink, ", link #", link_color, ", code #", code_block_fill)

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

# Body: line height on Normal; single spacing where it would look wrong ------
set_line(ppr_of(style("Normal")), round(240 * line_height))
set_line(ppr_of(style("Compact")), 240)
# 6 pt after a paragraph, nothing before; the paragraph after a heading
# (FirstParagraph) inherits this, so the gap below a heading is the
# heading's own "after" value only.
set_attrs(ensure_child(ppr_of(style("BodyText")), "w:spacing", ORDER_PPR),
          "w:before" = "0", "w:after" = "120")
set_attrs(ensure_child(ppr_of(style("AbstractTitle")), "w:spacing", ORDER_PPR), "w:before" = "200")
set_attrs(ensure_child(ppr_of(style("Abstract")), "w:spacing", ORDER_PPR), "w:after" = "200")

# Headings and title block ---------------------------------------------------
bold_headings <- heading_weight >= 600
for (id in c(paste0("Heading", 1:9), paste0("Heading", 1:9, "Char"), "Title", "TitleChar", "TOCHeading")) {
  set_run_props(rpr_of(style(id)), font = heading_font, color = primary, bold = bold_headings)
}
# Headings sit on a single line height (the body value would inflate the
# line box) with space above and a little below, by level.
heading_space <- list(c(360, 120), c(240, 80), c(200, 60))
for (level in 1:9) {
  space <- heading_space[[min(level, length(heading_space))]]
  if (level > 3) space <- c(160, 40)
  set_attrs(ensure_child(ppr_of(style(paste0("Heading", level))), "w:spacing", ORDER_PPR),
            "w:before" = as.character(space[1]), "w:after" = as.character(space[2]),
            "w:line" = "240", "w:lineRule" = "auto")
}
for (id in c("Subtitle", "SubtitleChar")) {
  set_run_props(rpr_of(style(id)), font = heading_font, color = ink, bold = FALSE)
}

# Links and code -------------------------------------------------------------
set_run_props(rpr_of(style("Hyperlink")), color = link_color)
verbatim_rpr <- rpr_of(style("VerbatimChar"))
set_run_props(verbatim_rpr, font = mono_font)
if (!is.null(code_inline_fill)) {
  set_attrs(ensure_child(verbatim_rpr, "w:shd", ORDER_RPR), "w:val" = "clear", "w:color" = "auto", "w:fill" = code_inline_fill)
}

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
set_attrs(ensure_child(code_ppr, "w:shd", ORDER_PPR), "w:val" = "clear", "w:color" = "auto", "w:fill" = code_block_fill)
set_attrs(ensure_child(code_ppr, "w:spacing", ORDER_PPR),
          "w:before" = "120", "w:after" = "120", "w:line" = "240", "w:lineRule" = "auto")
set_run_props(rpr_of(source_code), font = mono_font, size_halfpt = 20)

# Captions -------------------------------------------------------------------
for (id in c("Caption", "ImageCaption", "TableCaption")) {
  set_run_props(rpr_of(style(id)), italic = TRUE, size_halfpt = 20)
}

# Tables ---------------------------------------------------------------------
# Data tables use OwdTable, assigned by docx-tables.lua: all borders in ink
# and a bold first row on a light primary tint. The plain Table style stays
# border free because Quarto's caption and figure wrappers use it too.
table_style <- style("Table")
xml2::xml_remove(xml2::xml_find_all(table_style, "./w:tblStylePr[@w:type='firstRow']"))
w_ns <- xml2::xml_ns(styles)[["w"]]
xml2::xml_remove(xml2::xml_find_all(styles, "//w:style[@w:styleId='OwdTable']"))
border <- function(side) sprintf('<w:%s w:val="single" w:sz="4" w:space="0" w:color="%s"/>', side, ink)
owd_table <- xml2::read_xml(sprintf(
  '<w:style xmlns:w="%s" w:type="table" w:customStyle="1" w:styleId="OwdTable">
     <w:name w:val="OwdTable"/>
     <w:basedOn w:val="Table"/>
     <w:tblPr>
       <w:tblBorders>%s</w:tblBorders>
       <w:tblCellMar>
         <w:top w:w="40" w:type="dxa"/>
         <w:left w:w="108" w:type="dxa"/>
         <w:bottom w:w="40" w:type="dxa"/>
         <w:right w:w="108" w:type="dxa"/>
       </w:tblCellMar>
     </w:tblPr>
     <w:tblStylePr w:type="firstRow">
       <w:rPr><w:b/><w:bCs/></w:rPr>
       <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="%s"/></w:tcPr>
     </w:tblStylePr>
   </w:style>', w_ns,
  paste(vapply(c("top", "left", "bottom", "right", "insideH", "insideV"), border, ""), collapse = ""),
  table_head_fill))
xml2::xml_add_child(styles, owd_table)

xml2::write_xml(styles, styles_path)

# Font table: what Word substitutes when a brand font is not installed -------
# Without an entry, an unknown font name falls back to Times New Roman. The
# alternate name is what Word uses first; family, pitch and the OS/2 ranges
# (read from the font files) refine the match when the alternate is missing.
KNOWN_FONTS <- list(
  "Atkinson Hyperlegible Next" = list(
    family = "swiss", pitch = "variable", alt = "Arial",
    usb = c("80000067", "0000000A", "00000000", "00000000"), csb = c("20000013", "00000000")
  ),
  "Atkinson Hyperlegible" = list(
    family = "swiss", pitch = "variable", alt = "Arial",
    usb = c("800000EF", "0000204B", "00000000", "00000000"), csb = c("20000003", "00000000")
  ),
  "Source Code Pro" = list(
    family = "modern", pitch = "fixed", alt = "Courier New", panose = "020B0309030403020204",
    usb = c("200002F7", "02003803", "00000000", "00000000"), csb = c("6000019F", "00000000")
  )
)
font_table_path <- file.path(dir, "word", "fontTable.xml")
font_table <- xml2::read_xml(font_table_path)
ft_ns <- xml2::xml_ns(font_table)[["w"]]
upsert_font <- function(name, family, pitch, alt, panose = NULL, usb = NULL, csb = NULL) {
  xml2::xml_remove(xml2::xml_find_all(font_table, sprintf("//w:font[@w:name='%s']", name)))
  panose_xml <- if (is.null(panose)) "" else sprintf('<w:panose1 w:val="%s"/>', panose)
  sig_xml <- if (is.null(usb)) "" else sprintf(
    '<w:sig w:usb0="%s" w:usb1="%s" w:usb2="%s" w:usb3="%s" w:csb0="%s" w:csb1="%s"/>',
    usb[1], usb[2], usb[3], usb[4], csb[1], csb[2])
  node <- xml2::read_xml(sprintf(
    '<w:font xmlns:w="%s" w:name="%s"><w:altName w:val="%s"/>%s<w:charset w:val="00"/><w:family w:val="%s"/><w:pitch w:val="%s"/>%s</w:font>',
    ft_ns, name, alt, panose_xml, family, pitch, sig_xml))
  xml2::xml_add_child(font_table, node)
}
# Drop entries of brand fonts no longer in use before writing the current ones.
for (name in setdiff(names(KNOWN_FONTS), c(base_font, heading_font, mono_font))) {
  xml2::xml_remove(xml2::xml_find_all(font_table, sprintf("//w:font[@w:name='%s']", name)))
}
font_entry <- function(name, mono = FALSE) {
  known <- KNOWN_FONTS[[name]]
  if (is.null(known)) {
    known <- if (mono) list(family = "modern", pitch = "fixed", alt = "Courier New")
             else list(family = "swiss", pitch = "variable", alt = "Arial")
  }
  do.call(upsert_font, c(list(name = name), known))
}
for (font in unique(c(base_font, heading_font))) font_entry(font)
font_entry(mono_font, mono = TRUE)
xml2::write_xml(font_table, font_table_path)

# Theme fonts, for styles a maintainer adds in Word later --------------------
theme <- xml2::read_xml(theme_path)
xml2::xml_set_attr(xml2::xml_find_first(theme, "//a:majorFont/a:latin"), "typeface", heading_font)
xml2::xml_set_attr(xml2::xml_find_first(theme, "//a:minorFont/a:latin"), "typeface", base_font)
xml2::write_xml(theme, theme_path)

# Page margins ---------------------------------------------------------------
document_path <- file.path(dir, "word", "document.xml")
document <- xml2::read_xml(document_path)
for (margin in xml2::xml_find_all(document, "//w:sectPr/w:pgMar")) {
  set_attrs(margin, "w:top" = as.character(margin_twips), "w:right" = as.character(margin_twips),
            "w:bottom" = as.character(margin_twips), "w:left" = as.character(margin_twips))
}
xml2::write_xml(document, document_path)

zip_docx(dir, docx)
message("Wrote ", docx)
