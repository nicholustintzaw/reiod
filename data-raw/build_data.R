# ---------------------------------------------------------------------------- #
# data-raw/build_data.R
#
# Builds the three datasets shipped with reiod:
#   eiod_cutoffs     616 rows, every published cut-off
#   eiod_indicators    7 rows, indicator names, labels and units
#   eiod_demo        600 rows, synthetic respondent-day data for examples
#
# SOURCE  data-raw/eiod_cutoffs.csv
#         Transcribed programmatically from Tables 3 and 4a-4g of
#         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf (pages 16-19).
#         https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf
#         This is the SAME file the companion Stata implementation reads, so
#         the two implementations cannot drift apart at the data layer.
#
# Run with:  source("data-raw/build_data.R")
# ---------------------------------------------------------------------------- #

# ---- 1. read ---------------------------------------------------------------- #
# The cut-offs are printed to 11 significant digits. colClasses = "character"
# on the value column then as.numeric() guarantees a double; letting read.csv
# guess risks a narrower type and there is no way to recover lost digits later.

# Use format() with high precision to ensure consistent conversion across platforms
raw <- utils::read.csv(
  "data-raw/eiod_cutoffs.csv",
  stringsAsFactors = FALSE,
  colClasses = c(value_published = "character")
)

# Keep the literal text. The numeric column below is the nearest double to this
# string and round-trips back to it, but a reader checking the package against
# the printed table should be able to compare the CHARACTERS, not a rendering of
# a binary double. The companion Stata dataset ships the same column, as
# `value_published_str`, for the same reason.
value_published_str <- raw$value_published

# Parse the decimal strings straight to double. Do NOT apply signif() here.
#
# An earlier revision used signif(as.numeric(x), 11) to "match the published
# precision". That was wrong on two counts, and it is a trap worth naming so it
# is not reintroduced:
#
#   1. The published cut-offs do not all carry 11 significant digits. Of the 616
#      values, 198 carry MORE - up to 14, e.g. "1726.3821057877". Rounding to 11
#      destroys published digits on every one of those.
#   2. signif() is itself floating-point arithmetic (a pow/round/divide chain),
#      so it cannot deliver the cross-platform determinism it was reached for.
#      It altered 234 of 616 values on the machine where this was tested.
#
# The cross-platform problem it was meant to solve is real, but it belongs in
# the TESTS, not the data: a decimal string and a binary double are not the same
# object, and two correctly-rounded parsers may land one ULP apart. See
# expect_published_biodiv() in tests/testthat/test-reference_values.R, which
# compares at published decimal precision AND at machine precision instead of
# demanding bit-for-bit identity.
raw$value_published <- as.numeric(raw$value_published)
stopifnot(!anyNA(raw$value_published))

# Guard: every parsed value must still print back to exactly the digits that
# were published. This is what "no precision was lost" actually means, and it
# would have failed loudly under the signif() version above.
.published_digits <- function(s) {
  d <- sub("[eE].*$", "", s)
  d <- gsub("[-.]", "", d)
  d <- sub("^0+", "", d)
  nchar(sub("0+$", "", d))
}
.roundtrip_ok <- mapply(
  function(txt, num) {
    nd <- .published_digits(txt)
    isTRUE(all.equal(as.numeric(txt), num, tolerance = 0)) &&
      identical(as.numeric(sprintf(paste0("%.", max(nd - 1L, 0L), "e"), num)),
                as.numeric(txt))
  },
  value_published_str,
  raw$value_published
)
if (!all(.roundtrip_ok)) {
  stop(sum(!.roundtrip_ok), " value(s) no longer round-trip to their published ",
       "digits. Something is rounding the cut-offs; do not proceed.")
}
rm(.published_digits, .roundtrip_ok)

