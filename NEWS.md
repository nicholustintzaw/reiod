# reiod 0.0.0.9002

Renamed, and a cross-platform CI failure fixed. 2026-10-14.

## Breaking: the package is now `reiod`, not `reiof`

Every exported function, dataset, S3 class and file has been renamed
`eiof_*` → `eiod_*`; the package itself is `reiod`.

**EIOF** is Intake's *Environmental Impacts of Foods* **database**. **EIOD** is the
*Environmental Impacts of Diets* **metrics** — Tables 3, 4a–4g, 5a and 5b, which is
what this package implements and all it implements. The old name advertised a
database the package explicitly does not contain, which is why the README had to
spend a paragraph disowning it.

The rename also brings the package into line with the companion Stata
implementation, whose commands have always been `eiod_*`. One vocabulary across
both now.

Update any script by substituting `eiof` → `eiod` throughout; nothing else
changed. No function signature, default or result is different.

References to the **EIOF database** in the prose are unchanged and still say
EIOF, because that is still its name.

## Fixed

* **`R CMD check` failed on macOS (arm64) and passed everywhere else.** A test
  added in 0.0.0.9001 asserted
  `identical(as.numeric(value_published_str), value_published)`. That demanded
  bit-identical decimal-to-binary conversion on two different platforms, which
  is not guaranteed for values needing a large decimal exponent.

  16 of 616 cut-offs disagreed, every one of them biodiversity — the only
  indicator whose values all sit near 1e-13 — and every disagreement was one
  unit in the last place, about 2.2e-16 relative.

  **No result was affected, and the shipped data was never wrong.** Nudging every
  demonstration value by ±2 ULP across all seven indicators changes 0 of 8,400
  classifications. The assertion was simply stricter than the quantity it was
  testing.

  It is replaced by the two invariants that actually matter and that hold on
  every platform: every shipped double reproduces its published digits, and a
  re-parse agrees to within a few ULP. The reasoning is recorded in
  `tests/testthat/test-reference_values.R` so the assertion is not tightened
  back.

# reiod 0.0.0.9001

Changes from the Stata cross-check, 2026-10-14.

The companion Stata implementation went through a usability and precision
rebuild in early October 2026, driven by complaints from real use. Seven of its
sixteen findings also applied here. All seven are now addressed.

## Breaking

* **`eiod_demo`'s impact columns have been renamed** away from the indicator
  keys: `landtotal` is now `land_total_m2yr`, `ghg` is `ghg_kgco2e`, `biodiv` is
  `biodiv_pdf`, and so on. The values are unchanged, bit for bit.

  The old names made `for (ind in eiod_indicators$indicator) eiod_demo[[ind]]`
  possible, which implied the package required your columns to be named after
  the keys. **It never did** — reiod takes vectors. The rename forces every
  example to state the indicator-to-column mapping explicitly. `eiod_demo_map`
  ships that mapping.

  Code using `eiod_demo$ghg` and friends must be updated; code using your own
  data is unaffected.

## New

* **An integer impact vector is now refused by the metric functions.**
  `is.numeric(1L)` is `TRUE`, so an integer column previously passed every guard
  on the default path and was compared against the cut-off with its fractional
  part already truncated away. Measured on 200,000 simulated respondent-days in
  the companion Stata implementation, the same fault biased mean greenhouse gas
  emissions down from 3.836 to 3.336 — **13%**, silently. This is the only data
  quality test on the default path; everything else remains opt-in through
  `eiod_check_data()`.
* `eiod_absolute_all()` and `eiod_relative_all()` apply a metric to several
  indicators in one call, taking a named `map` from indicator key to column name.
* `details = TRUE` on `eiod_absolute_threshold()` and `eiod_relative_band()`
  returns the cut-off each observation was actually compared against —
  `cutoff` for the absolute metric, `cut_lower`/`cut_upper` for the relative one.
  Equivalent to `threshvar()` and `cutvar()` in the Stata commands.
* `eiod_lookup_cutoff()` now returns a classed object with a print method at 15
  significant digits, shown beside the literal text from the paper. R's default
  `options(digits = 7)` would have displayed the published `1726.3821057877` as
  `1726.382`, which looked as though the package had rounded the guideline. It
  had not; only the display was short. The object behaves as a plain named
  numeric under `[`, `c()` and arithmetic.
* `eiod_cutoffs` gains **`value_published_str`**: the cut-off as the literal
  characters transcribed from the paper, never through a numeric type. For an
  exact decimal check, compare against this rather than a rendering of a double.
* New `vignette("precision")` — the precision check as a pre-flight step, with
  the measured evidence for which precision worries are real. The troubleshooting
  vignette now carries a fifth planted fault, an integer column.

# reiod 0.0.0.9000

First working version. Implements Tables 3, 4a-4g, 5a and 5b of the Intake
Environmental Impacts of Foods methods paper (January 2026).

* `eiod_age_sex_group()` builds the eight-category demographic group that every
  cut-off is scaled by, and `eiod_as_sex_factor()` converts a numeric sex code
  into the recommended factor input.
* `eiod_absolute_threshold()` (Table 3) and `eiod_relative_band()`
  (Tables 4a-4g) for all seven environmental impact indicators.
* `eiod_hesd()` (Table 5a) and `eiod_hdlei()` (Table 5b), each returning the two
  criteria as separate sub-indicators as well as the combined measure.
* `eiod_check_data()` and five component checks covering variable type,
  plausibility, numerical precision and unit magnitude.
* Cut-offs ship as `eiod_cutoffs`, a 616-row long-format dataset built from the
  same source file as the companion Stata implementation.

## Known limitations

* The relative benchmark cut-offs for eutrophication potential carry an
  inferred rescaling. See `vignette("reiod")`, section "A caution on
  eutrophication". Confirm with Intake before publishing eutrophication results.
