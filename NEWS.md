# reiod 0.1.0.9000

Preparation for rOpenSci software peer review. 2026-10-29.

## Changed behaviour

* `eiod_check_magnitude()` names the correct unit when it suspects a unit
  error. Its hints for eutrophication still assumed the threshold was in
  kilograms; since Intake's October 2026 correction the expected unit is
  grams, so values 1000 times too large now read "values in mg where g is
  expected" and values 1000 times too small "values in kg where g is
  expected". Two hints that could never be shown (greenhouse gases in
  tonnes, water in mL) now can, and several that pointed the wrong way are
  fixed. Detection itself, and the warning level, are unchanged.

## Documentation

* Help pages are now generated with roxygen markdown throughout. Bold,
  code and links previously showed as raw `**`, backticks and `[fn()]` on
  some pages.
* `?eiod_lookup_cutoff` and `?reiod` no longer describe the superseded
  eutrophication rescaling: eight Table 3 values carry Intake's confirmed
  grams, and nothing is converted anywhere.
* The methods paper is referenced in `DESCRIPTION` (Deitchler et al. 2026,
  with its URL; the paper has no DOI) and cited in `CITATION.cff` as its own
  recommended citation gives it.
* Shared parameter descriptions are written once and inherited.
* New contributing guide (`.github/CONTRIBUTING.md`) and a Code of Conduct
  notice in the README.
* The maintainer's ORCID iD and current email are in `DESCRIPTION` and
  `CITATION.cff`.
* The Get started article, the README and `?reiod` have a runnable
  start-to-finish example.

## Internal

* The functions goodpractice flagged for cyclomatic complexity (up to 28)
  or length are split into small internal helpers. No function now exceeds a
  complexity of 15. Behaviour is unchanged: a snapshot of 223 cases (values,
  messages, warnings, errors and printed output) is identical before and
  after.
* No global assignment (`<<-`) remains.
* lintr reports nothing beyond the `library()` calls in tests and
  vignettes; the few deliberate exceptions are recorded in `.lintr` or with
  `# nolint`, each with its reason.
* A `pkgcheck-summary` GitHub workflow runs pkgcheck on every push while the
  upstream pkgcheck action is affected by ropensci-review-tools/pkgcheck#444.

# reiod 0.1.0

Intake corrected the Table 3 eutrophication thresholds. 2026-10-22.

## Breaking: remove any `/1000` you apply to eutrophication

Intake confirmed by email that **both** Table 3 and Table 4f are expressed in
grams PO4(3-)eq, and supplied corrected Table 3 thresholds. The published PDF
prints those eight cells in kilograms.

Between July and October 2026 `eiod_absolute_threshold()` divided your
eutrophication values by 1000 to match the printed kilograms. **It no longer
does.** Supply grams — which is what the EIOF databases give you — and convert
nothing. Dividing now would make results wrong by a factor of a thousand in
the other direction.

Every other indicator is unaffected; there never was a conversion for any of
them.

## The quantity did not change, and no classification moves

The corrected values are the printed ones × 1000, carried to full precision:
divide any of them by 1000 and you recover the figure in the PDF to its ten
decimals. `data-raw/build_data.R` and `tests/testthat/test-reference_values.R`
both assert that, so the two can never silently part company.

Tested on 400,000 simulated gram-scale values, the old behaviour (divide the
value, compare against the PDF's kilograms) and the new one (compare grams
directly) agreed everywhere. They can differ only within about one ULP of a
cut-off, and there the new path is the more exact, because it no longer
divides before comparing.

## Eight rows of `eiod_cutoffs` no longer match the paper

They are the only eight of the 616 that do not, and a new **`value_source`**
column marks them — `"published"` for 608, `"intake correction 2026-10"` for
these. `eiod_cutoff()` reports it, and `?eiod_cutoffs` documents it.

```r
subset(eiod_cutoffs, value_source != "published",
       select = c(demogroup_label, value, value_source))
```