# ---- 2. the shipped value is the published value, full stop ----------------- #
#
# NOTHING IS RESCALED HERE. Changed 2026-10-14, deliberately.
#
# Until this date the build multiplied the 80 relative eutrophication rows by
# 0.001, so that every cut-off sat on one internal unit scale. That was
# arithmetically fine and it was documented, but it meant `eiod_cutoffs` held
# 80 numbers that could not be found anywhere in the methods paper - and the
# whole point of shipping this dataset is that a reader can check it line by
# line against the PDF.
#
# The adjustment now happens where it belongs: in the command, at the moment of
# comparison, applied to the USER'S value, announced in a message, and
# documented in its own vignette section. See .eiod_to_cutoff_unit() in R/utils.R.
#
# Consequence: `value` is the cut-off exactly as printed, for all 616 rows, and
# the `unit` column now records what each table is actually printed in -
# kg PO4(3-)eq for Table 3 eutrophication, g PO4(3-)eq for Table 4f.
raw$value <- raw$value_published

eiod_cutoffs <- data.frame(
  metric           = raw$metric,
  table            = raw$table,
  indicator        = raw$indicator,
  indicator_label  = raw$indicator_label,
  unit             = raw$unit,
  demogroup        = as.integer(raw$demogroup),
  demogroup_label  = raw$demogroup_label,
  sex              = factor(ifelse(raw$sex == 1, "male", "female"),
                            levels = c("male", "female")),
  age_min          = as.numeric(raw$age_min),
  age_max          = as.numeric(raw$age_max),
  row_order        = as.integer(raw$row_order),
  percentile       = as.integer(raw$percentile),
  value               = raw$value,
  value_published_str = value_published_str,
  stringsAsFactors = FALSE
)

eiod_cutoffs <- eiod_cutoffs[
  order(eiod_cutoffs$metric, eiod_cutoffs$indicator,
        eiod_cutoffs$demogroup, eiod_cutoffs$row_order), ]
rownames(eiod_cutoffs) <- NULL

# ---- 3. structural validation ----------------------------------------------- #
# The same checks the Stata build runs. If one fails the CSV is wrong; do not
# relax the check.
stopifnot(
  nrow(eiod_cutoffs) == 616,
  all(eiod_cutoffs$metric %in% c("abs", "rel")),
  sum(eiod_cutoffs$metric == "abs") == 56,     # 7 indicators x 8 groups
  sum(eiod_cutoffs$metric == "rel") == 560,    # 7 x 8 x 10 rows
  length(unique(eiod_cutoffs$indicator)) == 7,
  all(eiod_cutoffs$demogroup %in% 1:8),
  !anyNA(eiod_cutoffs$value),
  all(eiod_cutoffs$value > 0),
  # complete grid, no duplicates
  !anyDuplicated(eiod_cutoffs[c("metric", "indicator", "demogroup", "row_order")]),
  # the shipped text and the shipped double are the same number
  identical(as.numeric(eiod_cutoffs$value_published_str), eiod_cutoffs$value)
)

# relative rows 1-9 are the P10..P90 cut-points and must be strictly increasing
# within indicator x group; row 10 repeats P90
rel <- eiod_cutoffs[eiod_cutoffs$metric == "rel", ]
by_series <- split(rel, list(rel$indicator, rel$demogroup), drop = TRUE)
stopifnot(length(by_series) == 56)
for (s in by_series) {
  s <- s[order(s$row_order), ]
  stopifnot(
    nrow(s) == 10,
    all(diff(s$value[1:9]) > 0),
    isTRUE(all.equal(s$value[10], s$value[9])),
    identical(s$percentile[1:9], seq.int(10L, 90L, by = 10L)),
    is.na(s$percentile[10])
  )
}

# nothing is rescaled: the shipped number IS the published number, every row
stopifnot(
  identical(eiod_cutoffs$value, as.numeric(eiod_cutoffs$value_published_str)),
  !"scale_to_db_unit" %in% names(eiod_cutoffs)
)

# the unit column must say what each table actually prints. Eutrophication is
# the only indicator where the two tables differ - see R/utils.R.
stopifnot(
  all(eiod_cutoffs$unit[eiod_cutoffs$indicator == "eutroph" &
                        eiod_cutoffs$metric == "abs"] == "kg PO4(3-)eq"),
  all(eiod_cutoffs$unit[eiod_cutoffs$indicator == "eutroph" &
                        eiod_cutoffs$metric == "rel"] == "g PO4(3-)eq"),
  # and every other indicator uses one unit across both tables
  all(vapply(setdiff(unique(eiod_cutoffs$indicator), "eutroph"),
             function(i) length(unique(eiod_cutoffs$unit[
               eiod_cutoffs$indicator == i])) == 1L, logical(1)))
)

