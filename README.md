
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

## What it does

| Family             | Question                                                               | Source       | Function                    |
|--------------------|------------------------------------------------------------------------|--------------|-----------------------------|
| Absolute threshold | Is this diet below the per capita daily share of a planetary boundary? | Table 3      | `eiod_absolute_threshold()` |
| Relative benchmark | Where does this diet sit in a fixed global reference distribution?     | Tables 4a–4g | `eiod_relative_band()`      |
| Composite — HESD   | Healthy *and* environmentally sustainable?                             | Table 5a     | `eiod_hesd()`               |
| Composite — HDLEI  | Healthy *and* low environmental impact?                                | Table 5b     | `eiod_hdlei()`              |

Seven indicators: total, arable and pasture land use; greenhouse gases;
eutrophication potential; water use; biodiversity loss. All 616 cut-offs
are age- and sex-specific, and ship with the package.

## Installation

``` r
# install.packages("pak")
pak::pak("nicholustintzaw/reiod")
```

**No dependencies beyond base R.** `reiod` imports only `stats` and
`utils`, which ship with every R installation, so it installs with no
dependency tree. The consequence is a plain vector API: pass
`df$biodiv_pdf`, not `biodiv_pdf`.

Your columns can be called anything. `"biodiv"` is the indicator *key*
reiod knows; what the column is named in your data is a separate matter,
and the two never have to match.

## Example

`eiod_demo` is a synthetic dataset shipped with the package: 600
respondent-days with age, sex, a GDQS score and the seven impact totals.
`eiod_demo_map` says which of its columns holds which indicator.

``` r
library(reiod)

d <- eiod_demo
d$grp <- eiod_age_sex_group(d$age, d$sex)   # the eight age x sex groups

# check the inputs before computing anything
summary(eiod_check_data(d, impacts = eiod_demo_map,
                        age = "age", sex = "sex", gdqs = "gdqs"))
#> PASS - 0 error, 0 warning, 33 note

# Table 3 - % of diets below each absolute threshold
abs7 <- eiod_absolute_all(d, d$grp, eiod_demo_map)
round(100 * colMeans(abs7, na.rm = TRUE), 1)
#>   abs_landtotal  abs_landarable abs_landpasture         abs_ghg     abs_eutroph 
#>            70.2            80.8            68.7            22.2            53.5 
#>       abs_water      abs_biodiv 
#>            95.2            57.1

# Tables 4a-4g - relative band (1-10) for greenhouse gases
table(eiod_relative_band(d$ghg_kgco2e, d$grp, "ghg"))
#> 
#>   1   2   3   4   5   6   7   8   9  10 
#> 249  30  65  78  29   1   4  63  23  58

# Table 5a - healthy and environmentally sustainable diet
table(eiod_hesd(d$biodiv_pdf, d$gdqs, d$grp))
#> 15 observation(s) aged under 2 years set to NA: the GDQS is not validated below age 2, so the HESD metric does not apply to them.
#> 
#>         Healthy and env. sustainable     Not healthy but env. sustainable 
#>                                  206                                  125 
#>     Healthy but not env. sustainable Not healthy and not env. sustainable 
#>                                  124                                  110
```

The percentages are unweighted and the data are synthetic: they
demonstrate the code, not a result. With survey data, estimate
prevalences with a design-aware estimator (see below).

## What it does not do

**`reiod` does not contain the EIOF database.** It implements the metric
*cut-offs* defined in the Intake methods paper and applies them to
impact values you have already derived. Matching food items to impact
factors, applying edible-portion, processing and cooking-yield
adjustments, and summing to the respondent-day is upstream work that
this package starts after.

**It does not calculate the Global Diet Quality Score.** The composite
metrics take a GDQS value as input.

**It applies no survey design.** `reiod` returns respondent-level
indicator vectors. Every prevalence you report should come from a
design-aware estimator — the **survey** package or equivalent — or both
your point estimates and your standard errors will be wrong for a
complex design.

