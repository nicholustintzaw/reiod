# Values hand-typed from the printed tables, as an independent check on the
# programmatic transcription in data-raw/.
#
# Published biodiversity cut-offs are retained to all reported significant
# digits. Because decimal fractions are not generally exactly representable
# as IEEE-754 binary64 values, bit-for-bit identical() comparisons may differ
# across platforms by one or a few machine-level steps.
#
# For biodiversity, tests therefore verify:
#   1. exact agreement at all published significant digits; and
#   2. agreement at near-machine precision for the underlying numeric value.
#
# No rounding is applied to the package data.

test_that("the cut-off dataset has the expected shape", {
  expect_identical(nrow(eiod_cutoffs), 616L)
  expect_identical(sum(eiod_cutoffs$metric == "abs"), 56L)
  expect_identical(sum(eiod_cutoffs$metric == "rel"), 560L)
  expect_length(unique(eiod_cutoffs$indicator), 7L)
  expect_true(all(eiod_cutoffs$demogroup %in% 1:8))
  expect_false(anyNA(eiod_cutoffs$value))
  expect_true(all(eiod_cutoffs$value > 0))
})

abs_val <- function(ind, g) {
  eiod_cutoffs$value[eiod_cutoffs$metric == "abs" &
    eiod_cutoffs$indicator == ind & eiod_cutoffs$demogroup == g]
}
rel_val <- function(ind, g, p) {
  eiod_cutoffs$value[eiod_cutoffs$metric == "rel" &
    eiod_cutoffs$indicator == ind & eiod_cutoffs$demogroup == g &
    !is.na(eiod_cutoffs$percentile) & eiod_cutoffs$percentile == p]
}


# Compare biodiversity values at both:
#   1. the exact precision published in the source tables, and
#   2. near-machine precision in their binary double representation.
#
# Biodiversity values are ~1e-13. Decimal values are generally not exactly
# representable as IEEE-754 binary64 numbers, so bit-for-bit identity can
# differ by one or a few machine-level steps across platforms even when all
# published decimal digits are preserved.

expect_published_biodiv <- function(actual,
                                    expected_text,
                                    sig_digits = 11L,
                                    eps_factor = 8) {

  expect_length(actual, 1L)
  expect_false(is.na(actual))

  # Check 1: preserve every digit reported in the published table.
  actual_text <- sprintf(
    paste0("%.", sig_digits - 1L, "e"),
    actual
  )

  expect_identical(actual_text, expected_text)

  # Check 2: require the underlying numeric value to remain extremely close
  # at machine precision. This guards against a value that merely rounds to
  # the same printed 11 significant digits but is numerically different.
  expected_num <- as.numeric(expected_text)

  rel_error <- abs(actual - expected_num) / abs(expected_num)
  tolerance <- eps_factor * .Machine$double.eps

  expect_true(
    rel_error <= tolerance,
    info = sprintf(
      "Relative error %.3e exceeds machine-level tolerance %.3e",
      rel_error,
      tolerance
    )
  )
}

# The expect_identical() calls below are safe, but it is worth knowing WHY,
# because the reason is not "identical() is fine here".
#
# Each compares a double parsed from the CSV on the BUILD machine against a
# literal parsed by R on the TEST machine - the same two-parsers-two-platforms
# structure that broke on macOS arm64 (see the note further down). They survive
# it only because every value here has a small decimal exponent, and the
# conversion is exact on every platform for those. Biodiversity is the one
# indicator where it is not, and every biodiversity value in this file goes
# through expect_published_biodiv() instead.
#
# So: do NOT add a biodiversity value to these blocks as a bare
# expect_identical(). Use the helper.

