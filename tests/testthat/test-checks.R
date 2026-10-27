has_level <- function(report, lvl, check = NULL) {
  ok <- as.character(report$level) == lvl
  if (!is.null(check)) ok <- ok & report$check == check
  any(ok)
}

test_that("clean data produces no errors", {
  rep <- eiod_check_data(eiod_demo,
                         impacts = c(biodiv = "biodiv_pdf", ghg = "ghg_kgco2e"),
                         age = "age", sex = "sex", gdqs = "gdqs")
  expect_s3_class(rep, "eiod_check")
  expect_false(has_level(rep, "error"))
  expect_true(summary(rep)$pass)
})

test_that("the three silent import failures are all caught as errors", {
  # a factor column: as.numeric() would return level codes, not values
  r <- eiod_check_impact(factor(c("3.7e-13", "5.2e-13")), name = "biodiv")
  expect_true(has_level(r, "error", "type"))
  expect_match(r$message[1], "factor")

  # a character column with a left-censored value
  r <- eiod_check_impact(c("1e-13", "<0.001", "2e-13"), name = "biodiv")
  expect_true(has_level(r, "error", "type"))
  expect_match(r$message[1], "will not convert")

  # an integer column cannot hold a small impact at all
  r <- eiod_check_impact(c(1L, 2L, 3L), name = "biodiv")
  expect_true(has_level(r, "error", "type"))
  expect_match(r$message[1], "integer")
})

test_that("implausible values are flagged", {
  expect_true(has_level(eiod_check_impact(c(-1, 2, 3)), "error", "negative"))
  expect_true(has_level(eiod_check_impact(c(0, 2, 3)), "warning", "zero"))
  expect_true(has_level(eiod_check_impact(c(Inf, 2)), "error", "finite"))
  expect_true(has_level(eiod_check_impact(c(NA_real_, NA_real_)),
                        "error", "missing"))
  expect_true(has_level(eiod_check_impact(c(NA, 1, 2)), "note", "missing"))
})

test_that("the precision detector separates storage classes", {
  set.seed(11)
  good <- stats::rlnorm(400, log(8e-13), 1)

  r_good <- eiod_check_precision(good, name = "x")
  expect_false(has_level(r_good, "warning", "precision"))

  # a single-precision round trip retains exactly 7 significant digits
  r_f7 <- eiod_check_precision(signif(good, 7), name = "x")
  expect_true(has_level(r_f7, "warning", "precision"))
  expect_match(r_f7$message[r_f7$check == "precision"][1],
               "at most 7 significant digits")

  # an Excel three-digit re-save is worse again
  r_e3 <- eiod_check_precision(signif(good, 3), name = "x")
  expect_true(has_level(r_e3, "warning", "precision"))
})

test_that("cut-off proximity reports the rows that could flip", {
  thr <- unname(eiod_lookup_cutoff("biodiv", 4, "abs"))
  v <- c(thr * (1 + 1e-9), 1e-14, 1e-11)     # first sits on the cut-off
  r <- eiod_check_precision(v, rep(4L, 3), "biodiv", name = "biodiv")
  expect_true(has_level(r, "warning", "proximity"))
  expect_equal(r$n[r$check == "proximity"], 1L)

  # comfortably clear of it, so no warning
  r2 <- eiod_check_precision(c(1e-14, 1e-11), rep(4L, 2), "biodiv")
  expect_false(has_level(r2, "warning", "proximity"))
  expect_true(has_level(r2, "note", "proximity"))

  # without group and indicator the check is skipped, and says so
  r3 <- eiod_check_precision(v, name = "biodiv")
  expect_match(r3$message[r3$check == "proximity"], "not checked")
})

