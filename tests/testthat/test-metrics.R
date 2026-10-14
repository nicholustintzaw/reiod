# Absolute threshold (Table 3) and relative benchmark (Tables 4a-4g)

abs4 <- unname(eiod_lookup_cutoff("biodiv", 4, "abs"))

test_that("the absolute comparison is strict", {
  # published cut-offs carry a "<" sign: exactly on the threshold is not below
  v <- c(abs4 * (1 - 1e-9), abs4, abs4 * (1 + 1e-9))
  got <- eiod_absolute_threshold(v, rep(4L, 3), "biodiv")
  expect_equal(got, c(1L, 0L, 0L))
})

test_that("missing impacts and groups stay missing", {
  # In R, NA < x is NA, but a careless implementation can turn missing data
  # into an apparent threshold breach. These must be NA, never 0 or band 10.
  v <- c(abs4 / 2, NA, abs4 / 2)
  g <- c(4L, 4L, NA)
  expect_equal(eiod_absolute_threshold(v, g, "biodiv"), c(1L, NA, NA))
  expect_equal(eiod_relative_band(v, g, "biodiv"), c(1L, NA, NA))
})

test_that("every band is reachable for every demographic group", {
  cuts <- lapply(1:8, function(g)
    unname(eiod_lookup_cutoff("biodiv", g, "rel", percentile = 10)))

  for (g in 1:8) {
    p <- vapply(seq(10, 90, 10), function(q)
      unname(eiod_lookup_cutoff("biodiv", g, "rel", percentile = q)), numeric(1))

    # a value inside each of the ten bands
    v <- c(p[1] * 0.5,                       # band 1
           (p[-9] + p[-1]) / 2,              # bands 2-9
           p[9] * 1.5)                       # band 10
    got <- eiod_relative_band(v, rep(g, 10), "biodiv")
    expect_equal(got, 1:10, info = paste("group", g))
  }
})

test_that("a value exactly on a cut-point falls in the higher band", {
  p <- vapply(seq(10, 90, 10), function(q)
    unname(eiod_lookup_cutoff("biodiv", 4, "rel", percentile = q)), numeric(1))
  expect_equal(eiod_relative_band(p[1] * (1 - 1e-9), 4L, "biodiv"), 1L)
  expect_equal(eiod_relative_band(p[1], 4L, "biodiv"), 2L)   # on P10 -> band 2
  expect_equal(eiod_relative_band(p[9], 4L, "biodiv"), 10L)  # on P90 -> band 10
})

test_that("bands are monotone in the impact", {
  g <- rep(4L, 200)
  v <- sort(stats::rlnorm(200, log(8e-13), 1.2))
  b <- eiod_relative_band(v, g, "biodiv")
  expect_true(all(diff(b) >= 0))
})

test_that("midpoint returns the band midpoint percentile", {
  b <- eiod_relative_band(eiod_demo$biodiv_pdf,
                          eiod_age_sex_group(eiod_demo$age, eiod_demo$sex),
                          "biodiv")
  m <- eiod_relative_band(eiod_demo$biodiv_pdf,
                          eiod_age_sex_group(eiod_demo$age, eiod_demo$sex),
                          "biodiv", midpoint = TRUE)
  expect_equal(m, b * 10L - 5L)
})

test_that("all seven indicators run and return sensible shapes", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
  # eiod_demo's columns are NOT named after the indicator keys, so the mapping
  # has to be stated. That is the point of eiod_demo_map.
  for (ind in names(eiod_demo_map)) {
    v <- eiod_demo[[eiod_demo_map[[ind]]]]
    a <- eiod_absolute_threshold(v, grp, ind)
    b <- eiod_relative_band(v, grp, ind)
    expect_length(a, nrow(eiod_demo))
    expect_length(b, nrow(eiod_demo))
    expect_true(all(a %in% c(0L, 1L, NA)))
    expect_true(all(b %in% c(1:10, NA)))
  }
})

test_that("the demo data cannot drift back to the indicator keys", {
  # The rename is the fix for the documentation trap; a future edit that
  # restored `eiod_demo$ghg` would silently restore the trap with it.
  expect_false(any(names(eiod_demo) %in% eiod_indicators$indicator))
  expect_identical(names(eiod_demo_map), eiod_indicators$indicator)
  expect_true(all(eiod_demo_map %in% names(eiod_demo)))
})

test_that("an integer impact vector is refused on the metric path", {
  # is.numeric(1L) is TRUE, so this passed every guard before October 2026.
  # Measured in the companion Stata package: 13% downward bias in mean ghg.
  grp <- rep(4L, 3)
  expect_error(eiod_absolute_threshold(c(1L, 2L, 3L), grp, "ghg"),
               "integer vector")
  expect_error(eiod_relative_band(c(1L, 2L, 3L), grp, "ghg"),
               "integer vector")
  # and the double it was truncated from is accepted
  expect_silent(eiod_absolute_threshold(c(1.4, 2.6, 3.1), grp, "ghg"))
})

