#' List the seven environmental impact indicators
#'
#' Prints the indicator names the `eiod_*` functions accept, with their labels
#' and the units your impact values must be in.
#'
#' @section If your data comes from the EIOF database, read this:
#' The EIOF country databases report six of the seven indicators in the unit
#' this package expects - `Land (m2/kg)`, `GHG (kg CO2e/kg)`, `Water Use
#' (L/kg)` and so on. **Eutrophication is the exception.** It is stored as
#' `Eutr. (g PO43-e/kg)` - in **grams**, while the methods paper and this
#' package work in **kilograms**.
#'
#' So the obvious pipeline gives you the wrong unit for one indicator:
#'
#' ```
#' kg food consumed  x  g PO4e per kg food  =  GRAMS PO4e per person per day
#' ```
#'
#' Divide that total by 1000 before passing it to [eiod_absolute_threshold()]
#' or [eiod_relative_band()], or every eutrophication result will be wrong by a
#' factor of a thousand. No other indicator needs this.
#'
#' [eiod_check_magnitude()] detects it - a eutrophication column 1000x too
#' large is reported as a likely gram/kilogram error - but that check is
#' opt-in. See `vignette("precision")` and the `?eiod_cutoffs` section on the
#' eutrophication rescaling.
#'
#' @param quiet If `TRUE`, return the table without printing it.
#'
#' @return A data frame of indicator, label and unit, invisibly when printing.
#'
#' @examples
#' eiod_list_indicators()
#'
#' @export
eiod_list_indicators <- function(quiet = FALSE) {
  ind <- .eiod_data("eiod_indicators")
  if (quiet) return(ind)

  cat("Seven environmental impact indicators, per capita per day:\n\n")
  w <- max(nchar(ind$indicator))
  for (i in seq_len(nrow(ind))) {
    cat(sprintf("  %-*s  %-26s %s\n", w, ind$indicator[i],
                ind$indicator_label[i], ind$unit[i]))
  }
  cat("\nValues must already be summed across everything the respondent\n")
  cat("consumed that day. reiod does not compute impacts from food items.\n")
  cat("\n")
  cat("NOTE on eutrophication, if your impacts come from the EIOF database:\n")
  cat("  EIOF stores it as `Eutr. (g PO43-e/kg)` - in GRAMS - while this\n")
  cat("  package expects kg PO4(3-)eq. Divide your summed total by 1000.\n")
  cat("  No other indicator needs converting. See ?eiod_list_indicators.\n")
  invisible(ind)
}


#' Look up a published cut-off value
#'
#' Returns the cut-off itself, rather than applying it. Useful for reporting
#' which number a respondent was compared against, and for checking the
#' package against the printed tables.
#'
#' @section Printing, and why it has its own method:
#' The published cut-offs need up to **14 significant digits** - `water` for
#' Female 10+ is `1726.3821057877`, and 15 of the 616 values need all 14. R's
#' default `options(digits = 7)` would print that as `1726.382`, which looks as
#' though the package had rounded the guideline.
#'
#' Storage was never the problem; the default *display* was. The returned object
#' therefore carries a class and a print method that uses 15 significant digits
#' and shows, alongside each value, the literal text transcribed from the paper:
#'
#' ```
#'   Male 10+ yr    14.2377570161    as published 14.2377570161
#' ```
#'
#' The `as printed` column is `value_published_str` from [eiod_cutoffs] - a
#' character string that has never been through a numeric type. If you need an
#' exact decimal comparison against the PDF, compare against that, not against a
#' rendering of a double. (The identical complaint, and the identical fix, arose
#' in the companion Stata package in October 2026.)
#'
#' @section Nothing here is rescaled:
#' **Every value this function returns is exactly what the methods paper
#' prints**, for all 616 cut-offs. The package does not adjust a published
#' number anywhere, so you can check any row of [eiod_cutoffs] against the PDF
#' and expect a character-for-character match.
#'
#' Where the paper's own units need reconciling - which happens for
#' eutrophication, and only for eutrophication - the adjustment is applied to
#' **your data** at the moment of comparison, is announced in a message, and is
#' described in `vignette("eutrophication")`.
#'
#' The object is an ordinary named numeric underneath: `[`, `c()` and arithmetic
#' all return plain numbers, so nothing downstream needs to know about the class.
#'
#' @param indicator One of the seven indicator names.
#' @param group Demographic group 1-8, or `NULL` for all eight.
#' @param metric `"abs"` for the Table 3 absolute threshold, or `"rel"` for a
#'   Table 4 relative benchmark cut-point.
#' @param percentile Required when `metric = "rel"`: a multiple of 10 from 10
#'   to 90.
#' @param published **No longer has any effect**, and retained only so existing
#'   scripts keep working. Until October 2026 the package stored 80 relative
#'   eutrophication rows pre-rescaled, and this argument switched between the
#'   stored and the published figure. Nothing is rescaled any more - `value` is
#'   the published figure for all 616 rows - so both settings return the same
#'   thing. See `vignette("eutrophication")`.
#'
#' @return A named numeric vector of class `eiod_cutoff`, named by demographic
#'   group label. Use `print(x, digits = )` to change the displayed precision,
#'   or `as.numeric(x)` to drop the class.
#'
#' @examples
#' # the HESD biodiversity criterion, all groups
#' eiod_lookup_cutoff("biodiv", metric = "abs")
#'
#' # the HDLEI biodiversity criterion
#' eiod_lookup_cutoff("biodiv", metric = "rel", percentile = 30)
#'
#' # one group, printed to every published digit
#' eiod_lookup_cutoff("water", group = 8, metric = "abs")
#'
#' # what R's default options(digits = 7) would have shown instead
#' print(c(eiod_lookup_cutoff("water", group = 8, metric = "abs")))
#'
#' @export
eiod_lookup_cutoff <- function(indicator, group = NULL,
                               metric = c("abs", "rel"),
                               percentile = NULL, published = FALSE) {

  metric <- match.arg(metric)
  .eiod_check_indicator(indicator)

  cut <- .eiod_data("eiod_cutoffs")
  s <- cut[cut$metric == metric & cut$indicator == indicator, ]

  if (metric == "rel") {
    if (is.null(percentile)) {
      stop("`percentile` is required when metric = \"rel\". ",
           "Use a multiple of 10 from 10 to 90.", call. = FALSE)
    }
    if (!is.numeric(percentile) || length(percentile) != 1L ||
        percentile %% 10 != 0 || percentile < 10 || percentile > 90) {
      stop("`percentile` must be a multiple of 10 between 10 and 90.",
           call. = FALSE)
    }
    s <- s[!is.na(s$percentile) & s$percentile == percentile, ]
  } else {
    if (!is.null(percentile)) {
      stop("`percentile` does not apply when metric = \"abs\".", call. = FALSE)
    }
  }

  if (!is.null(group)) {
    if (!is.numeric(group) || !all(group %in% 1:8)) {
      stop("`group` must be one or more integers from 1 to 8.", call. = FALSE)
    }
    s <- s[s$demogroup %in% group, ]
  }

  s <- s[order(s$demogroup), ]

  structure(
    stats::setNames(s$value, s$demogroup_label),
    class           = c("eiod_cutoff", "numeric"),
    indicator       = indicator,
    indicator_label = s$indicator_label[1],
    unit            = s$unit[1],
    metric          = metric,
    percentile      = percentile,
    published_str   = s$value_published_str
  )
}


