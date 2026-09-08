# xsamplefe

`xsamplefe` draws random samples of panel / fixed-effect data for
[`reghdfe`](https://github.com/sergiocorreia/reghdfe) and
[`xhdfe`](https://github.com/reisportela/xhdfe-xfe) in Stata. It is a superset
of Stata's `sample` and of Weesie's `sample2` (STB-37 dm46): instead of drawing
observations it can draw whole *units* (workers, firms, patents, ...), preserving
their histories unless a different `group()` overrides unit retention. It adds strata,
balanced-panel and mobility filters, connected sets and `reghdfe`'s
`group()`/`individual()` designs. The work is done by a C++17/OpenMP plugin with
no dependencies beyond compiler runtimes. Sampling does not guarantee that a
regression is estimable, connected, or unbiased; those properties also depend
on the model, missing data, identifying variation, and the sampling design.

```stata
. xsamplefe 10, absorb(worker firm year)                      // 10% of the workers, all their spells
. xsamplefe 10, absorb(worker firm year) unit(firm)           // 10% of the firms
. xsamplefe 50, absorb(idcode year) balanced                  // balanced panel, 50% of the units
. xsamplefe 5,  absorb(worker firm) movers(100) stayers(5) connected
. xsamplefe 20, group(patent_id) individual(inventor_id)      // whole patents / teams
. xsamplefe 10, by(region)                                    // exactly what -sample 10, by(region)- draws
. xsamplefe 10, absorb(worker firm) mobstrata generate(s)     // proportional mobility classes, no rows deleted
. xsamplefe 10, absorb(worker firm) connectivity              // how connected the frame and the sample are
. xsamplefe 10, absorb(worker firm) reconnect                 // grow the largest component back (costs size)
. xsamplefe 10, absorb(worker firm) minmovers(2)              // drop firms with fewer than 2 movers (cascades)
```

## Install the latest release

In Stata 14 or newer, run:

```stata
net install xsamplefe, from("https://github.com/reisportela/xsamplefe/releases/latest/download") replace
discard
help xsamplefe
```

This address always selects the **latest stable release**. Run the same command
again to update. Stata selects the binary for Linux x86-64, Windows x86-64,
macOS Apple Silicon, or macOS Intel. No compiler is needed; Mac releases include
OpenMP, and Windows compiler runtimes are linked statically. See
[INSTALL.md](INSTALL.md) for system requirements and local installation.
Drawing samples does not require `reghdfe` or `xhdfe`.

Get the installation check and self-contained examples into the current folder:

```stata
net get xsamplefe, from("https://github.com/reisportela/xsamplefe/releases/latest/download")
do xsamplefe_check.do
do xsamplefe_basics.do
do xsamplefe_tour.do
```

The tutorials start with `clear`; save your work before running them.
For offline installation or sharing with colleagues, download the
[standalone ZIP for all four platforms](https://github.com/reisportela/xsamplefe/releases/latest/download/xsamplefe.zip).
It includes the binaries, help, examples, source and build script. Platform-specific
ZIPs and SHA-256 checksums are also on the
[latest release page](https://github.com/reisportela/xsamplefe/releases/latest).

## The command at a glance

`xsamplefe` is one pipeline. Every stage decides *which units are drawn*; only
the last one touches your data.

```
+- 1  FRAME - which rows are in play
|
|   if/in          rows outside are kept, never drawn
|   unit           unit(), else group(), else the first absorb()
|   split units    any pulls them in, all pushes them out; default: error
|
|- 2  ELIGIBLE - which units may be drawn
|
|   panel          balanced minperiods() maxperiods() minobs() maxobs()
|   mobility       minmobility() maxmobility()
|                  ineligible units are dropped, and counted
|
|- 3  STRATA - how the draw is split
|
|   by()           strata, which must be constant within units
|   mobstrata      one stratum per mobility class of the unit
|   rates          movers() and stayers(): one rate for each class
|
|- 4  DRAW - int(n*#/100+.5) units per stratum
|
|   #              a percentage, or a number of units with count
|   seed()         the r-th smallest unit value takes the r-th uniform
|
|- 5  AFTER THE DRAW - retention rules
|
|   grouprule()    keep a group if any (default) or all of its units were drawn
|   reconnect      grow the largest component back to the frame's share
|   minmovers()    drop values with too few movers, and their units
|   connected      keep only the largest connected component
|
+- 6  RESULT - what you get back

      generate()     a 0/1 indicator; without it the rows are deleted
      connectivity   components and movers per value, frame and sample
      r()            every count above; verbose times each phase
```

Stages 1 to 4 are the sample. Stage 5 is the only place where a unit that was
*not* drawn can come back (`grouprule(any)`, `reconnect`) or a unit that *was*
drawn can leave (`minmovers()`, `connected`), which is why the stored results
count the units drawn and the units retained separately.

When `group()` differs from `unit()`, complete groups take priority. Units can
be partially retained and ineligible units can return through a kept group;
check `r(N_units_partial)` and `r(N_units_ineligible_retained)`.

| what you want | what to add |
|---|---|
| exactly what `sample` draws | no sampling unit at all |
| whole workers | `absorb()`, or `unit()` |
| whole firms | `unit(firm)` |
| whole patents with their teams | `group()` `individual()` |
| a balanced panel | `balanced` |
| proportional mobility classes | `mobstrata` |
| a variance decomposition | `movers(100)` `stayers(#)` |
| a connected sample | `connected`, `reconnect` |
| firms with enough movers | `minmovers(#)` |
| an indicator instead of deleting | `generate()` |

## Features

```
xsamplefe # [if] [in] [, options]        # is a percentage, or a count with -count-
by varlist: xsamplefe # [, options]      same as by(varlist)
```

| Group | Options |
|---|---|
| Main | `count`, `by(varlist)` (missing values form their own stratum), `generate(newvar)` / `keep(newvar)` indicator instead of deleting, `replace`, `seed(#)` |
| Sampling unit | `absorb(absvars)` in `reghdfe` syntax (`i.`, `#`, `##`, `name=var`, `fe#c.x`; first entry = unit, first other entry = mobility dimension), `group(varname)`, `individual(varname)` / `i(varname)`, `unit(varname)` (numeric or string) |
| Panel structure | `time(varname)` (default: the `xtset` time variable), `balanced`, `minperiods(#)`, `maxperiods(#)`, `minobs(#)`, `maxobs(#)` |
| Mobility structure | `mobility(varname)`, `minmobility(#)`, `maxmobility(#)`, `movers(#)`, `stayers(#)`, `mobstrata`, `connectivity`, `connected`, `minmovers(#)`, `reconnect` / `recontarget(#)` / `reconrule(gain|key)` |
| `if`/`in` and groups | `any`, `all` (units split by `if`/`in`; strict = error by default), `grouprule(any|all)` |
| Performance | `numthreads(#)` (0 = runtime default; `r(threads_used)` reports the team formed), `verbose` (per-phase timings), `pduplicates(#)` (number of uniform key columns, as in `sample`) |

Stored results (`r()`): retained / frame / outside / ineligible observations,
units in the frame / eligible / ineligible / sampled / retained / partially
retained, movers eligible / sampled / retained, units split by `if`/`in`,
strata, periods, mobility values covered, groups kept, the components of the
unit-mobility graph on the frame and on the sample with the share of rows,
units and mobility values in the largest one, the movers per mobility value and
the share of mobility values with at most one mover (all with `connectivity`),
what `reconnect` added, what `minmovers()` and `connected` dropped, thread
diagnostics, `r(rngstate)` before drawing and the dimensions used. See `help xsamplefe` for the complete list and semantics.

## Contract

- Without a sampling unit, `xsamplefe # [if] [, by() count]` retains exactly the
  observations that `sample # [if] [, by() count]` retains under the same seed
  and data order, and leaves the random-number generator in the same state.
- With a unit (`unit()`, `group()`, or the first `absorb()` variable), whole
  units are kept or dropped unless a different `group()` applies group closure.
  The random keys depend only on the seed and on the set of
  unit values, never on the physical order of the rows, and never on the number
  of threads.
- `any`/`all` resolve units split by `if`/`in` as in `sample2`; `generate()`
  (alias `keep()`) returns an indicator instead of deleting rows.
- Eligibility filters: `balanced`, `minperiods()`, `maxperiods()`, `minobs()`,
  `maxobs()`, `minmobility()`, `maxmobility()`; separate rates for movers and
  stayers; `connected` keeps the largest unit-mobility component; with
  `group()` the rows of a group are never separated (`grouprule(any|all)`).
- Unlike `sample`, `in` may be combined with `by()`: `xsamplefe` never sorts
  the data, so the range is well defined and rows outside it are kept.

## Mobility fidelity

Whole-unit sampling keeps every spell of a drawn unit, so the mobility of every
retained unit (distinct firms, transitions) is the one in its frame, provided
group closure does not make units partial. A simple random unit sample estimates
the eligible population's mobility shares; unequal rates and subsequent retention
rules change the design. It does not guarantee the exact composition of the
full dataset, nor that the sample stays
connected. To hold the mobility classes close to the population, stratify by the
number of distinct mobility values per unit — `mobstrata` does it natively:

```stata
. xsamplefe 10, absorb(worker firm year) mobstrata
* the same draw, built by hand:
. bysort worker firm: gen byte first = _n == 1 & !missing(firm)
. bysort worker: egen int nfirms = total(first)
. xsamplefe 10, absorb(worker firm year) by(nfirms)
```

The allocation is proportional with `sample`'s rounding, `int(n*#/100+.5)` per
class, so a class with few units can be rounded down to zero: the shares are
reproduced closely, not exactly.

`movers(100) stayers(#)` keeps every mover (best precision for the firm
effects, mover share over-represented by design); `connected` restricts the
sample to its largest connected component and reports how much was dropped.
Observation-level sampling (`sample`) and sampling of the other dimension
(`unit(firm)`) destroy the mobility structure; `unit(firm) group(worker)`
restores the full histories of every worker touched by a sampled firm at the
price of over-representing movers. `tests/xsamplefe_mobility_cert.do` exercises
these cases; [validation scope](docs/VALIDATION.md) describes the test boundaries.

## Connectivity

`connectivity` reports the components of the bipartite unit-mobility graph on
the eligible frame and on the final sample: `r(N_components_frame)`,
`r(lcc_share_frame)`, `r(N_components)`, `r(lcc_share)`, `r(lcc_units_share)`,
`r(lcc_mobility_share)` and `r(N_units_lcc_kept)`. It also reports the movers
per mobility value, `r(movers_per_mob_frame)` and `r(movers_per_mob)`, and the
share of mobility values with at most one mover, `r(weak_mob_share_frame)` and
`r(weak_mob_share)`. It is opt-in — each graph costs a serial union-find over
every frame row. `connected`, `reconnect` and `minmovers()` build the same
graphs and report the components without the option; the movers per mobility
value cost one further pass, so only `connectivity` and `minmovers()` compute
them.

Keeping whole units preserves the mobility of each unit but not the network: on
`patents` the largest component covers 76.0% of the frame rows and 0.8% of the
rows of a 10% unit sample; on `synthetic-assortative`, 69.0% against 0.1%.

`reconnect` is the explicit remedy. After the draw it adds eligible units that
were not drawn and that touch the current largest component, until the largest
component reaches the share it has in the frame, or the share given in
`recontarget(#)`. `reconrule(gain)`, the default, takes the unit that joins the
most rows first (ties by the unit's own uniform key); `reconrule(key)` takes
the frontier in that key's order, i.e. in random order.

**It costs size and composition, and the cost is large.** The gain rule prefers
the units that join the most rows, that is the hubs. Added units may also be
stayers: they can raise the component's row share without bridging components.
The target may be unattainable after the frontier is exhausted.
Measured on a 10% unit draw (`absorb(id1 id2)`,
`set seed 1`):

| dataset | 10% draw | after `reconnect` | added | mean mobility values per unit | movers |
|---|---|---|---|---|---|
| patents (500,008 rows, 101,837 units) | 50,241 rows, 10,184 units, largest component 0.8% | 106,639 rows, 15,518 units, 76.0% | 5,334 units / 56,398 rows | 4.91 (pop) / 4.93 -> 6.87 | 0.918 (pop) / 0.920 -> 0.947 |
| synthetic-assortative (499,155 rows) | 49,446 rows, 12,610 units, 0.1% | 101,386 rows, 19,726 units, 69.0% | 7,116 units / 51,940 rows | 1.56 (pop) / 1.55 -> 1.98 | 0.403 (pop) / 0.399 -> 0.601 |
| enron (367,662 rows) | 37,595 rows, 3,669 units, 96.2% | 63,462 rows, 3,704 units, 98.4% | 35 units / 25,867 rows | 10.02 (pop) / 10.25 -> 17.13 | 0.694 (pop) / 0.690 -> 0.693 |

So a `#` percent request can come back at roughly twice `#` percent of the rows
(2.1x on the first two, 1.7x on `enron` from only 35 hub units), with a higher
mean mobility and mover share; the population class shares are not preserved.
`recontarget(#)` is the lever — a target below `r(lcc_share_frame)` stops the
growth earlier.

`reconrule(key)` trades size for composition. Both rules reach the same target
(10% draw, `absorb(id1 id2)`, `set seed 1`, 16 threads):

| dataset | rule | rows | units (added) | mean mobility values per unit | movers | time |
|---|---|---:|---|---:|---:|---:|
| patents (pop 4.910, 0.918) | `gain` | 106,639 | 15,518 (+5,334) | 6.872 | 0.947 | 10.5 s |
| | `key` | 124,331 | 22,304 (+12,120) | 5.574 | 0.951 | 16.0 s |
| synthetic-assortative (pop 1.556, 0.403) | `gain` | 101,386 | 19,726 (+7,116) | 1.981 | 0.601 | 2.0 s |
| | `key` | 114,629 | 26,863 (+14,253) | 1.802 | 0.542 | 4.1 s |
| enron (pop 10.020, 0.694) | `gain` | 63,462 | 3,704 (+35) | 17.133 | 0.693 | 0.2 s |
| | `key` | 66,517 | 6,241 (+2,572) | 10.658 | 0.711 | 4.2 s |

`key` is closer to the population mean mobility on all three (most visibly on
`enron`) and to its mover share on `synthetic-assortative`; `gain` gives 5-17%
fewer rows and is faster (up to 20x on `enron`), and is slightly closer on the
mover share of `patents` and `enron`. Neither dominates, so `gain` stays the
default.

`reconnect` also ignores the `by()` strata: the units it adds come from the
whole frontier, so the per-stratum counts stop being exact and
`r(N_units_reconnected)` / `r(N_reconnected)` are totals, not broken down by
stratum. All of it is reported, not hidden.

See `help xsamplefe` for the full syntax, semantics and stored results.

## Limited mobility bias

Whole-unit sampling preserves selected histories, not the exact moments of the
full population. Sampling variation, eligibility restrictions, unequal rates,
and connectivity rules can all change the resulting variance decomposition.
Under the AKM model's exogeneity and identification assumptions, individual
effects can be unbiased while plug-in variances and covariances remain biased
by estimation noise. Sparse mobility can inflate `Var(psi_hat)` and depress
`Cov(alpha_hat, psi_hat)`; movers per firm are a useful diagnostic, not a
sufficient condition for unbiased estimation. See Bonhomme, Manresa and Lamadon,
[The ABC of AKM](https://arxiv.org/abs/2603.17034) (2026). In the repository's
calibrated simulation (6,000 workers, 300 firms, 5 periods), each design estimated
on its own connected set:

| design | rows | movers/firm | Var(psi) true | Var(psi) AKM | 2Cov true | 2Cov AKM |
|---|---:|---:|---:|---:|---:|---:|
| population | 30,000 | 30.3 | 0.096 | 0.101 | 0.190 | 0.182 |
| 25% of workers | 7,500 | 7.7 | 0.097 | 0.116 | 0.190 | 0.157 |
| 10% of workers | 2,925 | 3.2 | 0.098 | 0.166 | 0.196 | 0.109 |
| 10% of rows (`sample`) | 1,738 | 2.1 | 0.087 | 0.440 | 0.177 | −0.338 |
| `movers(100) stayers(10)` | 19,735 | 30.3 | 0.089 | 0.093 | 0.139 | 0.133 |

In this simulation the true columns barely move across simple unit samples.
The AKM columns do: the
estimated `Var(psi)` is 5% above the truth on the full data, 20% at a quarter
of the workers, 70% at a tenth, and five times the truth when the same number
of *rows* is drawn instead of units, with a covariance that changes sign. So a
unit sample can preserve useful identifying variation, but coefficients still
require the model's assumptions and an appropriate variance estimator.
Keeping every mover (`movers(100) stayers(#)`) retains more information about
firm effects while changing inclusion probabilities and the target composition.
The small variance bias here is not a general guarantee or a bias correction. `minmovers(#)`
drops the mobility values with fewer than `#` movers and the units linked to
them, iterating to a fixed point; it removes the noisiest firms but not the
bias, and because units are indivisible the pruning cascades and can empty the
sample (`minmovers(2)` drops 46 of 300 units on that panel, `minmovers(3)`
leaves nothing and says so). `tests/xsamplefe_estimation_cert.do` fixes these
numbers.

## Worked examples

[xsamplefe_basics.do](stata/xsamplefe_basics.do) is a short course on row and
worker samples, indicators, counts, strata, `if`, balance, and estimation.
[xsamplefe_tour.do](stata/xsamplefe_tour.do) covers mobility, connectivity,
pruning, and patents with multiple inventors. Both generate artificial data,
need no downloads or additional packages, and can be read block by block.
They start with `clear`, so save any unsaved work first.

```stata
do "/path/to/xsamplefe/stata/xsamplefe_basics.do"
do "/path/to/xsamplefe/stata/xsamplefe_tour.do"
```

After a net installation, use the `net get` command in the installation section
above to retrieve the tutorials and `xsamplefe_check.do` into the current directory.

## Build from source

The release binaries are built online by GitHub Actions on Linux, Windows,
Mac Intel and Mac ARM runners. Each runner loads its plugin and exercises the
Stata plugin interface, including OpenMP, before packaging. Native Stata
certification is performed separately on the Linux release binary.

To build your own binary, use the matching command on a machine with the required
compiler and SDK:

```bash
bash stata/tools/build-xsamplefe-plugin.sh --linux
bash stata/tools/build-xsamplefe-plugin.sh --windows
bash stata/tools/build-xsamplefe-plugin.sh --macos-arm64
bash stata/tools/build-xsamplefe-plugin.sh --macos-intel
```

Then install from the checkout or extracted ZIP:

```stata
net install xsamplefe, from("/path/to/xsamplefe/stata") replace
discard
```

For session-only use, build with `--output stata/xsamplefe.plugin`, then:

```stata
adopath ++ "/path/to/xsamplefe/stata"
discard
```

Compiled binaries are release assets and are not stored in Git. Each build
target gets a separate filename in `stata/`; `net install` selects the matching
one and installs it as `xsamplefe.plugin`. [INSTALL.md](INSTALL.md) has the
per-platform compiler requirements and explains certification on a new machine.
The Stata plugin interface files (`stplugin.h`/`stplugin.c`) are bundled, so
the build works offline once the compiler/OpenMP prerequisites are installed.
OpenMP is the default on every target. A Mac build requires macOS and its SDK;
the script does not provide a Mac cross-compiler on Linux.

## Tests and validation

```bash
bash tests/run_tests.sh                     # needs Stata, reghdfe and sample2
XSAMPLEFE_BUILD_PLUGIN=1 bash tests/run_tests.sh
XHDFE_ADOPATH=/path/to/xhdfe/stata bash tests/run_tests.sh   # adds the reghdfe/xhdfe comparison
bash tests/selftest.sh                      # checks that the harness reports a failure
```

`run_tests.sh` first lints the help file (no SMCL source line over 160 bytes,
balanced braces on every line): Stata's GUI Viewer truncates lines at 245
characters and a cut inside a directive garbles the rest of the page, which
`translate` does not detect.

`tests/selftest.sh` is the self-test of the harness: it runs `run_tests.sh`
once with `XSAMPLEFE_SELFTEST=1`, which injects
`tests/xsamplefe_selftest_fail.do` (one deliberately false assert) before the
real certification files, and requires that run to exit non-zero with a log
that lacks the success marker and contains "assertion is false"; then it runs
the normal path and requires exit 0 with the marker.
Each certification writes a new directory under `tests/output/`; an old log
can never supply the success marker. `XSAMPLEFE_FIXTURE_DIR` can point to a
directory containing the public `nlswork.dta` to run the suite without downloads.
The suite runs with `set varabbrev off`; the explicit abbreviation test enables
abbreviations only for that comparison.

The certification has six parts. `xsamplefe_cert.do` checks bit-identity
with `sample` (rows and RNG state), whole-unit integrity, thread and row-order
invariance, balanced panels, mobility rates and bounds, `group()`/`individual()`
closure, frame rules and expected errors. `xsamplefe_compat_cert.do` compares
`xsamplefe` with `sample2` (same rows at the observation level, same frames
under `any`/`all`/strict, same number of clusters per stratum with `cluster()`,
same errors, documented differences), with further `sample` cases (`in`,
missing and string strata, `by` prefix, `pduplicates()`), with a pure-Stata
reference implementation of the unit draw, and with `splitsample` and
`bsample` cluster designs. `xsamplefe_estimation_cert.do` checks that
regressions on a unit sample reproduce the full-data regression: on a synthetic
AKM panel with known beta, a 20% worker sample keeps the fixed-effect
structure (no singletons) and is unbiased, 100 Monte Carlo draws are centred
on the full-data estimate with calibrated standard errors, an observation-level
sample of the same size is noisier, and `xhdfe` equals `reghdfe` on the sample
when available. `xsamplefe_mobility_cert.do` certifies the mobility structure
of the sample: every retained unit keeps exactly its population mobility
(distinct firms, transitions), the mover share and the mobility-class shares
are unbiased, stratifying by the number of distinct mobility values per unit
(`by(nmob)`, `mobstrata`) reproduces the class counts with `sample`'s
rounding, and observation-level or other-dimension sampling visibly destroys
mobility. It also certifies the connectivity diagnostics against a pure-Stata
component computation and `reconnect` on a deliberately sparse graph.
`xsamplefe_adversarial_cert.do` adds parser regressions, failed-call RNG
restoration, 140 native-sample comparisons, actual 1/8/48-thread teams, and a
disconnected all-stayer case where reconnect cannot attain its target.
`xsamplefe_binding_cert.do` verifies missing binaries, changed plugin locations,
and rebinding after `discard`, in copies under the run's output directory.
Statistical assertions in these files concern the particular simulated designs;
they do not establish unbiased estimation for arbitrary data or models.
Local benchmark datasets, exploratory tests and audit working notes are excluded
from Git. See [validation scope and limitations](docs/VALIDATION.md) for the
published test contract. This is a GitHub distribution; SSC submission is deferred.

## Author and license

Miguel Portela (Universidade do Minho / NIPE). MIT license. `sample2` is by
Jeroen Weesie; the observation-level semantics follow StataCorp's `sample`.
