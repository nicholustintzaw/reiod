# ---------------------------------------------------------------------------- #
# Internal helpers. Not exported.
# ---------------------------------------------------------------------------- #

#' Access a dataset shipped with the package
#'
#' Avoids the "no visible binding for global variable" note that referring to
#' lazy-loaded package data directly would produce under `R CMD check`.
#'
#' @param name Dataset name.
#' @return The dataset.
#' @noRd
.eiod_data <- function(name) {
  get(name, envir = asNamespace("reiod"))
}

#' The seven valid indicator names
#' @noRd
.eiod_valid_indicators <- function() {
  c("landtotal", "landarable", "landpasture", "ghg",
    "eutroph", "water", "biodiv")
}

#' Validate an indicator name
#' @noRd
.eiod_check_indicator <- function(indicator) {
  if (!is.character(indicator) || length(indicator) != 1L || is.na(indicator)) {
    stop("`indicator` must be a single character string.", call. = FALSE)
  }
  ok <- .eiod_valid_indicators()
  if (!indicator %in% ok) {
    stop("`indicator` must be one of: ", paste(ok, collapse = ", "),
         ".\n  Got: \"", indicator, "\".",
         "\n  See eiod_list_indicators() for labels and units.",
         call. = FALSE)
  }
  invisible(indicator)
}

#' Absolute thresholds for one indicator
#'
#' @return A numeric vector of length 8, indexed by demographic group.
#' @noRd
.eiod_abs_thresholds <- function(indicator) {
  cut <- .eiod_data("eiod_cutoffs")
  s <- cut[cut$metric == "abs" & cut$indicator == indicator, ]
  if (nrow(s) != 8L) {
    stop("expected 8 absolute thresholds for \"", indicator,
         "\", found ", nrow(s), ". The cut-off dataset is damaged.",
         call. = FALSE)
  }
  s$value[order(s$demogroup)]
}

#' Relative cut-points for one indicator
#'
#' @return An 8 x 9 numeric matrix: rows are demographic groups, columns are
#'   the P10..P90 cut-points in ascending order.
#' @noRd
.eiod_rel_cutpoints <- function(indicator) {
  cut <- .eiod_data("eiod_cutoffs")
  s <- cut[cut$metric == "rel" & cut$indicator == indicator &
             !is.na(cut$percentile), ]
  if (nrow(s) != 72L) {
    stop("expected 72 relative cut-points for \"", indicator,
         "\" (8 groups x P10-P90), found ", nrow(s),
         ". The cut-off dataset is damaged.", call. = FALSE)
  }
  m <- matrix(NA_real_, nrow = 8L, ncol = 9L)
  m[cbind(s$demogroup, s$percentile / 10L)] <- s$value
  if (anyNA(m)) stop("incomplete cut-point grid for \"", indicator, "\".",
                     call. = FALSE)
  m
}

#' The unit string for one indicator
#'
#' This is the unit the USER supplies. It is not always the unit a given
#' cut-off table is printed in - see [.eiod_to_cutoff_unit()].
#'
#' @noRd
.eiod_unit <- function(indicator) {
  ind <- .eiod_data("eiod_indicators")
  ind$unit[match(indicator, ind$indicator)]
}

#' Put the user's values on the unit the cut-off table is printed in
#'
#' The ONE place in the package where a unit conversion happens, so there is
#' exactly one rule to find, read and check.
#'
#' Six of the seven indicators need nothing: the EIOF database, the methods
#' paper and both cut-off tables all agree. **Eutrophication does not.**
#'
#' \itemize{
#'   \item the EIOF country databases report it as `Eutr. (g PO43-e/kg)`, so a
#'     respondent total built from them is in **grams**;
#'   \item Table 4f is printed in grams, so the relative metric needs nothing;
#'   \item Table 3 is printed in **kilograms** - the methods paper states this
#'     explicitly on p.29 - so the absolute metric needs the user's value
#'     divided by 1000.
#' }
#'
#' The conversion is applied to the USER'S VALUE, never to the published
#' cut-off. `eiod_cutoffs` therefore holds exactly what the paper prints, for
#' all 616 rows, and can be checked line by line against the PDF. That was a
#' deliberate change on 2026-10-14; before it, the 80 Table 4f rows were stored
#' pre-divided and matched nothing in the source document.
#'
#' @param value The user's impact vector.
#' @param indicator Indicator key.
#' @param metric `"abs"` or `"rel"`.
#' @param quiet Suppress the message. Used when a caller has already reported
#'   the conversion, so it is not announced twice.
#'
#' @return A list with `value` (possibly converted), `factor` (the multiplier
#'   applied, 1 when none) and `note` (a one-line description, or `NULL`).
#' @noRd
.eiod_to_cutoff_unit <- function(value, indicator, metric, quiet = FALSE) {

  out <- list(value = value, factor = 1, note = NULL)

  if (identical(indicator, "eutroph") && identical(metric, "abs")) {
    out$factor <- 1e-3
    out$value  <- value * 1e-3
    out$note   <- paste0(
      "eutrophication: your values were divided by 1000 (g -> kg PO4(3-)eq) ",
      "to match Table 3, which the methods paper prints in kilograms. ",
      "Supply this indicator in GRAMS, as the EIOF database reports it. ",
      "Table 4f is printed in grams and needs no conversion. ",
      "See vignette(\"eutrophication\").")
    if (!quiet) message(out$note)
  }

  out
}