# spot-checks against values hand-typed from the printed tables
stopifnot(
  eiod_cutoffs$value[eiod_cutoffs$metric == "abs" &
    eiod_cutoffs$indicator == "biodiv" & eiod_cutoffs$demogroup == 4] ==
    1.2844358718e-12,
  eiod_cutoffs$value[eiod_cutoffs$metric == "abs" &
    eiod_cutoffs$indicator == "water" & eiod_cutoffs$demogroup == 8] ==
    1726.3821057877,
  eiod_cutoffs$value[eiod_cutoffs$metric == "rel" &
    eiod_cutoffs$indicator == "landtotal" & eiod_cutoffs$demogroup == 4 &
    !is.na(eiod_cutoffs$percentile) & eiod_cutoffs$percentile == 50] ==
    15.4981270626
)

message("eiod_cutoffs: all structural checks passed")

# ---- 4. indicator lookup ---------------------------------------------------- #
# `unit` here is the unit the USER must supply, which is not always the unit a
# given cut-off table is printed in. For six indicators the two coincide. For
# eutrophication they do not: the user supplies grams (because that is what the
# EIOF database reports, `Eutr. (g PO43-e/kg)`), Table 4f is printed in grams,
# and Table 3 is printed in kilograms. The commands reconcile the last of those
# at the point of comparison - see .eiod_to_cutoff_unit() in R/utils.R.
#
# Built from the RELATIVE rows, because those are the ones printed in the input
# unit for all seven indicators.
ind <- unique(eiod_cutoffs[eiod_cutoffs$metric == "rel",
                           c("indicator", "indicator_label", "unit")])
ind <- ind[order(match(ind$indicator,
                       c("landtotal", "landarable", "landpasture", "ghg",
                         "eutroph", "water", "biodiv"))), ]
rownames(ind) <- NULL
eiod_indicators <- ind

stopifnot(
  nrow(eiod_indicators) == 7L,
  eiod_indicators$unit[eiod_indicators$indicator == "eutroph"] == "g PO4(3-)eq"
)

# ---- 5. synthetic demonstration data ---------------------------------------- #
# Used in examples, vignettes and tests. NOT real survey data; no prevalence
# computed from it carries any substantive meaning.
#
# THE COLUMN NAMES ARE DELIBERATELY NOT THE INDICATOR KEYS.
#
# Until October 2026 these columns were called `landtotal`, `ghg`, `biodiv` and
# so on - i.e. exactly the strings the `indicator` argument takes. That made the
# examples look tidy:
#
#     for (ind in eiod_indicators$indicator)
#       eiod_absolute_threshold(eiod_demo[[ind]], grp, ind)
#
# and it taught a lie. The loop works only because the columns happen to be
# named after the keys; a user whose biodiversity column is `biodiv_pdf` cannot
# run it at all, and several concluded the package required a rename. It never
# did - reiod takes vectors, so any column name has always worked.
#
# The companion Stata package hit the identical problem with its own demo data
# and was rewritten to use `land_ado`, `cropland_ado`, `ghg_ado`. The same
# correction is applied here: survey-realistic names that carry their unit, so
# every example has to state the mapping explicitly. See eiod_absolute_all().
set.seed(20261001)
n <- 600

eiod_demo <- data.frame(
  id   = seq_len(n),
  age  = round(stats::runif(n, 0.5, 65), 1),
  sex  = factor(sample(c("male", "female"), n, replace = TRUE),
                levels = c("male", "female")),
  land_total_m2yr   = stats::rlnorm(n, log(8),     0.80),
  land_arable_m2yr  = stats::rlnorm(n, log(2.5),   0.70),
  land_pasture_m2yr = stats::rlnorm(n, log(4),     1.00),
  ghg_kgco2e        = stats::rlnorm(n, log(3),     0.70),
  eutroph_kgpo4e    = stats::rlnorm(n, log(0.02),  0.70),
  water_litres      = stats::rlnorm(n, log(600),   0.60),
  biodiv_pdf        = stats::rlnorm(n, log(8e-13), 1.00),
  gdqs              = round(stats::runif(n, 12, 38), 1),
  stringsAsFactors = FALSE
)

