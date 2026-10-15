#' Absolute threshold metric (Table 3)
#'
#' Codes a one-day diet `1` if its per capita environmental impact falls below
#' the demographic group's share of the per capita daily planetary boundary,
#' and `0` if it does not.
#'
#' @section Interpretation:
#' "x% of one-day diets fall below the absolute per capita daily threshold
#' established for \[indicator\]."
#'
#' This is a pass/fail against a planetary boundary share. It says nothing
#' about how the diet compares with other diets; for that, see
#' [eiod_relative_band()]. The two metric families answer different questions
#' and will not agree.
#'
#' @section The comparison is strict:
#' The published cut-offs carry a `<` sign, so a diet sitting exactly on the
#' threshold is *not* below it and is coded `0`.
#'
#' @section Missing values:
#' A missing impact returns `NA`, not `0`. This matters more than it looks: in
#' R, `NA < threshold` is `NA`, but a careless implementation using
#' `ifelse(value < threshold, 1, 0)` on a comparison that has already been
#' coerced can turn missing data into an apparent threshold breach. Here the
#' guard is explicit.
#'
#' @section Eutrophication is converted, and nothing else is:
#' Table 3 prints eutrophication in **kg** PO4(3-)eq while Table 4f prints it
#' in **grams** - and the EIOF database, which is where your values come from,
#' reports `Eutr. (g PO43-e/kg)`. So you supply grams, and this function
#' divides by 1000 before comparing against Table 3. It emits a message when it
#' does; wrap the call in `suppressMessages()` if you are looping and already
#' know.
#'
#' **The published cut-off is never altered.** `eiod_cutoffs` holds exactly
#' what the paper prints for all 616 rows; the adjustment is applied to your
#' data at the point of comparison, in one place, and only for this one
#' indicator and this one table. [eiod_relative_band()] needs no conversion.
#'
#' See `vignette("eutrophication")` for the evidence, and note that the unit
#' reading is an inference not yet confirmed by Intake.
#'
#' @section Storage type is checked here, not only in the check suite:
#' An integer `value` is refused with an error. `is.numeric(1L)` is `TRUE`, so
#' an integer column would otherwise pass every guard and be compared against
#' the threshold with its fractional part already truncated away. Measured on
#' 200,000 simulated respondent-days in the companion Stata implementation, that
#' biased mean greenhouse gas emissions down by 13%. Convert with `as.double()`.
#'
#' This is the only data-quality test on the default path. The fuller suite -
#' sign, zeros, unit magnitude, retained significant digits, cut-off proximity -
#' is in [eiod_check_data()] and [eiod_check_precision()], and is **not** run for
#' you. Run it first; see `vignette("precision")`.
#'
#' @param value Numeric vector of per capita daily impact, already summed
#'   across everything the respondent consumed that day, in the unit shown by
#'   [eiod_list_indicators()].
#' @param group Integer vector of demographic groups 1-8, from
#'   [eiod_age_sex_group()].
#' @param indicator One of `"landtotal"`, `"landarable"`, `"landpasture"`,
#'   `"ghg"`, `"eutroph"`, `"water"`, `"biodiv"`.
#' @param details If `TRUE`, return a data frame that also reports the threshold
#'   each observation was actually compared against, rather than just the
#'   result. Default `FALSE`.
#'
#' @return An integer vector: `1` below the threshold, `0` at or above it, `NA`
#'   where the impact or the group is missing.
#'
#'   If `details = TRUE`, a data frame with one row per observation and the
#'   columns `value`, `group`, `cutoff` and `below`. `cutoff` is the Table 3
#'   threshold applied to that row, so a reader can audit the comparison without
#'   opening the reference table. (Equivalent to `threshvar()` in the companion
#'   Stata command.) For `indicator = "eutroph"` an extra `value_kg`
#'   column appears, holding the value after the g-to-kg conversion described
#'   below, so the whole chain - value in grams, value in kilograms, published
#'   cut-off, result - can be read off one table.
#'
#' @seealso [eiod_relative_band()], [eiod_absolute_all()],
#'   [eiod_lookup_cutoff()], [eiod_check_data()]
#'
#' @examples
#' data(eiod_demo)
#' grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
#'
#' # the column is called ghg_kgco2e; the indicator key is "ghg".
#' # They are different things, and your data will not use the keys.
#' ghg_ok <- eiod_absolute_threshold(eiod_demo$ghg_kgco2e, grp, "ghg")
#' table(ghg_ok, useNA = "ifany")
#'
#' # which number each respondent was compared against
#' head(eiod_absolute_threshold(eiod_demo$ghg_kgco2e, grp, "ghg",
#'                              details = TRUE))
#'
#' # all seven indicators: state the mapping from indicator key to column
#' eiod_absolute_all(eiod_demo, grp, eiod_demo_map)[1:3, ]
#'
#' @export
eiod_absolute_threshold <- function(value, group, indicator, details = FALSE) {

  .eiod_check_indicator(indicator)
  .eiod_check_value(value)
  .eiod_check_group(group, n = length(value))
  if (!is.logical(details) || length(details) != 1L || is.na(details)) {
    stop("`details` must be TRUE or FALSE.", call. = FALSE)
  }

  thr <- .eiod_abs_thresholds(indicator)

  # Table 3 eutrophication is printed in kg while the EIOF database - and
  # therefore the user's value - is in grams. One place does this; see
  # .eiod_to_cutoff_unit() and vignette("eutrophication").
  conv <- .eiod_to_cutoff_unit(value, indicator, "abs")
  cmp  <- conv$value

  out <- rep(NA_integer_, length(cmp))

  for (g in 1:8) {
    idx <- which(!is.na(group) & group == g & !is.na(cmp))
    if (length(idx)) {
      out[idx] <- as.integer(cmp[idx] < thr[g])
    }
  }

  if (!details) return(out)

  cutoff <- rep(NA_real_, length(value))
  ok <- !is.na(group)
  cutoff[ok] <- thr[group[ok]]

  d <- data.frame(value = as.numeric(value), group = as.integer(group),
                  cutoff = cutoff, below = out)

  # Only when a conversion happened: keep what was actually compared, under a
  # name that states the unit. The Stata command does the same thing by
  # leaving `<yourvar>_kg' in the dataset; here the vector API means it lands
  # in the detail frame instead. Either way the whole chain is inspectable:
  #
  #   value (g) -> value_kg -> cutoff (published Table 3, kg) -> below
  if (conv$factor != 1) {
    d <- data.frame(value = as.numeric(value),
                    value_kg = as.numeric(cmp),
                    group = as.integer(group),
                    cutoff = cutoff, below = out)
    attr(d, "conversion") <- conv$note
  }
  d
}