#' Validate a demographic group vector
#' @noRd
.eiod_check_group <- function(group, n = NULL) {
  if (!is.numeric(group)) {
    stop("`group` must be numeric, with values 1-8. ",
         "Build it with eiod_age_sex_group().", call. = FALSE)
  }
  bad <- !is.na(group) & !(group %in% 1:8)
  if (any(bad)) {
    stop(sum(bad), " value(s) in `group` are outside 1-8. ",
         "Build it with eiod_age_sex_group().", call. = FALSE)
  }
  if (!is.null(n) && length(group) != n) {
    stop("`group` has length ", length(group),
         " but the impact vector has length ", n, ".", call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate a numeric impact vector
#'
#' This runs on the path every metric function takes, so it carries the checks
#' that must never be skippable. The fuller diagnostics live in
#' [eiod_check_impact()], which reports rather than stops; this one stops.
#'
#' The integer branch was added after the companion Stata implementation
#' measured the cost of the equivalent fault. See [eiod_check_impact()] for why
#' `is.numeric()` alone is not enough: `is.numeric(1L)` is `TRUE`.
#'
#' @noRd
.eiod_check_value <- function(value, arg = "value") {
  if (is.factor(value)) {
    stop("`", arg, "` is a factor. as.numeric() on a factor returns the level ",
         "codes, not the values, so this would silently produce wrong results. ",
         "Convert with as.numeric(as.character(x)), then re-check. ",
         "See eiod_check_impact().", call. = FALSE)
  }
  if (is.character(value)) {
    stop("`", arg, "` is character, not numeric. This usually means the ",
         "column failed to import: a stray symbol such as \"<0.001\", a decimal ",
         "comma, or a thousands separator. See eiod_check_impact().",
         call. = FALSE)
  }
  if (is.integer(value)) {
    stop("`", arg, "` is an integer vector, not a double. Integer storage ",
         "truncates toward zero, so the fractional part of every impact is ",
         "already gone before reiod sees it - and `is.numeric()` returns TRUE ",
         "for an integer, so nothing else would catch this. ",
         "On 200,000 simulated respondent-days the companion Stata ",
         "implementation measured a 13% downward bias in mean greenhouse gas ",
         "emissions from exactly this fault. ",
         "Convert with as.double(x), then re-check. See eiod_check_impact().",
         call. = FALSE)
  }
  if (!is.numeric(value)) {
    stop("`", arg, "` must be numeric.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Strip reiod's own attributes from a vector
#'
#' `eiod_lookup_cutoff()` returns a classed vector so it can print at published
#' precision. Arithmetic on it should return a plain number, not drag the class
#' and its metadata along into an unrelated result.
#'
#' @noRd
.eiod_bare <- function(x) {
  if (inherits(x, "eiod_cutoff")) {
    nm <- names(x)
    x <- as.vector(x)
    names(x) <- nm
  }
  x
}

#' Number of significant digits needed to reproduce each value exactly
#'
#' Used by [eiod_check_precision()]. A column whose maximum is 7 or fewer,
#' across many distinct values, is consistent with single-precision storage or
#' a truncated export.
#'
#' @param x A numeric vector.
#' @return An integer vector; `NA` where `x` is zero or not finite.
#' @noRd
.eiod_nsig <- function(x) {
  res <- rep(NA_integer_, length(x))
  ok <- is.finite(x) & x != 0
  if (!any(ok)) return(res)
  xv <- x[ok]
  nd <- rep(17L, length(xv))
  for (d in 16:1) {
    nd[signif(xv, d) == xv] <- d
  }
  res[ok] <- nd
  res
}

#' Resolve a sex vector to internal codes
#'
#' Returns 1 for male, 2 for female, `NA` for missing. Accepts a factor,
#' character or numeric vector. See [eiod_age_sex_group()] for the full
#' discussion of which input type to prefer.
#'
#' The numeric branch deliberately refuses to guess. Survey data uses 1/2 and
#' 0/1 about equally often, and guessing wrong inverts every downstream result
#' silently, so `male` and `female` must be given explicitly.
#'
#' @noRd
.eiod_resolve_sex <- function(sex, male = NULL, female = NULL) {

  if (is.logical(sex) && all(is.na(sex))) {
    return(rep(NA_integer_, length(sex)))
  }
  if (is.logical(sex)) {
    stop("`sex` is logical (TRUE/FALSE), which does not say which value means ",
         "male. Convert it first, for example with eiod_as_sex_factor().",
         call. = FALSE)
  }

  one_given <- xor(is.null(male), is.null(female))
  if (one_given) {
    stop("supply both `male` and `female`, or neither.", call. = FALSE)
  }

  # ---- factor or character: match on labels -------------------------------- #
  if (is.factor(sex) || is.character(sex)) {
    key <- tolower(trimws(as.character(sex)))
    key[key == ""] <- NA_character_

    if (!is.null(male)) {
      mk <- tolower(trimws(as.character(male)))
      fk <- tolower(trimws(as.character(female)))
    } else {
      mk <- c("m", "male", "males", "man", "men", "boy", "boys")
      fk <- c("f", "female", "females", "woman", "women", "girl", "girls")
    }

    out <- rep(NA_integer_, length(key))
    out[key %in% mk] <- 1L
    out[key %in% fk] <- 2L

    unmatched <- unique(key[!is.na(key) & is.na(out)])
    if (length(unmatched)) {
      stop("these values of `sex` were not recognised as male or female:\n  ",
           paste0("\"", unmatched, "\"", collapse = ", "),
           "\n  Set `male` and `female` explicitly, for example ",
           "male = \"M\", female = \"F\".",
           "\n  They are not dropped silently, because that would quietly ",
           "shrink your analysis sample.", call. = FALSE)
    }
    return(out)
  }

  # ---- numeric: require explicit codes ------------------------------------- #
  if (is.numeric(sex)) {
    obs <- sort(unique(sex[!is.na(sex)]))
    if (is.null(male)) {
      stop("`sex` is numeric, so reiod cannot tell which code means male.\n",
           "  Observed codes: ", paste(obs, collapse = ", "), "\n",
           "  Survey data uses 1/2 and 0/1 about equally often, and guessing ",
           "wrong would invert every result without any error.\n",
           "  Either state the codes:\n",
           "    eiod_age_sex_group(age, sex, male = 1, female = 2)\n",
           "  or convert once, which is the recommended route:\n",
           "    dat$sex <- eiod_as_sex_factor(dat$sex, male = 1, female = 2)",
           call. = FALSE)
    }
    if (length(male) != 1L || length(female) != 1L ||
        !is.numeric(male) || !is.numeric(female)) {
      stop("`male` and `female` must each be a single numeric code when `sex` ",
           "is numeric.", call. = FALSE)
    }
    if (male == female) {
      stop("`male` and `female` must differ.", call. = FALSE)
    }

    out <- rep(NA_integer_, length(sex))
    out[!is.na(sex) & sex == male]   <- 1L
    out[!is.na(sex) & sex == female] <- 2L

    unmatched <- setdiff(obs, c(male, female))
    if (length(unmatched)) {
      stop("these values of `sex` match neither male = ", male,
           " nor female = ", female, ":\n  ",
           paste(unmatched, collapse = ", "),
           "\n  Recode them or set `male` and `female` to match your data. ",
           "They are not dropped silently.", call. = FALSE)
    }
    return(out)
  }

  stop("`sex` must be a factor, character or numeric vector. Got ",
       class(sex)[1], ".", call. = FALSE)
}