test_that("Table 3 values match the printed table exactly", {
  expect_identical(abs_val("landtotal",   1), 4.0898629907)
  expect_identical(abs_val("landarable",  4), 5.5735931918)
  expect_identical(abs_val("landpasture", 8), 6.9692717624)
  expect_identical(abs_val("ghg",         6), 0.8845537944)
  # NOT 0.0267453228 — that is the figure the PDF prints, in kilograms. Intake
  # corrected the Table 3 eutrophication row to grams in October 2026; see the
  # dedicated test below.
  expect_equal(abs_val("eutroph",         4), 26.745322780673799)
  expect_identical(abs_val("water",       8), 1726.3821057877)
  expect_published_biodiv(
    abs_val("biodiv", 4),
    "1.2844358718e-12"
  )

  expect_published_biodiv(
    abs_val("biodiv", 1),
    "3.6896027444e-13"
  )
})

test_that("Tables 4a-4g values match the printed tables exactly", {
  expect_identical(rel_val("landtotal",   1, 10),  1.1645159358)
  expect_identical(rel_val("landtotal",   4, 50), 15.4981270626)
  expect_identical(rel_val("landtotal",   8, 90), 30.1963086516)
  expect_identical(rel_val("landarable",  1, 10),  1.1010661656)
  expect_identical(rel_val("landarable",  6, 50),  2.2621082746)
  expect_identical(rel_val("landpasture", 1, 10),  0.0634497703)
  expect_identical(rel_val("landpasture", 8, 90), 23.2607981018)
  expect_identical(rel_val("ghg",         1, 10),  0.8921758398)
  expect_identical(rel_val("ghg",         4, 10),  3.1058700138)
  expect_identical(rel_val("water",       7, 80), 819.3029666619)
  expect_identical(rel_val("water",       1, 10), 213.1623613755)
  expect_published_biodiv(
    rel_val("biodiv", 1, 10),
    "2.0227051058e-13"
  )

  expect_published_biodiv(
    rel_val("biodiv", 2, 30),
    "3.7599901323e-13"
  )

  expect_published_biodiv(
    rel_val("biodiv", 8, 30),
    "6.7861513180e-13"
  )
})

test_that("relative eutrophication carries the documented rescaling", {
  # THE STORED VALUE IS THE PRINTED VALUE. Before October 2026 this row was
  # shipped pre-divided by 1000; it is not any more, and must never be again.
  expect_identical(rel_val("eutroph", 2, 20), 8.3451357297)

  # no rescaling column survives, and no value differs from its printed text
  expect_false("scale_to_db_unit" %in% names(eiod_cutoffs))
  # expect_equal() on purpose: build-machine doubles vs test-machine parse,
  # the structure that failed on macOS arm64 (see expect_published_biodiv()).
  # nolint start: expect_identical_linter.
  expect_equal(eiod_cutoffs$value,
               as.numeric(eiod_cutoffs$value_published_str))
  # nolint end
})

test_that("every indicator now uses one unit across both tables", {
  # Eutrophication was the exception until Intake's October 2026 correction.
  # If this fails again, the reference CSV has regressed.
  for (ind in unique(eiod_cutoffs$indicator)) {
    expect_length(unique(eiod_cutoffs$unit[eiod_cutoffs$indicator == ind]), 1L)
  }
  expect_true(all(eiod_cutoffs$unit[eiod_cutoffs$indicator == "eutroph"] ==
                  "g PO4(3-)eq"))
  expect_identical(eiod_indicators$unit[eiod_indicators$indicator == "eutroph"],
                   "g PO4(3-)eq")
})

