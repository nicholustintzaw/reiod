#' Published cut-offs for every dietary environmental impact metric
#'
#' Every cut-off in Tables 3 and 4a-4g of the Intake methods paper, in long
#' format: one row per metric, indicator, demographic group and table row.
#'
#' Tables 5a and 5b are deliberately **not** stored here. They are composites
#' that reuse values already present - the HESD criterion is
#' `metric == "abs" & indicator == "biodiv"`, and the HDLEI criterion is
#' `metric == "rel" & indicator == "biodiv" & percentile == 30`. A second copy
#' could drift from the first.
#'
#' @section The eutrophication rescaling:
#' `value` equals `value_published` everywhere except the relative benchmarks
#' for eutrophication, where `scale_to_db_unit` is 0.001.
#'
#' The paper states that eutrophication potential is measured in kg PO4(3-)eq.
#' The Table 3 absolute threshold is consistent with that, at 0.0077 to 0.0267.
#' The Table 4f relative benchmarks for the same quantity are 5.3 to 48.7,
#' about a thousand times larger. Read as grams, Table 4f places the absolute
#' threshold between the 40th and 50th percentile of the global reference
#' distribution, which is where the total-land and pasture-land thresholds also
#' sit. Read as kilograms, every diet on earth would fall below the 10th
#' percentile, which is not a coherent reading of a percentile distribution.
#'
#' This is an inference from internal consistency, **not a documented
#' conversion**. Confirm with Intake before publishing any eutrophication
#' result. Every other indicator reconciles between the two tables without
#' adjustment.
#'
#' @section Checking a value against the printed table:
#' Three columns carry the same number in three forms, so that a reader can
#' check the package without having to trust any numeric rendering:
#'
#' \tabular{ll}{
#'   `value_published_str` \tab the literal characters from the paper, never
#'     through a numeric type \cr
#'   `value_published` \tab the nearest IEEE 754 double to that text \cr
#'   `value` \tab the above times `scale_to_db_unit` - what the metric
#'     functions compare against
#' }
#'
#' `data-raw/build_data.R` asserts that
#' `as.numeric(value_published_str) == value_published` for all 616 rows, and
#' that each parsed value still prints back to exactly its published digits.
#'
#' A `double` cannot hold most decimal fractions exactly - that is true of every
#' statistical package, not of this one. What is guaranteed here is that the
#' stored double is the nearest double to the published decimal, that it
#' round-trips back to that decimal, and that the decimal itself is in the file
#' as text. **If you need an exact decimal comparison, compare against
#' `value_published_str`.**
#'
#' Note that R's default `options(digits = 7)` will not show you a published
#' value in full: 15 of the 616 need 14 significant digits.
#' [eiod_lookup_cutoff()] prints at full precision for this reason.
#'
#' @format A data frame with 616 rows and 16 columns:
#' \describe{
#'   \item{metric}{`"abs"` for Table 3, `"rel"` for Tables 4a-4g}
#'   \item{table}{Source table: `"3"`, `"4a"` ... `"4g"`}
#'   \item{indicator}{Short indicator name used by the `eiod_*` functions}
#'   \item{indicator_label}{Human-readable indicator name}
#'   \item{unit}{Unit of `value`, per capita per day}
#'   \item{demogroup}{Demographic group, 1-8}
#'   \item{demogroup_label}{Group name, e.g. "Male 10+ yr"}
#'   \item{sex}{Factor, `"male"` or `"female"`}
#'   \item{age_min, age_max}{Age bounds in years; 999 means no upper bound}
#'   \item{row_order}{Position in the source table}
#'   \item{percentile}{10-90 for relative rows 1-9; `NA` for absolute rows and
#'     for row 10, which repeats P90 as a lower bound}
#'   \item{value}{**The cut-off the metric functions compare against**}
#'   \item{value_published}{The value exactly as printed in the paper}
#'   \item{value_published_str}{The same value as a character string, exactly as
#'     transcribed. Shipped so the published figure can be compared character
#'     for character, not as a rendering of a double}
#'   \item{scale_to_db_unit}{Multiplier linking `value_published` to `value`;
#'     1 except for the 80 relative eutrophication rows described above}
#' }
#'
#' @source Intake-EIOD-Methods-Paper-Jan2026-Final.pdf, Tables 3 and 4a-4g
#'   (pages 16-19). Transcribed programmatically; see `data-raw/build_data.R`.
#'   The same source file drives a companion Stata implementation.
#'
#' @examples
#' data(eiod_cutoffs)
#' str(eiod_cutoffs)
#'
#' # the HESD biodiversity criterion
#' subset(eiod_cutoffs, metric == "abs" & indicator == "biodiv",
#'        c(demogroup_label, value))
"eiod_cutoffs"