test_that("the magnitude check names a unit error", {
  grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)

  ok <- eiod_check_magnitude(eiod_demo$ghg_kgco2e, "ghg", grp, name = "ghg")
  expect_false(has_level(ok, "warning"))

  # the same data in grams
  bad <- eiod_check_magnitude(eiod_demo$ghg_kgco2e * 1000, "ghg", grp, name = "ghg")
  expect_true(has_level(bad, "warning", "magnitude"))
  expect_match(bad$message[1], "g <-> kg")

  # litres given as cubic metres
  badw <- eiod_check_magnitude(eiod_demo$water_litres / 1000, "water", grp)
  expect_true(has_level(badw, "warning", "magnitude"))
})

test_that("demographic checks report rather than stop", {
  # numeric sex with no codes: eiod_age_sex_group() errors, the check reports
  r <- eiod_check_demographics(eiod_demo$age,
                               ifelse(eiod_demo$sex == "male", 1L, 0L))
  expect_s3_class(r, "eiod_check")
  expect_true(has_level(r, "error", "sex"))
  # the finding carries the full count and the underlying error message
  i <- as.character(r$level) == "error" & r$check == "sex"
  expect_identical(r$n[i], nrow(eiod_demo))
  expect_match(r$message[i], "cannot tell which code means male", fixed = TRUE)

  # a factor is noted as the recommended type
  r2 <- eiod_check_demographics(eiod_demo$age, eiod_demo$sex)
  expect_false(has_level(r2, "error"))
  expect_match(paste(r2$message, collapse = " "), "recommended input type")

  # under-twos are counted, because they change the composite denominator
  expect_match(paste(r2$message, collapse = " "), "under 2 years")

  # age in months mistaken for years
  r3 <- eiod_check_demographics(eiod_demo$age * 12, eiod_demo$sex)
  expect_true(has_level(r3, "warning"))
})

test_that("GDQS checks catch the common mistakes", {
  expect_false(has_level(eiod_check_gdqs(eiod_demo$gdqs), "error"))
  expect_true(has_level(eiod_check_gdqs(c(10, 60)), "error", "range"))
  expect_true(has_level(eiod_check_gdqs(c(0.3, 0.7)), "warning", "range"))
  expect_true(has_level(eiod_check_gdqs(factor("20")), "error", "type"))
})

test_that("eiod_check_data catches every planted fault in the broken file", {
  path <- system.file("extdata", "eiod_broken.csv", package = "reiod")
  skip_if(path == "", "broken example file not installed")
  broken <- utils::read.csv(path, stringsAsFactors = FALSE)

  rep <- eiod_check_data(broken,
                         impacts = c(biodiv = "biodiv_pdf",
                                     ghg = "ghg_kgco2e",
                                     water = "water_litres",
                                     landarable = "land_arable_m2yr"),
                         age = "age", sex = "sex", gdqs = "gdqs")

  expect_true(summary(rep)$n_error > 0)
  expect_false(summary(rep)$pass)

  msgs <- paste(rep$message, collapse = " | ")
  expect_match(msgs, "character")      # biodiv imported as text
  expect_match(msgs, "cannot tell which code means male")   # sex 0/1
  expect_match(msgs, "column is integer")                   # arable land
})

test_that("missing columns are reported, not silently skipped", {
  rep <- eiod_check_data(eiod_demo, impacts = c(biodiv = "no_such_column"))
  expect_true(has_level(rep, "error", "structure"))
})

test_that("an unknown indicator name is rejected", {
  expect_error(eiod_check_data(eiod_demo, impacts = c(wrong = "biodiv_pdf")),
               "unknown indicator")
  expect_error(eiod_check_data(eiod_demo, impacts = c("biodiv_pdf")),
               "NAMED character vector")
})

test_that("the report prints and summarises", {
  rep <- eiod_check_data(eiod_demo, impacts = c(ghg = "ghg_kgco2e"),
                         age = "age", sex = "sex")
  expect_output(print(rep), "reiod data quality report")
  s <- summary(rep)
  expect_s3_class(s, "summary.eiod_check")
  expect_output(print(s), "PASS|FAIL")
})