test_that("the corrected Table 3 eutrophication thresholds are shipped", {
  # Intake confirmed by email (October 2026) that Tables 3 and 4f are both in
  # grams, and supplied corrected Table 3 values. These EIGHT rows are the only
  # ones in the dataset that do not match the currently published PDF.
  expect_true("value_source" %in% names(eiod_cutoffs))
  expect_identical(sum(eiod_cutoffs$value_source != "published"), 8L)

  corrected <- eiod_cutoffs[eiod_cutoffs$indicator == "eutroph" &
                            eiod_cutoffs$metric == "abs", ]
  corrected <- corrected[order(corrected$demogroup), ]
  expect_true(all(corrected$value_source == "intake correction 2026-10"))
  # expect_equal() on purpose: build-machine doubles vs test-machine literals.
  # Exactness is enforced by the round-trip guard in data-raw/build_data.R.
  # nolint start: expect_identical_linter.
  expect_equal(corrected$value,
               c(7.6827203674384066, 11.919876448673117, 16.415829847434384,
                 26.745322780673799, 7.4439228426109629, 11.039885569912013,
                 15.071843778053791, 21.51337701058506))
  # nolint end

  # The correction is a change of UNIT, not of quantity: each value divided by
  # 1000 reproduces what the PDF prints, to the 10 decimals it prints.
  published_kg <- c(0.0076827204, 0.0119198764, 0.0164158298, 0.0267453228,
                    0.0074439228, 0.0110398856, 0.0150718438, 0.0215133770)
  expect_identical(sprintf("%.10f", corrected$value / 1000),
                   sprintf("%.10f", published_kg))
})

test_that("no indicator is converted on the way in any more", {
  # The g -> kg conversion that eutrophication needed between July and
  # October 2026 is gone. Nothing is announced, and the comparison is direct.
  thr <- as.numeric(eiod_lookup_cutoff("eutroph", 4, "abs"))
  v <- c(thr * 0.5, thr * (1 - 1e-9), thr, thr * 2)

  got <- expect_silent(eiod_absolute_threshold(v, rep(4L, 4), "eutroph"))
  expect_identical(got, c(1L, 1L, 0L, 0L))
  expect_identical(got, as.integer(v < thr))

  expect_silent(eiod_absolute_threshold(c(1, 2), rep(4L, 2), "ghg"))
  expect_silent(eiod_relative_band(v, rep(4L, 4), "eutroph"))
})

test_that("the correction leaves every realistic classification unchanged", {
  # Old behaviour: divide the user's grams by 1000, compare with the PDF's kg.
  # New behaviour: compare grams directly with the corrected gram thresholds.
  # These agree everywhere except within ~1 ULP of a cut-off, where the new
  # path is the more exact of the two because it does not divide first.
  published_kg <- c(0.0076827204, 0.0119198764, 0.0164158298, 0.0267453228,
                    0.0074439228, 0.0110398856, 0.0150718438, 0.0215133770)
  set.seed(42)
  v <- c(eiod_demo$eutroph_gpo4e, stats::rlnorm(5000, log(20), 1))
  g <- c(eiod_age_sex_group(eiod_demo$age, eiod_demo$sex),
         sample(1:8, 5000, replace = TRUE))

  new <- eiod_absolute_threshold(v, g, "eutroph")
  old <- rep(NA_integer_, length(v))
  for (k in 1:8) {
    i <- which(g == k & !is.na(v))
    old[i] <- as.integer(v[i] / 1000 < published_kg[k])
  }
  expect_identical(new, old)
})

test_that("the relative metric leaves eutrophication alone", {
  # Table 4f is already in grams, so a gram input needs no conversion
  p <- vapply(seq(10, 90, 10), function(q)
    as.numeric(eiod_lookup_cutoff("eutroph", 4, "rel", q)), numeric(1))
  v <- c(p[1] * 0.5, (p[-9] + p[-1]) / 2, p[9] * 1.5)
  expect_identical(eiod_relative_band(v, rep(4L, 10), "eutroph"), 1:10)
})

test_that("details = TRUE has the same four columns for every indicator", {
  # The extra `value_kg` column existed only while eutrophication needed
  # converting. With Intake's corrected thresholds there is nothing to show.
  v <- c(30, 20)
  d <- eiod_absolute_threshold(v, c(4L, 4L), "eutroph", details = TRUE)
  expect_named(d, c("value", "group", "cutoff", "below"))
  expect_identical(d$value, v)
  # same stored value on both sides; the literal is checked in the Table 3 test
  expect_identical(d$cutoff, rep(abs_val("eutroph", 4), 2))
  expect_identical(d$below, c(0L, 1L))
  expect_null(attr(d, "conversion"))

  d2 <- eiod_absolute_threshold(c(1, 2), c(4L, 4L), "ghg", details = TRUE)
  expect_named(d2, c("value", "group", "cutoff", "below"))
})

