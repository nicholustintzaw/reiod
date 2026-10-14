# ---------------------------------------------------------------------------- #
# data-raw/build_data.R
#
# Builds the three datasets shipped with reiof:
#   eiof_cutoffs     616 rows, every published cut-off
#   eiof_indicators    7 rows, indicator names, labels and units
#   eiof_demo        600 rows, synthetic respondent-day data for examples
#
# SOURCE  data-raw/eiof_cutoffs.csv
#         Transcribed programmatically from Tables 3 and 4a-4g of
#         Intake-EIOD-Methods-Paper-Jan2026-Final.pdf (pages 16-19).
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
  "data-raw/eiof_cutoffs.csv",
  stringsAsFactors = FALSE,
  colClasses = c(value_published = "character", scale_to_db_unit = "character")
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
raw$value_published  <- as.numeric(raw$value_published)
raw$scale_to_db_unit <- as.numeric(raw$scale_to_db_unit)
stopifnot(!anyNA(raw$value_published), !anyNA(raw$scale_to_db_unit))

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

# ---- 2. harmonised value ---------------------------------------------------- #
# `value` is what the metric functions compare against. It equals the published
# value except for relative eutrophication, which carries an inferred /1000
# rescaling. See vignette("reiof"), "A caution on eutrophication".
raw$value <- raw$value_published * raw$scale_to_db_unit

eiof_cutoffs <- data.frame(
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
  value_published     = raw$value_published,
  value_published_str = value_published_str,
  scale_to_db_unit    = raw$scale_to_db_unit,
  stringsAsFactors = FALSE
)

eiof_cutoffs <- eiof_cutoffs[
  order(eiof_cutoffs$metric, eiof_cutoffs$indicator,
        eiof_cutoffs$demogroup, eiof_cutoffs$row_order), ]
rownames(eiof_cutoffs) <- NULL

# ---- 3. structural validation ----------------------------------------------- #
# The same checks the Stata build runs. If one fails the CSV is wrong; do not
# relax the check.
stopifnot(
  nrow(eiof_cutoffs) == 616,
  all(eiof_cutoffs$metric %in% c("abs", "rel")),
  sum(eiof_cutoffs$metric == "abs") == 56,     # 7 indicators x 8 groups
  sum(eiof_cutoffs$metric == "rel") == 560,    # 7 x 8 x 10 rows
  length(unique(eiof_cutoffs$indicator)) == 7,
  all(eiof_cutoffs$demogroup %in% 1:8),
  !anyNA(eiof_cutoffs$value),
  all(eiof_cutoffs$value > 0),
  # complete grid, no duplicates
  !anyDuplicated(eiof_cutoffs[c("metric", "indicator", "demogroup", "row_order")]),
  # the shipped text and the shipped double are the same number
  identical(as.numeric(eiof_cutoffs$value_published_str),
            eiof_cutoffs$value_published)
)

# relative rows 1-9 are the P10..P90 cut-points and must be strictly increasing
# within indicator x group; row 10 repeats P90
rel <- eiof_cutoffs[eiof_cutoffs$metric == "rel", ]
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

# the one rescaling is where we think it is, and nowhere else
stopifnot(
  all(eiof_cutoffs$scale_to_db_unit[
    !(eiof_cutoffs$metric == "rel" & eiof_cutoffs$indicator == "eutroph")] == 1),
  sum(eiof_cutoffs$scale_to_db_unit != 1) == 80   # 8 groups x 10 rows
)

# spot-checks against values hand-typed from the printed tables
stopifnot(
  eiof_cutoffs$value_published[eiof_cutoffs$metric == "abs" &
    eiof_cutoffs$indicator == "biodiv" & eiof_cutoffs$demogroup == 4] ==
    1.2844358718e-12,
  eiof_cutoffs$value_published[eiof_cutoffs$metric == "abs" &
    eiof_cutoffs$indicator == "water" & eiof_cutoffs$demogroup == 8] ==
    1726.3821057877,
  eiof_cutoffs$value_published[eiof_cutoffs$metric == "rel" &
    eiof_cutoffs$indicator == "landtotal" & eiof_cutoffs$demogroup == 4 &
    !is.na(eiof_cutoffs$percentile) & eiof_cutoffs$percentile == 50] ==
    15.4981270626
)

message("eiof_cutoffs: all structural checks passed")

# ---- 4. indicator lookup ---------------------------------------------------- #
ind <- unique(eiof_cutoffs[c("indicator", "indicator_label", "unit")])
ind <- ind[order(match(ind$indicator,
                       c("landtotal", "landarable", "landpasture", "ghg",
                         "eutroph", "water", "biodiv"))), ]
