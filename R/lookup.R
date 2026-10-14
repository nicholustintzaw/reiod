#' List the seven environmental impact indicators
#'
#' Prints the indicator names the `eiod_*` functions accept, with their labels
#' and the units your impact values must be in.
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
#' The `as published` column is `value_published_str` from [eiod_cutoffs] - a
#' character string that has never been through a numeric type. If you need an
#' exact decimal comparison against the PDF, compare against that, not against a
#' rendering of a double. (The identical complaint, and the identical fix, arose
#' in the companion Stata package in October 2026.)
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
#' @param published If `TRUE`, return the value exactly as printed in the
#'   paper rather than the harmonised value the metric functions use. The two
#'   differ only for relative eutrophication - 80 rows of 616, all of them
#'   relative; see `vignette("reiod")`.
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
  out <- if (published) s$value_published else s$value

  structure(
    stats::setNames(out, s$demogroup_label),
    class           = c("eiod_cutoff", "numeric"),
    indicator       = indicator,
    indicator_label = s$indicator_label[1],
    unit            = s$unit[1],
    metric          = metric,
    percentile      = percentile,
    published       = published,
    published_str   = s$value_published_str,
    scale           = s$scale_to_db_unit
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
  pub    <- isTRUE(attr(x, "published"))
  pstr   <- attr(x, "published_str")
  scale  <- attr(x, "scale")

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

  vhead    <- if (pub) "published value" else "value"
  wl       <- max(nchar(lab), 5L)
  wv       <- max(nchar(val), nchar(vhead))
  show_pub <- !is.null(pstr) && length(pstr) == length(x)
  rescaled <- !is.null(scale) && any(scale != 1)

  cat(sprintf("  %-*s  %-*s%s\n", wl, "group", wv, vhead,
              if (show_pub) "  as printed" else ""))
  for (i in seq_along(x)) {
    cat(sprintf("  %-*s  %-*s%s\n", wl, lab[i], wv, val[i],
                if (show_pub) paste0("  ", pstr[i]) else ""))
  }

  cat("\n  printed at ", digits, " significant digits.\n", sep = "")
  if (show_pub) {
    cat("  `as printed` is the literal text transcribed from the paper - it has\n")
    cat("  never been through a numeric type. Compare against that for an exact\n")
    cat("  decimal check.\n")
  }
  if (rescaled && !pub) {
    cat("\n  `value` carries the x", format(unique(scale)[1]),
        " eutrophication rescaling - an INFERENCE,\n", sep = "")
    cat("  not a documented conversion. See ?eiod_cutoffs. Use\n")
    cat("  published = TRUE for the unscaled figure.\n")
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