test_that("relative cut-points are strictly increasing, row 10 repeats P90", {
  rel <- eiod_cutoffs[eiod_cutoffs$metric == "rel", ]
  series <- split(rel, list(rel$indicator, rel$demogroup), drop = TRUE)
  expect_length(series, 56L)
  for (s in series) {
    s <- s[order(s$row_order), ]
    expect_identical(nrow(s), 10L)
    expect_true(all(diff(s$value[1:9]) > 0))
    expect_identical(s$value[10], s$value[9])
  }
})

test_that("Table 5 biodiversity cut-offs preserve published precision", {

  # Table 5a prints the ABSOLUTE biodiversity threshold
  expect_published_biodiv(
    abs_val("biodiv", 2),
    "5.7244838747e-13"
  )

  expect_published_biodiv(
    abs_val("biodiv", 3),
    "7.8836516181e-13"
  )

  expect_published_biodiv(
    abs_val("biodiv", 6),
    "5.3018709712e-13"
  )

  expect_published_biodiv(
    abs_val("biodiv", 8),
    "1.0331732910e-12"
  )

  # Table 5b prints the 30th-percentile RELATIVE benchmark
  expect_published_biodiv(
    rel_val("biodiv", 3, 30),
    "5.1781877527e-13"
  )

  expect_published_biodiv(
    rel_val("biodiv", 4, 30),
    "8.4365094030e-13"
  )

  expect_published_biodiv(
    rel_val("biodiv", 6, 30),
    "3.4824069682e-13"
  )

  expect_published_biodiv(
    rel_val("biodiv", 7, 30),
    "4.7542425566e-13"
  )
})


test_that("eiod_lookup_cutoff returns the published values", {
  expect_published_biodiv(
    unname(
      eiod_lookup_cutoff(
        "biodiv",
        4,
        "abs",
        published = TRUE
      )
    ),
    "1.2844358718e-12"
  )

  expect_published_biodiv(
    unname(
      eiod_lookup_cutoff(
        "biodiv",
        4,
        "rel",
        30,
        published = TRUE
      )
    ),
    "8.4365094030e-13"
  )
  expect_length(eiod_lookup_cutoff("ghg", metric = "abs"), 8L)
  expect_error(eiod_lookup_cutoff("ghg", metric = "rel"),
               "percentile.*required")
  expect_error(eiod_lookup_cutoff("nonsense", metric = "abs"), "must be one of")
})


test_that("the literal published text ships", {
  expect_true("value_published_str" %in% names(eiod_cutoffs))
  expect_type(eiod_cutoffs$value_published_str, "character")
  expect_false(anyNA(eiod_cutoffs$value_published_str))

  # a value needing 14 significant digits, compared as TEXT rather than as a
  # rendering of a double
  s <- eiod_cutoffs$value_published_str[eiod_cutoffs$metric == "abs" &
    eiod_cutoffs$indicator == "water" & eiod_cutoffs$demogroup == 8]
  expect_identical(s, "1726.3821057877")
})

