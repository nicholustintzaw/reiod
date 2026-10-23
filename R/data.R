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
#' @section Nothing here is rescaled:
#' **`value` is the cut-off exactly as this package received it, for all 616
#' rows**, and `value_published_str` is the same number as literal text. The
#' package applies no conversion to a cut-off and none to your data.
#'
#' For 608 rows "as received" means "as printed in the methods paper", and you
#' can check them against the PDF character for character. The remaining eight
#' are described in the next section.
#'
#' @section Eight rows differ from the published PDF, on Intake's instruction:
#' The **Table 3 eutrophication thresholds** in `eiod_cutoffs` are **not** the
#' numbers the currently published paper prints. They are corrections supplied
#' by Intake in October 2026, and the `value_source` column marks them:
#'
#' ```r
#' subset(eiod_cutoffs, value_source != "published",
#'        c(demogroup_label, unit, value, value_source))
#' ```
#'
#' **What was wrong.** The paper prints those eight cells in **kilograms**
#' PO4(3-)eq while Table 4f, and the EIOF food databases, use **grams**. Intake
#' confirmed by email that both tables are intended to be in grams, and
#' supplied the corrected Table 3 values.
#'
#' **What changed, and what did not.** The corrected values are the printed
#' ones multiplied by 1000, carried to full precision - the quantity is
#' identical, only the unit it is expressed in has changed. Dividing any
#' corrected value by 1000 reproduces the printed figure to the ten decimals
#' the PDF gives, and `data-raw/build_data.R` asserts exactly that. **No
#' classification moves**: tested on 400,000 simulated gram-scale values, old
#' and new behaviour agreed everywhere except within about one unit in the last
#' place of a cut-off, where the new path is the more exact of the two because
#' it no longer divides before comparing.
#'
#' **Consequence for you: supply eutrophication in grams**, which is what the
#' EIOF databases give you (`Eutr. (g PO43-e/kg)` x kg food = g). Every
#' indicator now uses one unit across both tables, and nothing is converted
#' anywhere. Between July and October 2026 this package divided eutrophication
#' values by 1000 on your behalf; that step is gone.
#'
#' See `vignette("eutrophication")` for the full history, including the
#' evidence that led to the question being raised.
#'
#' @section Checking a value against the printed table:
#' Two columns carry the same number in two forms, so that a reader can check
#' the package without having to trust any numeric rendering:
#'
#' \tabular{ll}{
#'   `value_published_str` \tab the literal characters from the paper, never
#'     through a numeric type \cr
#'   `value` \tab the nearest IEEE 754 double to that text - and what the
#'     metric functions compare against
#' }
#'
#' `data-raw/build_data.R` asserts that
#' `as.numeric(value_published_str) == value` for all 616 rows, and that each
#' parsed value still prints back to exactly its published digits.
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
#' @format A data frame with 616 rows and 15 columns:
#' \describe{
#'   \item{metric}{`"abs"` for Table 3, `"rel"` for Tables 4a-4g}
#'   \item{table}{Source table: `"3"`, `"4a"` ... `"4g"`}
#'   \item{indicator}{Short indicator name used by the `eiod_*` functions}
#'   \item{indicator_label}{Human-readable indicator name}
#'   \item{unit}{Unit **this table is printed in**, per capita per day. The
#'     same for both tables for six indicators; for eutrophication, kg for
#'     Table 3 and g for Table 4f}
#'   \item{demogroup}{Demographic group, 1-8}
#'   \item{demogroup_label}{Group name, e.g. "Male 10+ yr"}
#'   \item{sex}{Factor, `"male"` or `"female"`}
#'   \item{age_min, age_max}{Age bounds in years; 999 means no upper bound}
#'   \item{row_order}{Position in the source table}
#'   \item{percentile}{10-90 for relative rows 1-9; `NA` for absolute rows and
#'     for row 10, which repeats P90 as a lower bound}
#'   \item{value}{**The cut-off the metric functions compare against.** Nothing
#'     is rescaled: for 608 rows this is exactly what the paper prints, and for
#'     the other eight it is exactly what Intake supplied}
#'   \item{value_published_str}{The same value as a character string, exactly as
#'     received. Shipped so the figure can be compared character for character,
#'     not as a rendering of a double}
#'   \item{value_source}{`"published"` for the 608 rows transcribed from the
#'     paper; `"intake correction 2026-10"` for the eight Table 3
#'     eutrophication thresholds Intake corrected. **Those eight do not match
#'     the currently published PDF** - see the section above}
#' }
#'
#' @source Intake-EIOD-Methods-Paper-Jan2026-Final.pdf, Tables 3 and 4a-4g
#'   (pages 16-19), available at
#'   <https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf>.
#'   Transcribed programmatically; see `data-raw/build_data.R`. The same source
#'   file drives a companion Stata implementation.
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
#'   \item{eutroph_gpo4e}{Eutrophication potential, **g** PO4(3-)eq. Grams,
#'     like the EIOF databases and both cut-off tables. Renamed from
#'     `eutroph_kgpo4e` and rescaled in 0.1.0; see `vignette("eutrophication")`}
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
