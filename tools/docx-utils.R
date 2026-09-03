# Shared helpers for the reference.docx scripts. Sourced from the repository
# root by tools/bootstrap-reference-docx.R and tools/make-reference-docx.R.

# Quarto binary: PATH, QUARTO_PATH, or the RStudio and Positron bundles.
find_quarto <- function() {
  candidates <- c(
    Sys.getenv("QUARTO_PATH"),
    unname(Sys.which("quarto")),
    "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto",
    "/Applications/Positron.app/Contents/Resources/app/quarto/bin/quarto"
  )
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(candidates) == 0) {
    stop("Quarto not found. Put it on PATH or set QUARTO_PATH.", call. = FALSE)
  }
  candidates[[1]]
}

# Re-zip an unpacked docx deterministically: fixed timestamps, sorted entries,
# [Content_Types].xml first. Two runs over identical content give identical bytes.
zip_docx <- function(dir, out) {
  # Zip entries carry local DOS timestamps; a fixed zone keeps the bytes the
  # same on a laptop in Zurich and a CI runner in UTC.
  old_tz <- Sys.getenv("TZ", unset = NA)
  Sys.setenv(TZ = "UTC")
  on.exit(if (is.na(old_tz)) Sys.unsetenv("TZ") else Sys.setenv(TZ = old_tz), add = TRUE)
  files <- list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = FALSE)
  files <- files[order(files != "[Content_Types].xml", files, method = "radix")]
  Sys.setFileTime(file.path(dir, files), as.POSIXct("1980-01-01 00:00:00", tz = "UTC"))
  # zip() changes into `root`, so the target must be absolute; normalizePath()
  # leaves a path that does not exist yet untouched, hence the two steps.
  out <- file.path(normalizePath(dirname(out), mustWork = TRUE), basename(out))
  if (file.exists(out)) unlink(out)
  zip::zip(out, files, root = dir, mode = "mirror",
           include_directories = FALSE, compression_level = 6)
  invisible(out)
}

# Element order inside the WordprocessingML containers we edit. Word rejects
# files whose children are out of schema order, so new children are inserted
# at their place rather than appended.
ORDER_RPR <- c("w:rStyle", "w:rFonts", "w:b", "w:bCs", "w:i", "w:iCs", "w:caps",
  "w:smallCaps", "w:strike", "w:dstrike", "w:outline", "w:shadow", "w:emboss",
  "w:imprint", "w:noProof", "w:snapToGrid", "w:vanish", "w:webHidden", "w:color",
  "w:spacing", "w:w", "w:kern", "w:position", "w:sz", "w:szCs", "w:highlight",
  "w:u", "w:effect", "w:bdr", "w:shd", "w:fitText", "w:vertAlign", "w:rtl",
  "w:cs", "w:em", "w:lang", "w:eastAsianLayout", "w:specVanish", "w:oMath")
ORDER_PPR <- c("w:pStyle", "w:keepNext", "w:keepLines", "w:pageBreakBefore",
  "w:framePr", "w:widowControl", "w:numPr", "w:suppressLineNumbers", "w:pBdr",
  "w:shd", "w:tabs", "w:suppressAutoHyphens", "w:kinsoku", "w:wordWrap",
  "w:overflowPunct", "w:topLinePunct", "w:autoSpaceDE", "w:autoSpaceDN", "w:bidi",
  "w:adjustRightInd", "w:snapToGrid", "w:spacing", "w:ind", "w:contextualSpacing",
  "w:mirrorIndents", "w:suppressOverlap", "w:jc", "w:textDirection",
  "w:textAlignment", "w:textboxTightWrap", "w:outlineLvl", "w:divId", "w:cnfStyle",
  "w:rPr", "w:sectPr", "w:pPrChange")
ORDER_STYLE <- c("w:name", "w:aliases", "w:basedOn", "w:next", "w:link",
  "w:autoRedefine", "w:hidden", "w:uiPriority", "w:semiHidden", "w:unhideWhenUsed",
  "w:qFormat", "w:locked", "w:personal", "w:personalCompose", "w:personalReply",
  "w:rsid", "w:pPr", "w:rPr", "w:tblPr", "w:trPr", "w:tcPr", "w:tblStylePr")

