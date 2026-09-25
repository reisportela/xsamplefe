# Validation scope

The public distribution is intended for research testing. Sampling preserves
the documented selection and retention rules; it does not certify a research
design, guarantee identification, or correct limited-mobility bias.

## Reusable checks

`tests/run_tests.sh` runs six Stata certification files. It requires an explicit
success marker in a fresh log; shell exit status alone is insufficient.
`tests/selftest.sh` checks that failing assertions, stale logs and a command
that never starts Stata cannot produce a successful verdict.

Coverage includes:

- Exact retained rows and RNG state against native `sample`, including a
  140-case grid, sizes and percentages whose product n·#/100 lands on a half,
  and counts larger than signed 64-bit integers.
- Complete-unit retention, group closure and its documented partial-unit cases,
  missing values, eligibility, balance, mobility, connectivity and reconnect.
- Row-order invariance and actual OpenMP teams of 1, 8 and 48 threads when
  the host exposes enough processors.
- `sample2` compatibility, synthetic estimation and mobility checks, and an
  optional `reghdfe`/`xhdfe` comparison on the same synthetic sample.
- Frequency weights: a table of distinct rows with `[fweight=]` against the
  rows it stands for, in the retention indicator and the stored results.
- Absorb-parser errors, failed-call RNG restoration, missing plugins,
  rebinding after `discard`, and a plugin replaced at the same path within a
  session (the ado refuses a plugin of another release with r(498)).

These tests passed on StataNow/MP 19.5 on Linux during the September 2026 audit.
The C++ sampling implementation was unchanged by the fixes to the ado parser,
plugin loading and distribution. The release procedure reruns Stata tests
against the exact Linux binary downloaded from the successful GitHub workflow.

## Four-platform release checks

`.github/workflows/release.yml` builds Linux x86-64, Windows x86-64, Mac Intel
and Mac ARM binaries online. Each runner loads its actual output through the
Stata plugin interface and checks known selections, grouping, row order,
empty frames and observed OpenMP teams. Mac checks use the relocated, signed
plugin and bundled runtime. Windows builds reject GNU/MSYS runtime DLL imports.

The packager requires all four native checks to pass and all artifacts to name
the same source commit. `RELEASE.json` records the commit and workflow run;
`SHA256SUMS.txt` identifies the published files. Release installation uses those
same binaries, with platform selection by Stata's package descriptor.

Native plugin-interface tests do not exercise the Stata ado/RNG layer on Mac
or Windows. Investigator runs of `xsamplefe_check.do` and the tutorials remain
necessary there. Older Stata versions have not been separately certified.

## Interpretation and remaining limits

Functional correctness and speed are separate questions. Interleaved A/B
measurements on the shared Linux host did not establish a strict performance
non-regression verdict: differences were small relative to between-run variation.
No speed improvement is claimed for the audit corrections.

A separate group/individual comparison found row-order sensitivity in
`reghdfe` 6.14.1 on an unchanged selected sample. Ascending group/individual order
and `tolerance(1e-12)` yielded agreement with `xhdfe`; reversing the same rows
did not. This is a limitation of that estimator comparison. Users should check
convergence and sensitivity for their own designs.

Datasets used in local research benchmarks, machine-specific paths, working
notes and logs are not part of the current source distribution. The public
tests use artificial data and the official public `nlswork` fixture. The latter
can be supplied offline using `XSAMPLEFE_FIXTURE_DIR`.

GitHub publication does not constitute SSC submission; SSC is deferred.

## 1.3.0: faster phases with identical results, the xtset fix and reconnect

