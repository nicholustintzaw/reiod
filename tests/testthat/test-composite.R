abs4 <- unname(eiod_lookup_cutoff("biodiv", 4, "abs"))
p30  <- unname(eiod_lookup_cutoff("biodiv", 4, "rel", percentile = 30))

test_that("HESD produces the four categories of Table 5a", {
  bio  <- c(abs4 / 2, abs4 / 2, abs4 * 2, abs4 * 2)
  gdqs <- c(30,       10,       30,       10)
  got <- eiod_hesd(bio, gdqs, rep(4L, 4))
  expect_identical(as.integer(got), 1:4)
  expect_identical(levels(got)[1], "Healthy and env. sustainable")
})

test_that("HDLEI produces the four categories of Table 5b", {
  bio  <- c(p30 / 2, p30 / 2, p30 * 50, p30 * 50)
  gdqs <- c(30,      10,      30,       10)
  got <- eiod_hdlei(bio, gdqs, rep(4L, 4))
  expect_identical(as.integer(got), 1:4)
})

test_that("a GDQS of exactly 23 counts as healthy", {
  expect_identical(eiod_healthy_diet(c(22.999, 23, 23.001)), c(0L, 1L, 1L))
})

test_that("the binary form is exactly category 1", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
  suppressMessages({
    cat4 <- eiod_hesd(eiod_demo$biodiv_pdf, eiod_demo$gdqs, grp,
                      form = "category")
    bin  <- eiod_hesd(eiod_demo$biodiv_pdf, eiod_demo$gdqs, grp,
                      form = "binary")
  })
  expect_identical(bin, ifelse(is.na(cat4), NA_integer_,
                               as.integer(as.integer(cat4) == 1L)))
})

test_that("sub-indicators equal the standalone functions", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
  eligible <- !(grp %in% c(1L, 5L))

  suppressMessages({
    h <- eiod_hesd(eiod_demo$biodiv_pdf, eiod_demo$gdqs, grp,
                   form = "components")
    d <- eiod_hdlei(eiod_demo$biodiv_pdf, eiod_demo$gdqs, grp,
                    form = "components")
  })

  standalone_healthy <- eiod_healthy_diet(eiod_demo$gdqs)
  standalone_sust    <- eiod_sustainable_diet(eiod_demo$biodiv_pdf, grp)
  standalone_low     <- eiod_low_impact(eiod_demo$biodiv_pdf, grp)

  expect_identical(h$healthy[eligible], standalone_healthy[eligible])
  expect_identical(h$env[eligible],     standalone_sust[eligible])
  expect_identical(d$env[eligible],     standalone_low[eligible])
  expect_identical(h$healthy, d$healthy)
})

test_that("composites are NA below age 2", {
  grp  <- c(1L, 5L, 2L, 6L)
  bio  <- rep(1e-14, 4)        # comfortably below every cut-off
  gdqs <- rep(30, 4)
  suppressMessages({
    h <- eiod_hesd(bio, gdqs, grp, form = "binary")
    d <- eiod_hdlei(bio, gdqs, grp, form = "binary")
  })
  expect_identical(h, c(NA, NA, 1L, 1L))
  expect_identical(d, c(NA, NA, 1L, 1L))
})

test_that("missing inputs propagate to a missing category", {
  grp <- rep(4L, 3)
  got <- suppressMessages(
    eiod_hesd(c(abs4 / 2, NA, abs4 / 2), c(30, 30, NA), grp,
              form = "binary"))
  expect_identical(got, c(1L, NA, NA))
})

test_that("HDLEI is nested inside HESD", {
  # The relative P30 cut-off is stricter than the absolute threshold in every
  # demographic group, by the same constant factor, so hdlei == 1 must imply
  # hesd == 1. This is structural, not a property of any particular sample.
  for (g in 1:8) {
    a <- unname(eiod_lookup_cutoff("biodiv", g, "abs"))
    r <- unname(eiod_lookup_cutoff("biodiv", g, "rel", percentile = 30))
    expect_lt(r, a)
  }

  # the ratio is the same in all eight groups
  ratios <- vapply(1:8, function(g) {
    unname(eiod_lookup_cutoff("biodiv", g, "abs")) /
      unname(eiod_lookup_cutoff("biodiv", g, "rel", percentile = 30))
  }, numeric(1))
  expect_equal(diff(range(ratios)), 0, tolerance = 1e-9)

  # and it shows up in the data
  set.seed(7)
  n <- 2000
  grp  <- sample(c(2L, 3L, 4L, 6L, 7L, 8L), n, replace = TRUE)
  bio  <- stats::rlnorm(n, log(6e-13), 1.2)
  gdqs <- stats::runif(n, 12, 38)
  suppressMessages({
    h <- eiod_hesd(bio, gdqs, grp, form = "binary")
    d <- eiod_hdlei(bio, gdqs, grp, form = "binary")
  })
  expect_true(all(h[which(d == 1L)] == 1L))
  expect_gte(sum(h, na.rm = TRUE), sum(d, na.rm = TRUE))
})

test_that("a non-default percentile is flagged as a sensitivity analysis", {
  expect_message(eiod_low_impact(rep(1e-13, 2), rep(4L, 2), percentile = 50),
                 "not the published HDLEI criterion")
  expect_silent(eiod_low_impact(rep(1e-13, 2), rep(4L, 2)))
  expect_error(eiod_low_impact(1e-13, 4L, percentile = 35), "multiple of 10")
})

test_that("components form returns all four pieces", {
  grp <- rep(4L, 4)
  x <- suppressMessages(
    eiod_hesd(c(abs4 / 2, abs4 / 2, abs4 * 2, abs4 * 2),
              c(30, 10, 30, 10), grp, form = "components"))
  expect_s3_class(x, "data.frame")
  expect_named(x, c("healthy", "env", "category", "binary"))
  expect_identical(nrow(x), 4L)
})