test_that("details = TRUE reports the cut-off that was applied", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
  v   <- eiod_demo$biodiv_pdf

  d <- eiod_absolute_threshold(v, grp, "biodiv", details = TRUE)
  expect_s3_class(d, "data.frame")
  expect_named(d, c("value", "group", "cutoff", "below"))
  expect_equal(d$below, eiod_absolute_threshold(v, grp, "biodiv"))
  # the cut-off must be the published one for that group
  ok <- !is.na(d$group)
  expect_equal(d$cutoff[ok],
               as.numeric(eiod_lookup_cutoff("biodiv"))[d$group[ok]])
  # and it must agree with the result it produced
  fin <- ok & !is.na(d$value)
  expect_equal(as.integer(d$value[fin] < d$cutoff[fin]), d$below[fin])

  r <- eiod_relative_band(v, grp, "biodiv", details = TRUE)
  expect_named(r, c("value", "group", "band", "cut_lower", "cut_upper"))
  expect_equal(r$band, eiod_relative_band(v, grp, "biodiv"))
  # band 1 has no published lower bound; band 10 no upper
  expect_true(all(is.na(r$cut_lower[!is.na(r$band) & r$band == 1L])))
  expect_true(all(is.na(r$cut_upper[!is.na(r$band) & r$band == 10L])))
  mid <- which(!is.na(r$band) & r$band > 1L & r$band < 10L)
  expect_false(anyNA(r$cut_lower[mid]))
  expect_false(anyNA(r$cut_upper[mid]))
  # the value must sit inside the band it was given
  known <- which(!is.na(r$cut_lower))
  expect_true(all(r$value[known] >= r$cut_lower[known]))
  known <- which(!is.na(r$cut_upper))
  expect_true(all(r$value[known] < r$cut_upper[known]))

  expect_error(eiod_relative_band(v, grp, "biodiv", midpoint = TRUE,
                                  details = TRUE), "cannot both be TRUE")
})

test_that("the *_all helpers take a map and allow a partial one", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)

  all7 <- eiod_absolute_all(eiod_demo, grp, eiod_demo_map)
  expect_named(all7, paste0("abs_", names(eiod_demo_map)))
  expect_equal(nrow(all7), nrow(eiod_demo))
  expect_equal(all7$abs_ghg,
               eiod_absolute_threshold(eiod_demo$ghg_kgco2e, grp, "ghg"))

  part <- eiod_relative_all(eiod_demo, grp,
                            c(biodiv = "biodiv_pdf", water = "water_litres"))
  expect_named(part, c("band_biodiv", "band_water"))
  expect_equal(part$band_biodiv,
               eiod_relative_band(eiod_demo$biodiv_pdf, grp, "biodiv"))

  expect_error(eiod_absolute_all(eiod_demo, grp, c("ghg_kgco2e")),
               "must be named with an indicator key")
  expect_error(eiod_absolute_all(eiod_demo, grp, c(nope = "ghg_kgco2e")),
               "unknown indicator key")
  expect_error(eiod_absolute_all(eiod_demo, grp, c(ghg = "not_a_column")),
               "not in `data`")
  expect_error(eiod_absolute_all(eiod_demo, grp,
                                 c(ghg = "ghg_kgco2e", ghg = "water_litres")),
               "more than once")
})

test_that("bad arguments are rejected clearly", {
  expect_error(eiod_absolute_threshold(1, 4L, "nope"), "must be one of")
  expect_error(eiod_absolute_threshold(factor("1"), 4L, "ghg"), "factor")
  expect_error(eiod_absolute_threshold("1", 4L, "ghg"), "character")
  expect_error(eiod_absolute_threshold(1, 99L, "ghg"), "outside 1-8")
  expect_error(eiod_absolute_threshold(c(1, 2), 4L, "ghg"), "length")
})

test_that("the absolute threshold sits where expected in the relative scale", {
  # Documented in the vignette and in the Stata companion: for GHG the
  # planetary-boundary threshold lies below the whole reference distribution,
  # and for water above it.
  for (g in 1:8) {
    thr_ghg <- unname(eiod_lookup_cutoff("ghg", g, "abs"))
    p10_ghg <- unname(eiod_lookup_cutoff("ghg", g, "rel", percentile = 10))
    expect_lt(thr_ghg, p10_ghg)

    thr_wat <- unname(eiod_lookup_cutoff("water", g, "abs"))
    p90_wat <- unname(eiod_lookup_cutoff("water", g, "rel", percentile = 90))
    expect_gt(thr_wat, p90_wat)
  }
})