# a realistic trace of missingness, so examples show how it propagates
eiod_demo$biodiv_pdf[sample(n, 12)] <- NA
eiod_demo$gdqs[sample(n, 8)]        <- NA

# The canonical mapping from indicator key to demo column, shipped so that
# examples, vignettes and tests all read it from one place rather than each
# retyping it.
eiod_demo_map <- c(
  landtotal   = "land_total_m2yr",
  landarable  = "land_arable_m2yr",
  landpasture = "land_pasture_m2yr",
  ghg         = "ghg_kgco2e",
  eutroph     = "eutroph_kgpo4e",
  water       = "water_litres",
  biodiv      = "biodiv_pdf"
)

stopifnot(
  nrow(eiod_demo) == n,
  is.factor(eiod_demo$sex),
  # the whole point of the rename: no demo column may be named after a key
  !any(names(eiod_demo) %in% names(eiod_demo_map)),
  all(eiod_demo_map %in% names(eiod_demo)),
  identical(names(eiod_demo_map),
            c("landtotal", "landarable", "landpasture", "ghg",
              "eutroph", "water", "biodiv"))
)

# ---- 6. a deliberately broken copy, for the troubleshooting vignette -------- #
# Five faults, one per failure mode the check suite is built to catch.
eiod_broken <- eiod_demo

#  (a) biodiversity read in as character, because two cells are left-censored.
#      as.character(), not format(): format() pads NAs to "  NA" and that extra
#      fault would muddy the demonstration.
eiod_broken$biodiv_pdf <- as.character(eiod_broken$biodiv_pdf)
eiod_broken$biodiv_pdf[c(14, 221)] <- "<1e-14"

#  (b) greenhouse gases supplied in grams rather than kilograms
eiod_broken$ghg_kgco2e <- eiod_broken$ghg_kgco2e * 1000

#  (c) sex coded 0/1 with no labels, so male/female is ambiguous
eiod_broken$sex <- ifelse(eiod_demo$sex == "male", 1L, 0L)

#  (d) water rounded to 4 significant digits, as an Excel re-save would.
#      Deliberately 4 and not 3: signif(x, 3) on values around 600 yields whole
#      numbers, the column then re-reads as integer, and the demonstration
#      becomes a type fault instead of the precision fault intended.
eiod_broken$water_litres <- signif(eiod_broken$water_litres, 4)

#  (e) arable land stored as an integer. as.integer() truncates toward zero -
#      it does not round - so this both destroys the fractional part of every
#      value and manufactures exact zeros out of everything below 1 m2*year.
#      is.numeric(1L) is TRUE, so until October 2026 this passed every guard on
#      the metric path and was caught only if the analyst ran the check suite.
eiod_broken$land_arable_m2yr <- as.integer(eiod_broken$land_arable_m2yr)

utils::write.csv(eiod_broken, "inst/extdata/eiod_broken.csv", row.names = FALSE)

# ---- 7. save ---------------------------------------------------------------- #
save(eiod_cutoffs,    file = "data/eiod_cutoffs.rda",    compress = "xz")
save(eiod_indicators, file = "data/eiod_indicators.rda", compress = "xz")
save(eiod_demo,       file = "data/eiod_demo.rda",       compress = "xz")
save(eiod_demo_map,   file = "data/eiod_demo_map.rda",   compress = "xz")

message("saved: eiod_cutoffs (", nrow(eiod_cutoffs), " rows), ",
        "eiod_indicators (", nrow(eiod_indicators), "), ",
        "eiod_demo (", nrow(eiod_demo), "), ",
        "eiod_demo_map (", length(eiod_demo_map), ")")
message("saved: inst/extdata/eiod_broken.csv")