**These values may differ from the Intake guideline PDF as published today.**
That is deliberate and on Intake's instruction, not an error in `reiod`.

## The demo data moved to grams too

`eiod_demo$eutroph_kgpo4e` is renamed **`eutroph_gpo4e`** and resimulated in
grams, and `eiod_demo_map` follows it.

This had to change. With the conversion gone, the shipped map pointed
`eutroph` at a kilogram column, so
`eiod_absolute_all(eiod_demo, grp, eiod_demo_map)` returned **100% below
threshold** and the relative metric put every respondent in band 1 — the
package's own demo demonstrating the 1000× mistake this release warns about.
Nothing errored; it just quietly classified everything the same way.

Two guards now exist so it cannot recur: `data-raw/build_data.R` refuses to
save demo data whose median is more than 20× away from its indicator's median
cut-off, and `tests/testthat/test-reference_values.R` asserts the same thing
plus that no indicator comes out degenerate under the shipped map.

## The documentation site is reorganised

The home page and Get started page had both become catch-alls. They are now
scoped, and the detail moved into articles rather than being dropped.

* **Home** — what the package does, how to install it, what it does *not* do,
  and five cautions to read before reporting results. Nothing else.
* **Get started** — what is in the package, how to see the indicators it
  knows, what the cut-offs are for each table, and survey weights. It no
  longer teaches you to compute anything.
* **Articles** — a dropdown in three groups, meant to be read in order:
  *Before you compute* (`data-checks`, `demographic-groups`), *The metrics,
  table by table* (`table3-absolute`, `table4-relative`,
  `table5-composites`), and *Reference notes* (`precision`,
  `troubleshooting`, `eutrophication`).

Each metric article now works the same five ways through its table: **a single
value, a column from a dataset, adding results to a data frame, all seven
indicators at once, and only the indicators you have.** That last one was
already supported and barely documented — `eiod_absolute_all()` and
`eiod_relative_all()` have always accepted any subset of the seven.

`vignette("relative-benchmarks")` is renamed **`vignette("table4-relative")`**
for consistency with the other table articles. Four articles are new:
`data-checks`, `demographic-groups`, `table3-absolute`, `table5-composites`.

## Also

* `.eiod_to_cutoff_unit()` is **removed**. Nothing in the package rescales
  anything now, for any indicator.
* `details = TRUE` on `eiod_absolute_threshold()` returns **four** columns.
  The `value_kg` column is gone; there is no converted value to show.
* `vignette("eutrophication")` rewritten around the correction.

# reiod 0.0.0.9006

Documentation only. No computed result changes. 2026-10-15.

* **Incomplete EIOF coverage is now documented as an upstream responsibility.** Not every
  food has an impact factor; a food without one contributes nothing to the day total, so the
  total is understated - and `reiod` cannot detect it, because it receives one number per
  respondent-day and the aggregation has already discarded the evidence. The one detectable
  case, every food uncosted and summed to `0` rather than `NA`, was already caught by the zero
  check in `eiod_check_impact()`.

  New section in `vignette("troubleshooting")`, "The one you have to handle yourself", with
  what to compute upstream: the share of consumed weight carrying a factor, reported alongside
  any prevalence. Cross-referenced from `vignette("precision")` and `?eiod_list_indicators`.

* The methods paper is now hyperlinked wherever it is cited.

# reiod 0.0.0.9005

The eutrophication conversion is now visible. 2026-10-14.

* `details = TRUE` on `eiod_absolute_threshold()` returns the converted value as
  a **`value_kg`** column (renamed from `value_compared`), so the whole chain -
  value in grams, value in kilograms, published cut-off, result - reads off one
  table. The companion Stata command does the same thing in the shape Stata
  users expect: it leaves `<yourvar>_kg` in the dataset.
* `vignette("eutrophication")` gains a worked check of the arithmetic.

No computed result changes.

# reiod 0.0.0.9004

The reference data now matches the methods paper on every row. 2026-10-14.

