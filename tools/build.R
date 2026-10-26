# ---------------------------------------------------------------------------- #
# tools/build.R - the maintainer's rebuild loop. Not part of the package.
#
# The roxygen comments in R/ are the source of truth for man/ and NAMESPACE;
# never edit those by hand. README.md is knitted from README.Rmd. The datasets
# in data/ are built from data-raw/. Run the steps you need, top to bottom.
# ---------------------------------------------------------------------------- #

## 0. one-time: install the development tooling
# install.packages(c("devtools", "roxygen2", "pkgdown", "covr"))

## 1. after editing roxygen comments in R/: regenerate man/ and NAMESPACE
# devtools::document()

## 2. after editing README.Rmd: re-knit README.md (it runs the example code)
# devtools::build_readme()

## 3. only if data-raw/eiod_cutoffs.csv changes (e.g. an Intake correction):
#    rebuild the datasets. The script stops if any cut-off fails to round-trip
#    to its published digits.
# source("data-raw/build_data.R")

## 4. test, measure coverage, and check
# devtools::test()
# covr::report(covr::package_coverage())   # rOpenSci expects at least 75%
# devtools::check()

## 5. build the website locally (CI also builds and deploys it on every push
#    to main)
# pkgdown::build_site()