rownames(ind) <- NULL
eiof_indicators <- ind

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
#     for (ind in eiof_indicators$indicator)
#       eiof_absolute_threshold(eiof_demo[[ind]], grp, ind)
#
# and it taught a lie. The loop works only because the columns happen to be
# named after the keys; a user whose biodiversity column is `biodiv_pdf` cannot
# run it at all, and several concluded the package required a rename. It never
# did - reiof takes vectors, so any column name has always worked.
#
# The companion Stata package hit the identical problem with its own demo data
# and was rewritten to use `land_ado`, `cropland_ado`, `ghg_ado`. The same
# correction is applied here: survey-realistic names that carry their unit, so
# every example has to state the mapping explicitly. See eiof_absolute_all().
set.seed(20261001)
n <- 600

eiof_demo <- data.frame(
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
eiof_demo$biodiv_pdf[sample(n, 12)] <- NA
eiof_demo$gdqs[sample(n, 8)]        <- NA

# The canonical mapping from indicator key to demo column, shipped so that
# examples, vignettes and tests all read it from one place rather than each
# retyping it.
eiof_demo_map <- c(
  landtotal   = "land_total_m2yr",
  landarable  = "land_arable_m2yr",
  landpasture = "land_pasture_m2yr",
  ghg         = "ghg_kgco2e",
  eutroph     = "eutroph_kgpo4e",
  water       = "water_litres",
  biodiv      = "biodiv_pdf"
)

stopifnot(
  nrow(eiof_demo) == n,
  is.factor(eiof_demo$sex),
  # the whole point of the rename: no demo column may be named after a key
  !any(names(eiof_demo) %in% names(eiof_demo_map)),
  all(eiof_demo_map %in% names(eiof_demo)),
  identical(names(eiof_demo_map),
            c("landtotal", "landarable", "landpasture", "ghg",
              "eutroph", "water", "biodiv"))
)

# ---- 6. a deliberately broken copy, for the troubleshooting vignette -------- #
# Five faults, one per failure mode the check suite is built to catch.
eiof_broken <- eiof_demo

#  (a) biodiversity read in as character, because two cells are left-censored.
#      as.character(), not format(): format() pads NAs to "  NA" and that extra
#      fault would muddy the demonstration.
eiof_broken$biodiv_pdf <- as.character(eiof_broken$biodiv_pdf)
eiof_broken$biodiv_pdf[c(14, 221)] <- "<1e-14"

#  (b) greenhouse gases supplied in grams rather than kilograms
eiof_broken$ghg_kgco2e <- eiof_broken$ghg_kgco2e * 1000

#  (c) sex coded 0/1 with no labels, so male/female is ambiguous
eiof_broken$sex <- ifelse(eiof_demo$sex == "male", 1L, 0L)

#  (d) water rounded to 4 significant digits, as an Excel re-save would.
#      Deliberately 4 and not 3: signif(x, 3) on values around 600 yields whole
#      numbers, the column then re-reads as integer, and the demonstration
#      becomes a type fault instead of the precision fault intended.
eiof_broken$water_litres <- signif(eiof_broken$water_litres, 4)

#  (e) arable land stored as an integer. as.integer() truncates toward zero -
#      it does not round - so this both destroys the fractional part of every
#      value and manufactures exact zeros out of everything below 1 m2*year.
#      is.numeric(1L) is TRUE, so until October 2026 this passed every guard on
#      the metric path and was caught only if the analyst ran the check suite.
eiof_broken$land_arable_m2yr <- as.integer(eiof_broken$land_arable_m2yr)

utils::write.csv(eiof_broken, "inst/extdata/eiof_broken.csv", row.names = FALSE)

# ---- 7. save ---------------------------------------------------------------- #
save(eiof_cutoffs,    file = "data/eiof_cutoffs.rda",    compress = "xz")
save(eiof_indicators, file = "data/eiof_indicators.rda", compress = "xz")
save(eiof_demo,       file = "data/eiof_demo.rda",       compress = "xz")
save(eiof_demo_map,   file = "data/eiof_demo_map.rda",   compress = "xz")

message("saved: eiof_cutoffs (", nrow(eiof_cutoffs), " rows), ",
        "eiof_indicators (", nrow(eiof_indicators), "), ",
        "eiof_demo (", nrow(eiof_demo), "), ",
        "eiof_demo_map (", length(eiof_demo_map), ")")
message("saved: inst/extdata/eiof_broken.csv")