Most of the plugin's computing phases now run in parallel or were removed;
apart from the two behaviour changes below, no result changes. The union-find
over the distinct links and the reconnect search remain serial. Dense ranks of integer
identifiers use a bitmap of the values present instead of a sort; the if/in
check is skipped when no row with a unit or group value is outside the frame;
the rows of every unit are laid out in parallel in the same order as before;
large strata are drawn with a parallel histogram of the first key; the
connectivity graphs are built from the distinct unit-mobility links; only the
uniform cells that the draw uses are read; only retained rows are written.
Reading from and writing to Stata remain on one thread, because the plugin
interface is not safe to read from worker threads. The ado compacts an
absorb() interaction only when it becomes the unit or the mobility dimension.

Evidence, on Linux with StataNow/MP 19.5:

- Same-session comparison with 1.2.3 in 201 designs, ten of them with
  reconnect on dense graphs where both frontiers coincide (observation and unit
  sampling, filters, strata with extended missing values, mobility, graphs,
  reconnect, minmovers, groups, if/in rules, interactions, and identifiers that
  are non-integer, negative, sparse, near 2^53, float and string): identical
  return codes, stored results, random-number state and data.
- Direct plugin tests with constructed ties on the first key columns, including
  large strata and 1, 8 and 48 threads: identical to the 1.2.3 selection.
- Five deliberately broken builds were detected: four by these comparisons or by
  the certification asserts, one by Stata stopping on the corrupted index it
  produced.
- The certification suite passes, with new permanent tests: implicit xtset
  time with in, selection with ties against Stata's own sort, invariance to
  order-preserving recodings of the unit, if 1 against no if/in, and two-column
  by() against sample.

Interleaved same-session timings on a 20-million-row worker panel (2 million
workers, 200,000 firms), 10 percent unit sample: 4.87 s to 2.08 s with 48
threads and 13.74 s to 3.19 s with one thread; connectivity 6.28 s to 2.48 s;
minmovers(2) 12.64 s to 3.85 s; observation sampling 2.91 s to 2.02 s. On the
500,000-row benchmark datasets the default calls are 26 to 45 percent faster.
An absorb() list with an interaction that is neither the unit nor the mobility
dimension no longer pays for its compaction (22.1 s to 2.4 s on the same panel).
On a 173-million-row simulated panel (20 million workers) the same design drew
the same 17,312,023 rows in 12-17 s instead of 24-33 s, and the peak memory of
the process fell from 16.9 GB to 11.6 GB.

Behaviour change 1: when balanced, minperiods() or maxperiods() take the time
variable from xtset, 1.2.3 ran xtset, which sorts the data before if/in are
applied, so in could select other rows and the data order changed. 1.3.0 reads
the stored time variable without sorting. The only other difference: data that
were xtset but later acquired repeated times within a panel now use that time
variable, as time() does, instead of stopping with a misleading message.

Behaviour change 2: reconnect now follows its documented rule. In 1.2.x, after
a unit joined the largest component, the frontier gained only the units linked
to that unit's own mobility values; units linked to a component that had just
merged into the largest one entered only when the frontier ran out. 1.3.0 keeps
the frontier complete (the values of every other component are listed once,
since such a component changes only when it joins the largest one) and, under
reconrule(gain), keeps the candidates in a heap whose stale gains are
recomputed at the top (gains can only fall). Against a brute-force
implementation of the documented rule on 320 random sparse panels (both rules,
four targets, ineligible units and missing mobility values), 1.3.0 agreed in
every case and 1.2.3 differed in 42. On the benchmark datasets reconnect
reaches the same target with fewer units under gain (4,442 instead of 5,334 on
patents, 6,131 instead of 7,116 on synthetic-assortative, the same 35 on
enron) and runs in well under a second, where 1.2.3 took up to 20 seconds
(19.6 s to 0.2 s on patents with reconrule(key)). Every other
stored result and every sample drawn without reconnect is identical to 1.2.3.

## 1.4.0: frequency weights, and percentages rounded as Stata rounds them

### Percentages rounded as Stata rounds them