#' The seven environmental impact indicators
#'
#' Indicator names accepted by the `eiod_*` functions, with their labels and
#' the units your impact values must be in.
#'
#' @format A data frame with 7 rows and 3 columns:
#' \describe{
#'   \item{indicator}{Short name, as passed to the `eiod_*` functions}
#'   \item{indicator_label}{Human-readable name}
#'   \item{unit}{Required unit, per capita per day}
#' }
#'
#' @examples
#' data(eiod_indicators)
#' eiod_indicators
"eiod_indicators"


#' Synthetic respondent-day data for examples
#'
#' Six hundred simulated respondent-days with age, sex, the seven impact totals
#' and a GDQS score, for use in examples, vignettes and tests.
#'
#' **These are not real survey data.** The values were drawn from lognormal
#' distributions chosen to be roughly plausible. No prevalence computed from
#' this dataset carries any substantive meaning.
#'
#' A small amount of missingness is included in `biodiv_pdf` and `gdqs` so
#' examples show how it propagates.
#'
#' @section The column names are deliberately not the indicator keys:
#' Until October 2026 the impact columns were called `landtotal`, `ghg`,
#' `biodiv` and so on - the same strings the `indicator` argument takes. That
#' made the examples tidy and taught something false: a loop over
#' `eiod_demo[[ind]]` works only because the columns happen to be named after
#' the keys, and readers concluded that reiod required those names.
#'
#' It never did. reiod takes vectors, so any column name has always worked. The
#' columns now carry survey-realistic names with their units, which forces every
#' example to state the indicator-to-column mapping explicitly. See
#' [eiod_demo_map] and [eiod_absolute_all()].
#'
#' @format A data frame with 600 rows and 11 columns:
#' \describe{
#'   \item{id}{Row identifier}
#'   \item{age}{Age in years, 0.5 to 65}
#'   \item{sex}{Factor with levels `"male"` and `"female"`}
#'   \item{land_total_m2yr, land_arable_m2yr, land_pasture_m2yr}{Land use,
#'     m2*year}
#'   \item{ghg_kgco2e}{Greenhouse gas emissions, kg CO2eq}
#'   \item{eutroph_kgpo4e}{Eutrophication potential, kg PO4(3-)eq}
#'   \item{water_litres}{Water use, litres}
#'   \item{biodiv_pdf}{Biodiversity loss, PDF*year}
#'   \item{gdqs}{Global Diet Quality Score}
#' }
#'
#' @seealso [eiod_demo_map] for the indicator-to-column mapping. A deliberately
#'   broken copy ships as
#'   `system.file("extdata", "eiod_broken.csv", package = "reiod")` and is used
#'   in `vignette("troubleshooting")`.
#'
#' @examples
#' data(eiod_demo)
#' head(eiod_demo)
"eiod_demo"


#' Indicator keys mapped to the demonstration data's column names
#'
#' A named character vector in the shape every `*_all()` function expects: the
#' **name** is the indicator key reiod knows, the **value** is the column in
#' [eiod_demo] that holds it.
#'
#' It is shipped rather than retyped in each example, and it exists at all
#' because [eiod_demo]'s columns are deliberately *not* named after the
#' indicator keys. Write the equivalent line for your own data once, near the
#' top of your script, and every later call reads from it.
#'
#' @format A named character vector of length 7.
#'
#' @seealso [eiod_absolute_all()], [eiod_relative_all()], [eiod_demo]
#'
#' @examples
#' data(eiod_demo_map)
#' eiod_demo_map
#'
#' # the same shape, for your own data:
#' # my_map <- c(ghg = "ghg_total_kg", biodiv = "pdf_year", water = "water_l")
"eiod_demo_map"
