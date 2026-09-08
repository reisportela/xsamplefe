# xsamplefe

`xsamplefe` draws random samples of panel / fixed-effect data for
[`reghdfe`](https://github.com/sergiocorreia/reghdfe) and
[`xhdfe`](https://github.com/reisportela/xhdfe-xfe) in Stata. It is a superset
of Stata's `sample` and of Weesie's `sample2` (STB-37 dm46): instead of drawing
observations it can draw whole *units* (workers, firms, patents, ...) so that
the fixed-effect structure of the sample stays estimable, and it adds strata,
balanced-panel and mobility filters, connected sets and `reghdfe`'s
`group()`/`individual()` designs. The work is done by a C++17/OpenMP plugin with
no external dependencies.

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
```

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
| Mobility structure | `mobility(varname)`, `minmobility(#)`, `maxmobility(#)`, `movers(#)`, `stayers(#)`, `mobstrata`, `connectivity`, `connected`, `reconnect` / `recontarget(#)` / `reconrule(gain|key)` |
| `if`/`in` and groups | `any`, `all` (units split by `if`/`in`; strict = error by default), `grouprule(any|all)` |
| Performance | `numthreads(#)` (0 = runtime default; `r(threads_used)` reports the team formed), `verbose` (per-phase timings), `pduplicates(#)` (number of uniform key columns, as in `sample`) |

Stored results (`r()`): retained / frame / outside / ineligible observations,
units in the frame / eligible / ineligible / sampled / retained / partially
retained, movers eligible / sampled / retained, units split by `if`/`in`,
strata, periods, mobility values covered, groups kept, the components of the
unit-mobility graph on the frame and on the sample with the share of rows,
units and mobility values in the largest one (with `connectivity`), what
`reconnect` added, what
`connected` dropped, thread diagnostics, `r(rngstate)` before drawing and the
dimensions used. See `help xsamplefe` for the complete list and semantics.

## Contract

- Without a sampling unit, `xsamplefe # [if] [, by() count]` retains exactly the
  observations that `sample # [if] [, by() count]` retains under the same seed
  and data order, and leaves the random-number generator in the same state.
- With a unit (`unit()`, `group()`, or the first `absorb()` variable), whole
  units are kept or dropped. The draw depends only on the seed and on the set of
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
retained unit (distinct firms, transitions) is exactly the one in the population
and the shares of movers and of the mobility classes are unbiased. It does not
guarantee the exact composition of the sample, nor that the sample stays
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
price of over-representing movers. `tests/xsamplefe_mobility_cert.do` and
`docs/VALIDATION_20260908.md` quantify all of this.

## Connectivity

`connectivity` reports the components of the bipartite unit-mobility graph on
the eligible frame and on the final sample: `r(N_components_frame)`,
`r(lcc_share_frame)`, `r(N_components)`, `r(lcc_share)`, `r(lcc_units_share)`,
`r(lcc_mobility_share)` and `r(N_units_lcc_kept)`. It is opt-in — each graph
costs a serial union-find over every frame row — and `connected` and
`reconnect`, which need the same graphs, report them too; without one of the
three the seven results are missing.

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
the units that join the most rows, that is the hubs, and the added units are
movers by construction. Measured on a 10% unit draw (`absorb(id1 id2)`,
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

## Install

From a local checkout (or an unzipped release):

```stata
adopath ++ "/path/to/xsamplefe/stata"
```

or

```stata
net install xsamplefe, from("/path/to/xsamplefe/stata") replace
```

The plugin binary (`stata/xsamplefe.plugin`) is not versioned; build it once:

```bash
bash stata/tools/build-xsamplefe-plugin.sh --linux --openmp   # Linux (GCC/Clang + libgomp)
bash stata/tools/build-xsamplefe-plugin.sh                     # macOS: universal binary, OpenMP off
bash stata/tools/build-xsamplefe-plugin.sh --openmp            # macOS with Homebrew libomp (host arch)
bash stata/tools/build-xsamplefe-plugin.sh --windows           # mingw-w64: MSYS2 MINGW64 shell or cross build, static runtimes
```

`INSTALL.md` has the per-platform details (runtime requirements of a shipped
Linux binary, MSYS2 and WSL for Windows, `libomp` on macOS) and how to run the
certification on a new machine.

Requirements: a C++17 compiler with OpenMP (GCC/Clang; mingw-w64 for Windows).
The Stata plugin interface files (`stplugin.h`/`stplugin.c`) are bundled, so
the build works offline.

## Tests and validation

```bash
bash tests/run_tests.sh                     # needs Stata, reghdfe and sample2
XSAMPLEFE_BUILD_PLUGIN=1 bash tests/run_tests.sh
XHDFE_ADOPATH=/path/to/xhdfe/stata bash tests/run_tests.sh   # adds the reghdfe/xhdfe comparison
bash tests/selftest.sh                      # checks that the harness reports a failure
```

`tests/selftest.sh` is the self-test of the harness: it runs `run_tests.sh`
once with `XSAMPLEFE_SELFTEST=1`, which injects
`tests/xsamplefe_selftest_fail.do` (one deliberately false assert) before the
real certification files, and requires that run to exit non-zero with a log
that lacks the success marker and contains "assertion is false"; then it runs
the normal path and requires exit 0 with the marker. Without the variable,
`run_tests.sh` and `testall.do` behave exactly as before.

The certification has four parts. `xsamplefe_cert.do` checks bit-identity
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
`benchmarks/` contains the sweeps over the `xhdfe` core-23 /
core-24 benchmark datasets and `docs/VALIDATION_20260908.md` the results
(all datasets: determinism, integrity and parity OK; `reghdfe` and `xhdfe`
agree on the samples to 1e-9 or better — see the `max_b_diff` column of the
CSV; 173M rows sampled in 29 s).

## Author and license

Miguel Portela (Universidade do Minho / NIPE). MIT license. `sample2` is by
Jeroen Weesie; the observation-level semantics follow StataCorp's `sample`.