The number drawn in a stratum, `int(n*#/100+.5)`, was computed by the plugin as
(n·#)/100. Stata evaluates `n*#/100` as n·(#/100), and in binary64 the two
differ when (n·#)/100 is exactly a half and n·(#/100) falls just below it.
There `sample` and `sample2` draw one fewer than 1.3.0 did: 29 percent of 50
observations or units is 14, and 1.3.0 drew 15. Parity with `sample` failed in
such strata, and so did the stated count for units and for the `movers()` and
`stayers()` rates; `count` was not affected. In an affected stratum the 1.3.0
draw is the 1.4.0 draw plus the next observation or unit in key order; group
closure, `connected`, `reconnect` and `minmovers()` can carry that difference
further. The random-number state after the call is unchanged, because the ado
already used Stata's arithmetic to size the uniform keys.

Evidence, on Linux with StataNow/MP 19.5:

- `%21x` shows that Stata and Mata give `500*0.7/100` the value of
  `500*(0.7/100)`, 3.4999999999999996, and `(500*0.7)/100` the value 3.5.
- For n from 1 to 3,000 and # from 0.1 to 99.9 in steps of 0.1, the 1.3.0
  formula differs from Stata's `int(n*#/100+.5)` in 829 of 2,997,000 pairs
  (183 with a whole-number percentage); the 1.4.0 formula agrees in all of them.
- The product is rounded before the half is added, whatever the compiler does
  with multiply-add instructions. For n up to 100,000 and the same percentages,
  a fused multiply-add would have given the same counts in all 99,900,000 pairs.
- New certification cases compare twelve such pairs with `sample` (rows and
  random-number state), a `by()` design with three such strata, units,
  `movers()`/`stayers()` rates and 29 percent of 50 clusters with `sample2`.
  The native plugin test run by the release workflow on the four platforms
  now checks 29 percent of 50 observations. All of these fail with the 1.3.0
  plugin and pass with 1.4.0.

### Frequency weights

With a sampling unit, `[fweight=w]` makes every observation stand for `w`
identical ones. Every count of rows in the plugin becomes a sum of weights:
the observations per unit behind `minobs()`/`maxobs()`, the rows of the graph
components behind `connected`, `reconnect` and the connectivity shares, and the
observation counts in `r()`. Counts of distinct units, periods, mobility values
and groups, the draw and the tests on distinct rows (units split by `if`/`in`,
group closure) are unchanged. A table of the distinct combinations of the
variables a design uses, with their counts, therefore draws the sample of data
that do not fit in memory, for example from an out-of-core engine. Weights
must be positive integers summing to less than 2^53; observation-level sampling
refuses them. Without weights the results are those of the rounding-corrected
plugin.

Evidence, on Linux with StataNow/MP 19.5:

- New certification section 13: on a worker-firm-year panel repeated over
  months (with missing firms) and on repeated patent-inventor pairs, the
  table from `contract` with `[fw=w]` gives the rows' retention indicator and
  every stored result except `r(n_uniforms)` in 17 designs: `minobs()`,
  `maxobs()` with strata and periods, `connected`, `reconnect` under both
  rules and an explicit target, `minmovers()`, rates with `mobstrata` and
  `connectivity`, `balanced`, `count` with strata, `if` with `any` and `all`,
  group closure under both rules and with `connected`, and, on data where 2
  percent of the rows have no unit, `absorb()` as the unit source, a string
  unit and `minperiods()`. The `by` prefix equals `by()` with weights and on
  the rows. The weighted draw is identical with 1, 8 and 48 threads (with
  `minobs()`, `connected` and `reconnect`) and after shuffling the rows;
  weights multiplied by 10^9 change no decision and multiply every count
  exactly; a total of 2^53 - 1 is accepted and 2^53 refused; errors are tested
  for weights without a unit, `aweight`s, and non-integer, zero and missing
  weights.
- The same comparison without the weights fails for `minobs()`, `reconnect`,
  `connected` and `minmovers()`, so the section detects unweighted counts.
- The native plugin test checks a weighted `minobs()` design on the four
  release platforms.
- `r(n_uniforms)` and the random-number state after the call follow the rows
  in memory, as the uniform keys are drawn over them; the draw is the same,
  because a unit-level draw reads only the first U uniforms of the first key
  column.
- Interleaved A/B timings against 1.3.0 on a 20-million-row worker panel
  (2 million workers, 200,000 firms, 8 threads, a shared host under load),
  medians of four pairs: unit sample 2.19 s and 2.21 s, `connectivity` 2.49 s
  and 2.46 s, `minmovers(2)` 2.68 s and 2.67 s, within the run-to-run spread.
  The three indicators drawn there are identical in both versions (these
  percentages are not rounding edges).
- The full certification passes; the optional benchmark-connectivity block,
  which needs the external datasets named by `XSF_SERGIO_DIR`, was skipped.

### Independent audit of the candidate, and its corrections

An independent read-only audit of the 1.4.0 candidate (25 September 2026)
found no defect in the rounding correction or in the frequency weights. It
reproduced them against Stata, `sample`, `sample2` and the `expand` oracle,
built five mutant plugins (each caught by section 13) and repeated the timings.
It reported one defect that blocked publication, two older defects of the
same family, and five minor points. All were reproduced before and after the
corrections below.

- **A plugin left loaded by an update (high).** After `net install ..., replace`
  and `discard`, as the README said, a session that had run 1.3.0 kept its
  plugin: `discard`, `clear all` and a new `program ..., plugin` do not
  unload a shared object. The 1.4.0 ado then ran on the 1.3.0 plugin, drawing
  15 units for 29 percent of 50 without a word, and a weighted call stopped
  with "varlist has wrong length". The plugin now reports its release to the
  ado (local `xsf_plugin_version`, 10400) before anything else, and the ado
  refuses any other release with r(498) and a request to restart Stata,
  restoring the random-number state and leaving the data untouched. With the
  1.3.0 plugin loaded, the README recipe now stops with r(498) at every call,
  weighted or not; a new Stata session then draws 14. The binding
  certification replaces the plugin at the same path within a session and
  checks that the same release still passes; the refusal of an older release
  was checked by hand, since no older binary ships with the tests. README,
  INSTALL and the help now say to restart Stata after an update or a rebuild,
  and never to copy a plugin over the file Stata has loaded, which crashed
  Stata in the audit.
- **`movers()`, `stayers()` and `recontarget()` rounded to about 13 digits
  (medium, older than 1.4.0).** They went through `numlist`: `movers(12.49999999999999)`
  became 12.5 and drew 1 of 4 movers where `int(n*#/100+.5)` gives 0. They now
  reach the plugin as typed, as `#` does, with the same error codes as before
  (r(121) for a non-number, r(125) out of range); section 12 checks the case.
- **`reconnect` stopped one unit late at an exact target (low, older than 1.4.0).**
  The share was compared in binary64, and 0.56 * 100 exceeds 56, so a sample
  whose largest component held exactly 56 of 100 rows still added a unit under
  `recontarget(56)` (likewise 55; the whole percentages affected with 100 rows
  are 7, 14, 28, 55 and 56). Whole-percentage targets and the frame share are
  now compared by cross-multiplication in 128-bit integers; the mobility
  certification checks 56 of 100 (no unit added) and `recontarget(57)`
  (three units, to 59 of 103).
- **Minor points.** With weights, the deletion message now says how many
  observations in memory were deleted and how many they stood for. The build
  script adds `-ffp-contract=off` on every target, a second guard beside the
  `volatile` product; the build-script test pins the flag. The README shows
  `[fweight]` with the `by` prefix. Section 13 adds the 48-thread, 10^9 and
  2^53 cases above. A string weight keeps Stata's own r(109) "type mismatch",
  which `syntax` raises before `xsamplefe` runs, as for any Stata command.