# Return the child `tag` of `parent`, creating it in schema order when absent.
ensure_child <- function(parent, tag, order) {
  node <- xml2::xml_find_first(parent, paste0("./", tag))
  if (!inherits(node, "xml_missing")) return(node)
  ns <- xml2::xml_ns(xml2::xml_root(parent))
  kids <- xml2::xml_children(parent)
  ranks <- match(xml2::xml_name(kids, ns), order)
  later <- which(!is.na(ranks) & ranks > match(tag, order))
  if (length(later) > 0) {
    xml2::xml_add_sibling(kids[[later[1]]], tag, .where = "before")
  } else {
    xml2::xml_add_child(parent, tag)
  }
  xml2::xml_find_first(parent, paste0("./", tag))
}

set_attrs <- function(node, ...) {
  attrs <- list(...)
  for (name in names(attrs)) xml2::xml_set_attr(node, name, attrs[[name]])
  invisible(node)
}

# Removing a namespaced attribute needs the namespace map; setting one does not.
drop_attrs <- function(node, names) {
  ns <- xml2::xml_ns(xml2::xml_root(node))
  for (name in names) xml2::xml_set_attr(node, name, NULL, ns = ns)
  invisible(node)
}

remove_child <- function(parent, tag) {
  node <- xml2::xml_find_first(parent, paste0("./", tag))
  if (!inherits(node, "xml_missing")) xml2::xml_remove(node)
  invisible(parent)
}

# Run properties: explicit fonts (theme references removed), bold, italic,
# colour and size. NULL leaves a property alone; FALSE removes bold or italic.
set_run_props <- function(rpr, font = NULL, bold = NULL, italic = NULL,
                          color = NULL, size_halfpt = NULL) {
  if (!is.null(font)) {
    rf <- ensure_child(rpr, "w:rFonts", ORDER_RPR)
    set_attrs(rf, "w:ascii" = font, "w:hAnsi" = font, "w:cs" = font)
    drop_attrs(rf, c("w:asciiTheme", "w:hAnsiTheme", "w:cstheme", "w:eastAsiaTheme"))
  }
  if (isTRUE(bold)) {
    ensure_child(rpr, "w:b", ORDER_RPR)
    ensure_child(rpr, "w:bCs", ORDER_RPR)
  } else if (isFALSE(bold)) {
    remove_child(rpr, "w:b"); remove_child(rpr, "w:bCs")
  }
  if (isTRUE(italic)) {
    ensure_child(rpr, "w:i", ORDER_RPR)
    ensure_child(rpr, "w:iCs", ORDER_RPR)
  } else if (isFALSE(italic)) {
    remove_child(rpr, "w:i"); remove_child(rpr, "w:iCs")
  }
  if (!is.null(color)) {
    col <- ensure_child(rpr, "w:color", ORDER_RPR)
    set_attrs(col, "w:val" = color)
    drop_attrs(col, c("w:themeColor", "w:themeShade", "w:themeTint"))
  }
  if (!is.null(size_halfpt)) {
    set_attrs(ensure_child(rpr, "w:sz", ORDER_RPR), "w:val" = as.character(size_halfpt))
    set_attrs(ensure_child(rpr, "w:szCs", ORDER_RPR), "w:val" = as.character(size_halfpt))
  }
  invisible(rpr)
}

# Mix a hex colour with white; share is the white proportion (0 to 1).
mix_with_white <- function(hex, share = 0.85) {
  rgb <- grDevices::col2rgb(paste0("#", sub("^#", "", hex)))
  mixed <- round(share * 255 + (1 - share) * rgb)
  toupper(sprintf("%02X%02X%02X", mixed[1], mixed[2], mixed[3]))
}

hex_clean <- function(hex) toupper(sub("^#", "", hex))
