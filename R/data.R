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
#' **`value` is the cut-off exactly as printed in the methods paper, for all
#' 616 rows**, and `value_published_str` is the same number as the literal text
#' that was transcribed. You can check any row against the PDF and expect a
#' character-for-character match. That is the whole purpose of shipping this
#' dataset rather than hard-coding the numbers.
#'
#' Until October 2026 the 80 relative eutrophication rows were stored
#' pre-divided by 1000, so that every cut-off sat on one internal unit scale.
#' It was documented and arithmetically sound, but it meant 80 of the shipped
#' numbers could not be found anywhere in the source document. The adjustment
#' now happens in the command instead, applied to the user's value at the
#' moment of comparison. See the next section, and
#' `vignette("eutrophication")`.
#'
#' @section Eutrophication is printed in two different units:
#' The `unit` column records what each table is actually printed in, and for
#' **eutrophication the two tables differ**:
#'
#' \tabular{lll}{
#'   Table 3 (`metric == "abs"`)  \tab 0.0077 - 0.0267 \tab **kg** PO4(3-)eq \cr
#'   Table 4f (`metric == "rel"`) \tab 5.3 - 48.7      \tab **g** PO4(3-)eq
#' }
#'
#' Every other indicator uses one unit across both tables.
#'
#' **Supply your data in grams**, which is what the EIOF database gives you
#' (`Eutr. (g PO43-e/kg)` x kg food = g). [eiod_relative_band()] then needs no
#' conversion, and [eiod_absolute_threshold()] divides by 1000 for you and says
#' so in a message.
#'
#' The methods paper states on p.29 that eutrophication potential "is measured
#' in kilograms of phosphate equivalents (kg PO4(3-)eq)". That statement sits in
#' the section describing how the **EIOF database** was built, and the Table 3
#' absolute thresholds are consistent with it, at 0.0077 to 0.0267.
#'
#' **The Table 4f relative benchmarks are not.** For Male 10+ they run from
#' 18.44 to 48.72 - about 690 times the Table 3 threshold for the same group.
#' The paper never states a unit for the Table 4 series.
#'
#' Four things point the same way:
#'
#' \itemize{
#'   \item **The EIOF database itself reports eutrophication in grams.** The
#'     country databases store it as `Eutr. (g PO43-e/kg)` - checked across the
#'     Burkina Faso, Ethiopia, Ghana and Viet Nam files - while every other
#'     indicator matches the paper's unit (`m2/kg`, `kg CO2e/kg`, `L/kg`).
#'     Eutrophication is the one place where Intake's operational unit and the
#'     paper's stated unit disagree.
#'   \item **The kilogram reading is physically impossible.** A 10th-percentile
#'     adult diet would emit 18.4 kg PO4(3-)eq *per person per day* - 6.7 tonnes
#'     a year, far more than the total mass of food a person eats.
#'   \item **The gram reading reconciles the two tables in all eight
#'     demographic groups.** Rescaled, the Table 3 threshold lands between the
#'     40th and 50th percentile of Table 4f in **8 of 8** groups, across a 3.5x
#'     spread of threshold values - which is where the total-land and
#'     pasture-land thresholds also sit. Unscaled it falls below the 10th
#'     percentile, which only greenhouse gases do.
#'   \item **The two tables have different sources.** Table 3 derives from the
#'     planetary-boundary work of Moberg et al. (2020) and Hallstrom et al.
#'     (2022), who work in kg; Tables 4a-4g are decile averages from the WWF
#'     Planet-Based Diets Database. Two independent upstreams is a plausible
#'     route to one unharmonised unit.
#' }
#'
#' **If your impacts come from the EIOF database**, your summed eutrophication
#' total is therefore in grams and must be divided by 1000 before use here. See
#' [eiod_list_indicators()].
#'
#' **It remains an inference, not a documented conversion**, because the paper
#' does not state the unit of Table 4f either way. Confirm with Intake before
#' publishing any eutrophication result. Every other indicator reconciles
#' between the two tables without adjustment.
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
#' @format A data frame with 616 rows and 14 columns:
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
#'   \item{value}{**The cut-off exactly as printed in the paper**, and what the
#'     metric functions compare against. Nothing is rescaled}
#'   \item{value_published_str}{The same value as a character string, exactly as
#'     transcribed. Shipped so the published figure can be compared character
#'     for character, not as a rendering of a double}
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
