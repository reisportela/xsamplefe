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
  140-case grid and counts larger than signed 64-bit integers.
- Complete-unit retention, group closure and its documented partial-unit cases,
  missing values, eligibility, balance, mobility, connectivity and reconnect.
- Row-order invariance and actual OpenMP teams of 1, 8 and 48 threads when
  the host exposes enough processors.
- `sample2` compatibility, synthetic estimation and mobility checks, and an
  optional `reghdfe`/`xhdfe` comparison on the same synthetic sample.
- Absorb-parser errors, failed-call RNG restoration, missing plugins and
  rebinding after `discard`.

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