## Breaking: supply eutrophication in GRAMS

The input unit for `eutroph` changes from kg PO4(3-)eq to **g PO4(3-)eq** —
which is what the EIOF database gives you, so for most users this means
*removing* a conversion rather than adding one.

Every other indicator is unchanged.

## Breaking: `eiod_cutoffs` loses two columns

`value_published` and `scale_to_db_unit` are gone. `value` is now the cut-off
**exactly as printed in the paper, for all 616 rows**, and
`value_published_str` is the same number as literal text.

Until now, the 80 relative eutrophication rows were stored pre-divided by 1000
so every cut-off sat on one internal scale. It worked, but it meant 80 of the
shipped numbers could not be found anywhere in the source document — which
defeats the purpose of shipping the reference data at all. **You can now check
any row of `eiod_cutoffs` against the PDF and expect a character-for-character
match.**

Note that `d$value_published` will now *partial-match* `value_published_str`
and silently return a character vector. If you referenced that column, change
it to `d$value`.

## The conversion moved into the command

`eiod_absolute_threshold()` divides eutrophication values by 1000 before
comparing against Table 3, which the paper prints in kilograms. It emits a
message when it does. `eiod_relative_band()` does nothing, because Table 4f is
printed in grams.

* the rule lives in one internal function, `.eiod_to_cutoff_unit()`, used by
  both metric functions and by `eiod_check_precision()`;
* `details = TRUE` gains a `value_compared` column for `eutroph`, so the table
  cannot be misread as comparing grams with kilograms;
* `eiod_cutoffs$unit` now records what each table is printed in — kg for
  Table 3 eutrophication, g for Table 4f. Every other indicator has one unit
  across both;
* `eiod_indicators$unit` reports the **input** unit, now `g PO4(3-)eq`.

## Other

* New `vignette("eutrophication")` — the whole issue in one place: what to
  supply, what the package does, the evidence, and what changes if Intake's
  answer differs.
* `eiod_lookup_cutoff()`'s `published` argument no longer has any effect and is
  retained only so existing scripts keep working. Both settings return the
  published value, because that is now the only value there is.

# reiod 0.0.0.9003

Documentation only. No computed result changes. 2026-10-14.

## If your impacts come from the EIOF database, read this

The EIOF country databases store eutrophication as **`Eutr. (g PO43-e/kg)` — in
grams** — while every other indicator matches the methods paper's unit
(`Land (m2/kg)`, `GHG (kg CO2e/kg)`, `Water Use (L/kg)`). Checked across the
Burkina Faso, Ethiopia, Ghana and Viet Nam files; it is the EIOF standard.

So the obvious pipeline produces the wrong unit for exactly one indicator:

```
kg food consumed  x  g PO4e per kg food  =  GRAMS PO4e per person per day
```

**Divide that total by 1000 before passing it to `reiod`**, or every
eutrophication result is wrong by a factor of a thousand. No other indicator
needs converting. `eiod_check_magnitude()` detects it, but it is opt-in — so
the warning is now stated wherever the expected unit is, including in the
printed output of `eiod_list_indicators()`.

## The eutrophication inference is now much better evidenced

Still an inference, still unconfirmed by Intake — but the case is now four
independent lines rather than two, and one of them is new and decisive about
Intake's operational unit:

* the **EIOF database reports eutrophication in grams** while the paper states kg;
* the kilogram reading of Table 4f is physically impossible (18.4 kg PO4eq per
  person per *day*);
* rescaled, the Table 3 threshold lands between P40 and P50 of Table 4f in
  **8 of 8** demographic groups, across a 3.5x spread of threshold values;
* Tables 3 and 4 come from different upstream sources (planetary-boundary
  literature vs the WWF Planet-Based Diets Database).

See `?eiod_cutoffs` and `vignette("reiod")`. A full write-up, including a
pending decision about which unit the package should work in, is in
`outputs/r-package-development/EUTROPHICATION_UNITS.md`.

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
