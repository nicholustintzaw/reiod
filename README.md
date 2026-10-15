
<!-- README.md is generated from README.Rmd. Please edit that file -->

# reiod

<!-- badges: start -->

[![Project Status:
WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/nicholustintzaw/reiod/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/nicholustintzaw/reiod/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/nicholustintzaw/reiod/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/nicholustintzaw/reiod/actions/workflows/pkgdown.yaml)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

Dietary environmental impact metrics from Intake’s Environmental Impacts
of Foods framework, for R.

**`reiod` does not contain the EIOF database.** It implements the metric
*cut-offs* defined in the Intake methods paper and applies them to
impact values you have already derived. Matching food items to impact
factors, applying edible-portion, processing and cooking-yield
adjustments, and summing to the respondent-day is upstream work that
this package starts after. It also does not calculate the Global Diet
Quality Score; the composite metrics take a GDQS value as input.

## What it does

| Family             | Question                                                               | Source       | Function                    |
|--------------------|------------------------------------------------------------------------|--------------|-----------------------------|
| Absolute threshold | Is this diet below the per capita daily share of a planetary boundary? | Table 3      | `eiod_absolute_threshold()` |
| Relative benchmark | Where does this diet sit in a fixed global reference distribution?     | Tables 4a–4g | `eiod_relative_band()`      |
| Composite — HESD   | Healthy *and* environmentally sustainable?                             | Table 5a     | `eiod_hesd()`               |
| Composite — HDLEI  | Healthy *and* low environmental impact?                                | Table 5b     | `eiod_hdlei()`              |

Seven indicators: total, arable and pasture land use; greenhouse gases;
eutrophication potential; water use; biodiversity loss. All cut-offs are
age- and sex-specific.

## Installation

``` r
# install.packages("pak")
pak::pak("nicholustintzaw/reiod")
```

**No dependencies.** `reiod` imports nothing, so it installs with no
dependency tree. The consequence is a plain vector API: pass
`df$biodiv_pdf`, not `biodiv_pdf`.

Your columns can be called anything. `"biodiv"` is the indicator *key*
reiod knows; what the column is named in your data is a separate matter,
and the two never have to match.

## Usage

``` r
library(reiod)

# 1. state which column holds which indicator, once
my_map <- c(biodiv = "biodiv_pdf", ghg = "ghg_kgco2e")

# 2. check the data before computing anything
report <- eiod_check_data(
  eiod_demo,
  impacts = my_map,
  age = "age", sex = "sex", gdqs = "gdqs"
)
summary(report)
#> PASS - 0 error, 0 warning, 13 note
```

``` r
# 3. the demographic group, required by everything else
grp <- eiod_age_sex_group(age = eiod_demo$age, sex = eiod_demo$sex)

# 4. the metrics
ghg_abs    <- eiod_absolute_threshold(eiod_demo$ghg_kgco2e, grp, "ghg")
biodiv_bnd <- eiod_relative_band(eiod_demo$biodiv_pdf, grp, "biodiv")
hesd       <- eiod_hesd(eiod_demo$biodiv_pdf, eiod_demo$gdqs, grp, form = "binary")
#> 15 observation(s) aged under 2 years set to NA: the GDQS is not validated below age 2, so the HESD metric does not apply to them.

round(100 * c(ghg_below_threshold = mean(ghg_abs, na.rm = TRUE),
              hesd                = mean(hesd,    na.rm = TRUE)), 1)
#> ghg_below_threshold                hesd 
#>                22.2                36.5
```

Several indicators at once, with the same mapping:

``` r
round(100 * colMeans(eiod_absolute_all(eiod_demo, grp, eiod_demo_map),
                     na.rm = TRUE), 1)
#> eutrophication: your values were divided by 1000 (g -> kg PO4(3-)eq) to match Table 3, which the methods paper prints in kilograms. Supply this indicator in GRAMS, as the EIOF database reports it. Table 4f is printed in grams and needs no conversion. See vignette("eutrophication").
#>   abs_landtotal  abs_landarable abs_landpasture         abs_ghg     abs_eutroph 
#>            70.2            80.8            68.7            22.2           100.0 
#>       abs_water      abs_biodiv 
#>            95.2            57.1
```

Each composite also returns its two criteria separately, which is
usually what you want for reporting:

``` r
parts <- eiod_hesd(eiod_demo$biodiv_pdf, eiod_demo$gdqs, grp, form = "components")
#> 15 observation(s) aged under 2 years set to NA: the GDQS is not validated below age 2, so the HESD metric does not apply to them.
head(parts, 3)
#>   healthy env                         category binary
#> 1       1   0 Healthy but not env. sustainable      0
#> 2       0   1 Not healthy but env. sustainable      0
#> 3       1   1     Healthy and env. sustainable      1
```

## A note on the `sex` variable

A **factor is the recommended input**; character works the same way.
Numeric is deliberately refused unless you say which code means male:

``` r
eiod_age_sex_group(age = c(1.5, 40), sex = c(1, 0))
#> Error: `sex` is numeric, so reiod cannot tell which code means male.
#>   Observed codes: 0, 1
#>   Survey data uses 1/2 and 0/1 about equally often, and guessing wrong would invert every result without any error.
#>   Either state the codes:
#>     eiod_age_sex_group(age, sex, male = 1, female = 2)
#>   or convert once, which is the recommended route:
#>     dat$sex <- eiod_as_sex_factor(dat$sex, male = 1, female = 2)
```

Survey data uses `1/2` and `0/1` about equally often, and they cannot be
told apart from the values alone. Guessing wrong would invert every
result silently. Convert once instead:

``` r
eiod_as_sex_factor(c(1, 0), male = 1, female = 0)
#> [1] male   female
#> Levels: male female
```

## Three things to know before reporting results

1.  **Eutrophication is printed in two different units.** Table 3 is in
    kg PO₄³⁻eq, Table 4f is in grams. **Supply your data in grams**, as
    the EIOF database gives it to you (`Eutr. (g PO43-e/kg)`);
    `eiod_absolute_threshold()` converts for you and says so. No
    published cut-off is ever adjusted — `eiod_cutoffs` matches the PDF
    on every one of its 616 rows. The unit reading is an inference
    Intake has not yet confirmed; see `vignette("eutrophication")`.
2.  **A low relative band is not evidence of sustainability.** For
    greenhouse gases even band 1 exceeds the planetary boundary; for
    water even band 10 is below it.
3.  **HDLEI is nested inside HESD.** The HDLEI cut-off is uniformly
    1.52× stricter, so every HDLEI diet is also a HESD diet. They are
    not two independent dimensions.

All three are explained in `vignette("reiod")`.

## Documentation

- `vignette("reiod")` — EIOF, reiod, and step-by-step usage
- `vignette("eutrophication")` — the one indicator with a unit problem
- `vignette("precision")` — the pre-flight precision check; run this
  before generating any indicator
- `vignette("relative-benchmarks")` — what the reference distribution
  is, and is not
- `vignette("troubleshooting")` — a broken dataset, the errors, and the
  fixes

## Data quality checks

`eiod_check_data()` runs six component checks covering variable type,
plausibility, numerical precision and unit magnitude. **They are
opt-in** — the only test on the default metric path is that an impact
vector must not be an integer, because `is.numeric(1L)` is `TRUE` and
nothing else would catch it. Two checks are worth singling out:

**Precision.** R’s `numeric` is a double, so a biodiversity value of
`3.6896e-13` is comfortably representable and `<` comparison is exact —
the small exponent is not the problem. The risk is ingestion fidelity:
Excel re-saving displayed digits, CSV exports written at six significant
digits, Stata `float` storage, database `REAL` columns. The check
measures significant digits actually retained, and counts how many
observations sit close enough to their own cut-off that rounding could
flip the classification.

The companion Stata implementation measured this on 200,000 simulated
respondent-days: single-precision storage changed **0 of 200,000**
absolute classifications and **1 of 200,000** relative bands, while
**integer** storage of greenhouse gas emissions biased the mean down by
**13%**. The intuition that the tiny exponent is the danger turns out to
be the wrong worry; truncation is the real one. See
`vignette("precision")`.

**Unit magnitude.** Compares your median against the published global
reference and names the likely conversion when the ratio lands near a
known factor:

``` r
eiod_check_magnitude(eiod_demo$ghg_kgco2e * 1000, "ghg", grp, name = "ghg_in_grams")
#> reiod data quality report
#> 
#>   ERROR    0
#>   WARNING  1
#>   NOTE     0
#> 
#>   WARNING  ghg_in_grams   magnitude    median 3061 vs expected 5.547 for this demographic mix (ratio 552).
#>                                        Consistent with a g <-> kg unit error. Expected unit: kg CO2eq.
#> 
#>   No blocking problems.
```

## Source

Intake (2026). [*Methods for Assessing Healthy, Environmentally
Sustainable Diets
Globally.*](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf)
Tables 3, 4a–4g, 5a and 5b.

The cut-offs ship as `eiod_cutoffs`, a 616-row long-format dataset built
from the same source file as a companion Stata implementation, so the
two cannot drift apart at the data layer.

## Related

[`{riycf}`](https://github.com/nutriverse/riycf) — infant and young
child feeding indicators, same dependency-free design.