# The invariant that actually matters, and the only one that is portable.
#
# An earlier version of this file asserted
#   identical(as.numeric(value_published_str), value_published)
# and it FAILED ON macOS arm64 while passing on Windows and three Linux builds.
# The failure was real but harmless, and the reason is worth recording so the
# assertion is not tightened back:
#
#   `value_published` is parsed once, on the machine that runs
#   data-raw/build_data.R, and frozen into the shipped .rda. The test above
#   re-parsed the same decimal string on the TEST machine. Decimal-to-binary
#   conversion of a value needing a large decimal exponent is not bit-identical
#   across platforms - R scales by a computed power of ten rather than using a
#   correctly-rounded conversion, and that chain rounds differently on arm64
#   than on x86-64.
#
# The evidence that it is confined to exactly that cause:
#
#   * all 16 disagreements on macOS were BIODIVERSITY values, and biodiversity
#     is the only indicator whose 88 cut-offs all need |exponent| >= 10. Every
#     one of the other 528 rows agreed bit for bit.
#   * every disagreement was ONE unit in the last place, ~2.2e-16 relative.
#
# And the evidence that it cannot change a result: nudging every demo value by
# +/-2 ULP across all seven indicators changed 0 of 8,400 classifications. The
# package's own proximity check uses a default tolerance of 1e-6, which is 4.5
# BILLION times wider than the disagreement being discussed here.
#
# So the right assertions are: (a) the shipped double reproduces its published
# digits - which is what "no precision was lost" actually means, and is true on
# every platform; and (b) a re-parse agrees to within a few ULP, not exactly.

test_that("every shipped double reproduces its published digits", {
  # This is the portable form of the round-trip guard in data-raw/build_data.R.
  nd <- vapply(eiod_cutoffs$value_published_str, function(txt) {
    d <- sub("[eE].*$", "", txt)
    d <- gsub("[-.]", "", d)
    d <- sub("^0+", "", d)
    nchar(sub("0+$", "", d))
  }, integer(1), USE.NAMES = FALSE)

  back <- mapply(function(num, n)
    sprintf(paste0("%.", max(n - 1L, 0L), "e"), num),
    eiod_cutoffs$value, nd)

  # expect_equal() on purpose: build-machine doubles vs test-machine parse.
  # nolint start: expect_identical_linter.
  expect_equal(as.numeric(back),
               as.numeric(eiod_cutoffs$value_published_str))
  # nolint end

  # 14 across the values transcribed from the PDF; the eight Intake-corrected
  # eutrophication thresholds were supplied at full double precision and need
  # more.
  expect_identical(max(nd[eiod_cutoffs$value_source == "published"]), 14L)
  expect_lte(max(nd), 17L)
})

test_that("re-parsing the published text agrees to within a few ULP", {
  reparsed <- as.numeric(eiod_cutoffs$value_published_str)
  rel <- abs(reparsed - eiod_cutoffs$value) /
    abs(eiod_cutoffs$value)

  # deliberately NOT identical(): see the note above. 8 ULP is the same
  # allowance expect_published_biodiv() uses, and the largest difference ever
  # observed in CI was 1.
  expect_lte(max(rel), 8 * .Machine$double.eps)

  # and nothing may disagree by enough to matter: the proximity check's default
  # tolerance is 1e-6
  expect_lt(max(rel), 1e-12)
})

test_that("eiod_lookup_cutoff prints every published digit", {
  x <- eiod_lookup_cutoff("water", group = 8, metric = "abs")
  expect_s3_class(x, "eiod_cutoff")

  out <- paste(utils::capture.output(print(x)), collapse = " ")
  expect_match(out, "1726.3821057877", fixed = TRUE)

  # R's default options(digits = 7) would have truncated it, which is the whole
  # reason for the print method. c() drops the class and the metadata but keeps
  # the names, so this is what the bare vector would have shown.
  bare <- paste(utils::capture.output(print(c(x))), collapse = " ")
  expect_false(grepl("1726.3821057877", bare, fixed = TRUE))
  expect_match(bare, "1726.382", fixed = TRUE)

  # the class must not leak into arithmetic or subsetting
  expect_false(inherits(x * 2, "eiod_cutoff"))
  expect_false(inherits(x[1], "eiod_cutoff"))
  expect_false(inherits(c(x, 1), "eiod_cutoff"))
  expect_type(as.numeric(x), "double")
  expect_equal(unname(as.numeric(x)), 1726.3821057877)
})