**It cannot see incomplete EIOF coverage.** Not every food has an impact
factor, and a food without one contributes nothing to the day total, so
the total is understated. `reiod` receives one number per
respondent-day; the aggregation has already discarded the evidence.
Count the share of consumed weight carrying a factor when you aggregate,
and report it with any prevalence.

## Cautions before you report results

**1. Eight eutrophication cut-offs differ from the published PDF, on
Intake’s instruction.** The paper prints the Table 3 eutrophication row
in kilograms while Table 4f and the EIOF databases use grams; Intake
confirmed in October 2026 that both tables are meant to be in grams and
supplied corrected values. They are the printed figures × 1000 — same
quantity, different unit — so no result changes, and the `value_source`
column marks the eight rows. **Supply eutrophication in grams and
convert nothing.**

**2. A low relative band is not evidence of sustainability.** For
greenhouse gases even band 1 exceeds the planetary boundary; for water
even band 10 is below it. The two metric families answer different
questions and will not agree. Never use one as a proxy for the other.

**3. HDLEI is nested inside HESD.** The HDLEI cut-off is uniformly 1.52×
stricter, so every HDLEI diet is also a HESD diet. They are not two
independent dimensions and must not be presented as a 2×2.

**4. The relative reference distribution is country-level.** It is built
from Food Balance Sheet data — national availability averages, not
individual consumption. A band is a statement about position relative to
*national average availability patterns*, not relative to other people
or other days. Worth a sentence in any methods section.

**5. The data checks are opt-in.** Only one test runs on the default
metric path: an impact vector must not be an integer, because
`is.numeric(1L)` is `TRUE` and nothing else would catch it. Sign, zeros,
unit magnitude, retained precision and cut-off proximity are checked
only if you call `eiod_check_data()`.

## Documentation

Start with **[Get
started](https://nicholustintzaw.github.io/reiod/articles/reiod.html)**
for what is in the package and what the cut-offs are. Then the articles,
in order:

|     | Article                                                                                                       |
|-----|---------------------------------------------------------------------------------------------------------------|
| 1   | [Check your data first](https://nicholustintzaw.github.io/reiod/articles/data-checks.html)                    |
| 2   | [Demographic groups](https://nicholustintzaw.github.io/reiod/articles/demographic-groups.html)                |
| 3   | [Table 3 — absolute thresholds](https://nicholustintzaw.github.io/reiod/articles/table3-absolute.html)        |
| 4   | [Tables 4a–4g — relative benchmarks](https://nicholustintzaw.github.io/reiod/articles/table4-relative.html)   |
| 5   | [Tables 5a & 5b — composite metrics](https://nicholustintzaw.github.io/reiod/articles/table5-composites.html) |

Each metric article works through a single value, a column from a
dataset, adding results to a data frame, all seven indicators at once,
and **only the indicators you have**.

Reference notes: [the precision pre-flight
check](https://nicholustintzaw.github.io/reiod/articles/precision.html),
[a broken dataset fault by
fault](https://nicholustintzaw.github.io/reiod/articles/troubleshooting.html),
and [eutrophication’s corrected
cut-off](https://nicholustintzaw.github.io/reiod/articles/eutrophication.html).

## Source

Intake (2026). [*Methods for Assessing Healthy, Environmentally
Sustainable Diets
Globally.*](https://www.intake.org/sites/default/files/2026-01/Intake-EIOD-Methods-Paper-Jan2026-Final.pdf)
Tables 3, 4a–4g, 5a and 5b.

The cut-offs ship as `eiod_cutoffs`, a 616-row long-format dataset built
from the same source file as a companion [Stata
implementation](https://github.com/nicholustintzaw/eiod), so the two
cannot drift apart at the data layer.

## Related

[`{riycf}`](https://github.com/nutriverse/riycf) — infant and young
child feeding indicators, same dependency-free design.