#' @param x An `eiod_cutoff` object.
#' @param digits Significant digits to display. The default of 15 shows every
#'   published digit; the widest cut-off in the tables needs 14.
#' @param ... Ignored.
#' @rdname eiod_lookup_cutoff
#' @export
print.eiod_cutoff <- function(x, digits = 15, ...) {

  metric <- attr(x, "metric")
  pct    <- attr(x, "percentile")
  pstr   <- attr(x, "published_str")
  ind    <- attr(x, "indicator")

  head_txt <- if (identical(metric, "abs")) {
    "Table 3 absolute threshold"
  } else {
    paste0("Tables 4a-4g relative benchmark, P", pct)
  }
  cat(head_txt, " - ", attr(x, "indicator_label"), "\n", sep = "")
  cat("  unit: ", attr(x, "unit"), " per capita per day\n\n", sep = "")

  val <- vapply(as.numeric(x), function(v) format(v, digits = digits),
                character(1))
  lab <- names(x)
  if (is.null(lab)) lab <- rep("", length(x))

  vhead    <- "value"
  wl       <- max(nchar(lab), 5L)
  wv       <- max(nchar(val), nchar(vhead))
  show_pub <- !is.null(pstr) && length(pstr) == length(x)

  cat(sprintf("  %-*s  %-*s%s\n", wl, "group", wv, vhead,
              if (show_pub) "  as printed" else ""))
  for (i in seq_along(x)) {
    cat(sprintf("  %-*s  %-*s%s\n", wl, lab[i], wv, val[i],
                if (show_pub) paste0("  ", pstr[i]) else ""))
  }

  cat("\n  printed at ", digits, " significant digits.\n", sep = "")
  if (show_pub) {
    cat("  Every value above is EXACTLY as printed in the methods paper -\n")
    cat("  nothing in this package rescales a published cut-off. `as printed`\n")
    cat("  is the literal text, which has never been through a numeric type.\n")
  }
  if (identical(ind, "eutroph")) {
    cat("\n  NOTE: eutrophication is printed in different units in the two\n")
    cat("  tables. Table 3 is in kg PO4(3-)eq; Table 4f is in g PO4(3-)eq.\n")
    cat("  Supply your data in GRAMS, as the EIOF database reports it;\n")
    cat("  eiod_absolute_threshold() converts to kg for you and says so.\n")
    cat("  See vignette(\"eutrophication\").\n")
  }
  invisible(x)
}


#' @rdname eiod_lookup_cutoff
#' @param e1,e2 Operands.
#' @export
Ops.eiod_cutoff <- function(e1, e2) {
  # Arithmetic on a cut-off should give a plain number back, not drag the
  # class and its metadata into an unrelated result.
  if (!missing(e1)) e1 <- .eiod_bare(e1)
  if (missing(e2)) return(get(.Generic)(e1))
  get(.Generic)(e1, .eiod_bare(e2))
}