test_that("eutrophication cut-offs print exactly as the paper has them", {
  x <- eiod_lookup_cutoff("eutroph", metric = "rel", percentile = 20)
  out <- paste(utils::capture.output(print(x)), collapse = " ")
  expect_match(out, "as printed")
  expect_match(out, "8.3451357297", fixed = TRUE)
  expect_equal(unname(as.numeric(x))[2], 8.3451357297)   # NOT 0.00834...

  # `published` is retained but no longer does anything
  y <- eiod_lookup_cutoff("eutroph", metric = "rel", percentile = 20,
                          published = TRUE)
  expect_identical(as.numeric(y), as.numeric(x))

  # Table 3 is now in grams too, and carries the corrected value
  z <- eiod_lookup_cutoff("eutroph", group = 4, metric = "abs")
  zout <- paste(utils::capture.output(print(z)), collapse = " ")
  expect_equal(unname(as.numeric(z)), 26.745322780673799)
  expect_match(zout, "g PO4(3-)eq", fixed = TRUE)
  expect_false(grepl("kg PO4(3-)eq", zout, fixed = TRUE))

  # and the print method flags that these eight rows differ from the PDF
  expect_match(zout, "CORRECTED BY INTAKE")
  expect_match(zout, "DIFFER FROM THE CURRENTLY PUBLISHED PDF")
})


# ---------------------------------------------------------------------------- #
# The demo data must be on the same scale as the cut-offs it is demonstrated
# against.
#
# This exists because of a real failure. When Intake's October 2026 correction
# removed the g -> kg conversion, `eiod_demo$eutroph_kgpo4e` was left holding
# kilograms and `eiod_demo_map` went on pointing `eutroph` at it. Nothing
# errored. `eiod_absolute_all(eiod_demo, grp, eiod_demo_map)` simply returned
# 100% below threshold, and the relative metric put every respondent in band 1
# - the package's own demo quietly demonstrating the 1000x mistake its
# breaking-change note warns about.
#
# Scale is asserted, not balance. Water legitimately sits ~95% below its
# threshold on this data; tightening until that failed would mean tuning the
# simulation to please the test.
# ---------------------------------------------------------------------------- #
test_that("every demo column is on its indicator's scale", {
  for (ind in names(eiod_demo_map)) {
    col   <- eiod_demo_map[[ind]]
    thr   <- median(eiod_cutoffs$value[eiod_cutoffs$metric == "abs" &
                                         eiod_cutoffs$indicator == ind])
    ratio <- median(eiod_demo[[col]], na.rm = TRUE) / thr
    expect_gt(ratio, 0.05, label = paste0(col, " / ", ind, " threshold"))
    expect_lt(ratio, 20,   label = paste0(col, " / ", ind, " threshold"))
  }
})

test_that("the shipped map produces no degenerate indicator", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)

  abs_p <- colMeans(eiod_absolute_all(eiod_demo, grp, eiod_demo_map),
                    na.rm = TRUE)
  # 0 or 1 everywhere means the column and the cut-off are not comparable
  expect_true(all(abs_p > 0 & abs_p < 1),
              info = paste(names(abs_p), round(abs_p, 3), collapse = "; "))

  bands <- eiod_relative_all(eiod_demo, grp, eiod_demo_map)
  expect_true(all(vapply(bands, function(b) length(unique(b[!is.na(b)])) > 1L,
                         logical(1))),
              info = "an indicator put every respondent in one band")
})

test_that("eutrophication demo data is in grams, named for it", {
  expect_true("eutroph_gpo4e" %in% names(eiod_demo))
  expect_false("eutroph_kgpo4e" %in% names(eiod_demo))
  expect_identical(unname(eiod_demo_map[["eutroph"]]), "eutroph_gpo4e")

  # grams: the median must land inside the Table 3 range, 7.4 to 26.7 g
  expect_gt(median(eiod_demo$eutroph_gpo4e), 7)
  expect_lt(median(eiod_demo$eutroph_gpo4e), 30)
})
