# reiof 0.0.0.9001

Changes from the Stata cross-check, 2026-10-14.

The companion Stata implementation went through a usability and precision
rebuild in early October 2026, driven by complaints from real use. Seven of its
sixteen findings also applied here. All seven are now addressed.

## Breaking

* **`eiof_demo`'s impact columns have been renamed** away from the indicator
  keys: `landtotal` is now `land_total_m2yr`, `ghg` is `ghg_kgco2e`, `biodiv` is
  `biodiv_pdf`, and so on. The values are unchanged, bit for bit.

  The old names made `for (ind in eiof_indicators$indicator) eiof_demo[[ind]]`
  possible, which implied the package required your columns to be named after
  the keys. **It never did** — reiof takes vectors. The rename forces every
  example to state the indicator-to-column mapping explicitly. `eiof_demo_map`
  ships that mapping.

  Code using `eiof_demo$ghg` and friends must be updated; code using your own
  data is unaffected.

## New

* **An integer impact vector is now refused by the metric functions.**
  `is.numeric(1L)` is `TRUE`, so an integer column previously passed every guard
  on the default path and was compared against the cut-off with its fractional
  part already truncated away. Measured on 200,000 simulated respondent-days in
  the companion Stata implementation, the same fault biased mean greenhouse gas
  emissions down from 3.836 to 3.336 — **13%**, silently. This is the only data
  quality test on the default path; everything else remains opt-in through
  `eiof_check_data()`.
* `eiof_absolute_all()` and `eiof_relative_all()` apply a metric to several
  indicators in one call, taking a named `map` from indicator key to column name.
* `details = TRUE` on `eiof_absolute_threshold()` and `eiof_relative_band()`
  returns the cut-off each observation was actually compared against —
  `cutoff` for the absolute metric, `cut_lower`/`cut_upper` for the relative one.
  Equivalent to `threshvar()` and `cutvar()` in the Stata commands.
* `eiof_lookup_cutoff()` now returns a classed object with a print method at 15
  significant digits, shown beside the literal text from the paper. R's default
  `options(digits = 7)` would have displayed the published `1726.3821057877` as
  `1726.382`, which looked as though the package had rounded the guideline. It
  had not; only the display was short. The object behaves as a plain named
  numeric under `[`, `c()` and arithmetic.
* `eiof_cutoffs` gains **`value_published_str`**: the cut-off as the literal
  characters transcribed from the paper, never through a numeric type. For an
  exact decimal check, compare against this rather than a rendering of a double.
* New `vignette("precision")` — the precision check as a pre-flight step, with
  the measured evidence for which precision worries are real. The troubleshooting
  vignette now carries a fifth planted fault, an integer column.

# reiof 0.0.0.9000

First working version. Implements Tables 3, 4a-4g, 5a and 5b of the Intake
Environmental Impacts of Foods methods paper (January 2026).

* `eiof_age_sex_group()` builds the eight-category demographic group that every
  cut-off is scaled by, and `eiof_as_sex_factor()` converts a numeric sex code
  into the recommended factor input.
* `eiof_absolute_threshold()` (Table 3) and `eiof_relative_band()`
  (Tables 4a-4g) for all seven environmental impact indicators.
* `eiof_hesd()` (Table 5a) and `eiof_hdlei()` (Table 5b), each returning the two
  criteria as separate sub-indicators as well as the combined measure.
* `eiof_check_data()` and five component checks covering variable type,
  plausibility, numerical precision and unit magnitude.
* Cut-offs ship as `eiof_cutoffs`, a 616-row long-format dataset built from the
  same source file as the companion Stata implementation.

## Known limitations

* The relative benchmark cut-offs for eutrophication potential carry an
  inferred rescaling. See `vignette("reiof")`, section "A caution on
  eutrophication". Confirm with Intake before publishing eutrophication results.
