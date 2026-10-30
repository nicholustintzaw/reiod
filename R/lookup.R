#' List the seven environmental impact indicators
#'
#' Prints the indicator names the `eiod_*` functions accept, with their labels
#' and the units your impact values must be in.
#'
#' @section If your data comes from the EIOF database:
#' **Supply it as it comes - nothing needs converting.** The units in this
#' table are the EIOF database's own: `Land (m2/kg)`, `GHG (kg CO2e/kg)`,
#' `Eutr. (g PO43-e/kg)`, `Water Use (L/kg)`. Multiply by kilograms of food
#' consumed, sum to the respondent-day, and pass the result straight in.
#'
#' ```
#' kg food consumed  x  EIOF intensity per kg  =  the value this package wants
#' ```
#'
#' **This changed in October 2026.** Eutrophication used to be the exception:
#' the methods paper printed its Table 3 threshold in kilograms while the
#' database reported grams, so a conversion was needed and this package applied
#' one. Intake has since confirmed that both cut-off tables are in grams and
#' supplied corrected Table 3 values. Every indicator is now on a single unit
#' and no conversion happens anywhere.
#'
#' If you are revisiting a script written before that change and it divides
#' eutrophication by 1000, **remove the division** - the package no longer
#' expects it. `?eiod_cutoffs` has the detail.
#'
#' @section Sum over ALL consumed foods, including uncosted ones:
#' Values must be summed over every food consumed, including any the EIOF
#' database cannot cost. Not every food has an impact factor. The EIOF
#' country databases mark foods with no available estimate, and such a food
#' contributes **nothing** to the
#' day's total - so a respondent who ate one has an impact that is understated
#' by an unknown amount.
#'
#' **This package cannot detect that.** It receives one number per
#' respondent-day; whether that number was summed over complete or incomplete
#' coverage is not recoverable from the number itself. The only exception is
#' the extreme case: if every food lacked a factor and the sum was coded `0`
#' rather than `NA`, [eiod_check_impact()] flags the zero.
#'
#' It matters more here than in most analyses because these metrics compare
#' each respondent against a **fixed external cut-off** rather than against your
#' sample, so uneven coverage shifts results with nothing in the output looking
#' wrong.
#'
#' Count it where it is still visible - when you aggregate to the
#' respondent-day - preferably as the **share of consumed weight** carrying a
#' factor rather than a count of items, and report it with any prevalence. See
#' `vignette("troubleshooting")`.
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
  cat("These are the EIOF database's own units. Supply your totals as they\n")
  cat("come - no indicator needs converting.\n")
  cat("  Changed Oct 2026: eutrophication used to need a /1000 step, because\n")
  cat("  the paper printed its Table 3 threshold in kg. Intake has corrected\n")
  cat("  that row to grams. Remove the division from older scripts.\n")
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
#' **Every value this function returns is the published cut-off**, exactly as
#' printed in the methods paper for 608 of the 616, so you can check those
#' rows of [eiod_cutoffs] against the PDF and expect a character-for-character
#' match. The other eight are the Table 3 eutrophication thresholds, which
#' carry the values Intake confirmed in October 2026 (in grams, where the PDF
#' prints kilograms) and are marked by the `value_source` column.
#'
#' Nothing is converted at the moment of comparison either: every indicator,
#' eutrophication included, is on one unit across both tables. Supply your
#' values in those units. See `vignette("eutrophication")`.
#'
#' The object is an ordinary named numeric underneath: `[`, `c()` and
#' arithmetic all return plain numbers, so nothing downstream needs to know
#' about the class.
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
    published_str   = s$value_published_str,
    corrected       = s$value_source != "published"
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
  pstr      <- attr(x, "published_str")
  ind       <- attr(x, "indicator")
  corrected <- attr(x, "corrected")

  head_txt <- if (identical(metric, "abs")) {
    "Table 3 absolute threshold"
  } else {
    paste0("Tables 4a-4g relative benchmark, P", pct)
  }
  cat(head_txt, " - ", attr(x, "indicator_label"), "\n", sep = "")
  cat("  unit: ", attr(x, "unit"), " per capita per day\n\n", sep = "")

  val <- vapply(as.numeric(x), format, character(1), digits = digits)
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
    cat("  `as printed` is the literal text this package ships, which has\n")
    cat("  never been through a numeric type. Nothing is rescaled here.\n")
  }
  if (!is.null(corrected) && any(corrected)) {
    cat("\n  NOTE: these values were CORRECTED BY INTAKE in October 2026 and\n")
    cat("  DIFFER FROM THE CURRENTLY PUBLISHED PDF, which prints the Table 3\n")
    cat("  eutrophication row in kilograms. Both Table 3 and Table 4f are in\n")
    cat("  grams; the corrected values are the printed ones x1000, so no\n")
    cat("  result changes. See vignette(\"eutrophication\") and",
        "?eiod_cutoffs.\n")
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
