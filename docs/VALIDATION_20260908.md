# xsamplefe 1.0.0 / 1.1.0 — validation record (08sep2026)

Host: shared 48-logical-processor Linux workstation (1 TB RAM), Stata/MP,
GCC 11.5, plugin built with `--linux --openmp`. All datasets below are the ones
used by the `xhdfe` certification and benchmark suites; the raw sweep outputs
are `benchmarks/results/sweep_core23_20260908.csv` and
`benchmarks/results/sweep_heavy_20260908.csv`.

## Checks performed on every dataset

- `det`: the 10 percent unit sample (unit = first absorbed variable) is
  identical with `numthreads(1)`, `numthreads(16)` and, for the heavy sets,
  `numthreads(48)`.
- `int`: every unit is retained or dropped as a whole.
- `par`: `xsamplefe 10` retains exactly the rows that `sample 10` retains under
  the same seed.
- `xhdfe` (and, up to 1M rows, `reghdfe`) run on the unit sample; `maxdiff` is
  the largest absolute coefficient difference between the two.

## Results

| dataset | rows | units | sampled | xsamplefe 16 thr (s) | 1 thr (s) | det | int | par | xsamplefe obs-level (s) | `sample` (s) | xhdfe N | reghdfe N | maxdiff |
|---|---:|---:|---:|---:|---:|:-:|:-:|:-:|---:|---:|---:|---:|---:|
| felsdvsimul | 100 | 20 | 2 | 0.01 | 0.00 | 1 | 1 | 1 | 0.00 | 0.00 | 8 | 8 | 2e-16 |
| toy_patents_chain | 6,656 | 261 | 26 | 0.00 | 0.01 | 1 | 1 | 1 | 0.00 | 0.00 | 1,184 | 1,184 | 3e-15 |
| credit2 | 19,094 | 601 | 60 | 0.01 | 0.01 | 1 | 1 | 1 | 0.00 | 0.00 | 1,862 | 1,862 | 8e-14 |
| soccer | 73,487 | 528 | 53 | 0.02 | 0.02 | 1 | 1 | 1 | 0.01 | 0.01 | 7,142 | 7,142 | 9e-16 |
| credit | 516,810 | 13,946 | 1,395 | 0.11 | 0.11 | 1 | 1 | 1 | 0.08 | 0.09 | 52,165 | 52,165 | 2e-14 |
| directors | 525,012 | 395,925 | 39,593 | 0.15 | 0.18 | 1 | 1 | 1 | 0.07 | 0.10 | 485 | 485 | 4e-14 |
| enron | 367,662 | 36,692 | 3,669 | 0.06 | 0.09 | 1 | 1 | 1 | 0.05 | 0.06 | 28,312 | 28,312 | 9e-15 |
| patents | 500,008 | 101,837 | 10,184 | 0.09 | 0.15 | 1 | 1 | 1 | 0.09 | 0.09 | 1,521 | 1,521 | 2e-12 |
| synthetic-complete | 500,000 | 1,000 | 100 | 0.09 | 0.10 | 1 | 1 | 1 | 0.10 | 0.09 | 50,000 | 50,000 | 7e-15 |
| synthetic-uniform-easy | 500,000 | 216,007 | 21,601 | 0.10 | 0.12 | 1 | 1 | 1 | 0.10 | 0.10 | 43,129 | 43,129 | 1e-14 |
| synthetic-uniform-hard | 500,000 | 122,702 | 12,270 | 0.11 | 0.19 | 1 | 1 | 1 | 0.07 | 0.09 | 5,181 | 5,181 | 1e-11 |
| synthetic-assortative | 499,155 | 126,101 | 12,610 | 0.12 | 0.19 | 1 | 1 | 1 | 0.08 | 0.12 | 42,682 | 42,682 | 8e-14 |
| github | 548,843 | 27,970 | 2,797 | 0.11 | 0.13 | 1 | 1 | 1 | 0.08 | 0.13 | 52,609 | 52,609 | 6e-13 |
| schools | 413,444 | 206,722 | 20,672 | 0.10 | 0.12 | 1 | 1 | 1 | 0.09 | 0.08 | 36,778 | 36,778 | 4e-11 |
| workers | 504,315 | 28,864 | 2,886 | 0.10 | 0.13 | 1 | 1 | 1 | 0.09 | 0.09 | 56,203 | 56,203 | 2e-11 |
| pf_difficult_1m | 1,000,000 | 100,000 | 10,000 | 0.34 | 0.28 | 1 | 1 | 1 | 0.17 | 0.23 | 100,000 | 100,000 | 9e-10 |
| pf_simple_10m | 10,000,000 | 1,000,000 | 100,000 | 2.94 | 3.94 | 1 | 1 | 1 | 1.91 | 3.77 | 1,000,000 | — | — |
| pf_difficult_10m | 10,000,000 | 1,000,000 | 100,000 | 3.10 | 3.85 | 1 | 1 | 1 | 2.05 | 3.46 | 1,000,000 | — | — |
| main_95_21_ready | 47,569,720 | 6,393,933 | 639,393 | 10.01 | 15.45 | 1 | 1 | 1 | 6.85 | 20.75 | 4,551,799 | 4,551,799 | 2e-13 |
| akm_v02_firstreg | 57,821,050 | 7,705,610 | 770,561 | 16.9 (13.3 @48) | 20.7 | 1 | 1 | 1 | 10.3 | 21.0 | 5,533,175 | — | — |
| akm_v02_secondreg (data) | 57,821,050 | 7,705,610 | 770,561 | 14.7 (11.3 @48) | 14.7 | 1 | 1 | 1 | 9.0 | 24.6 | 5,533,175 | — | — |
| simulated_panel | 173,163,263 | 20,000,000 | 2,000,000 | 29.2 (29.6 @48) | 64.8 | 1 | 1 | 1 | 29.5 | 52.7 | 17,311,387 | — | — |

The AKM firstreg and secondreg files hold the same rows in different column
orders; both draw the same 770,561 workers, as implied by the row-order
invariance of unit sampling.

## Marta's group()/individual() data (core24, 3,000,000 rows, 1,200,000 groups)

`benchmarks/marta_group_individual.do` and `marta_group_individual_reg.do`
(16 threads, `set seed 1`):

| variant | command | rows retained | xsamplefe (s) | estimable? |
|---|---|---:|---:|---|
| A | 10% of groups | 300,476 | 0.89 | no: 83,340 singletons, df < 0 in both reghdfe and xhdfe |
| B | 10% of firms `unit(ntrab)` | 317,025 | 0.78 | no: df < 0 |
| C | 10% of individuals `unit(p_ntrab)`, closure `any` | 779,905 | 0.74 | yes: reghdfe = xhdfe (F 537.0 vs 537.2; coefficients to 1e-6) |
| D | 10% of groups, `by(year) minmobility(2) maxmobility(4)` | 278,332 | 0.77 | — |
| E | 10% of groups, `connected` | 96 | 0.67 | 86,383 components; the graph shatters |
| F | 5% of individuals, `movers(20) stayers(2)` | 1,273,561 | 0.90 | — |
| G | 10% of individuals, `grouprule(all)` | 4,788 obs after singletons | — | tiny |

Thread determinism (1/8/48) and whole-group integrity held in every variant.

## Other checks

- `tests/xsamplefe_cert.do`: bit-identity with `sample` (auto, nlswork with
  `if`+`by()`, `count by()`), RNG state preserved, `generate()`/`keep()`, unit
  integrity, thread and shuffle invariance, string identifiers, `balanced`
  (explicit and `xtset` time), period and observation bounds, `movers()`/`stayers()`
  rates, `minmobility()`/`maxmobility()`, `connected`, synthetic patents with
  `group()`/`individual()` (closure, `i()` alias, team bounds, `count` per
  stratum), strict/`any`/`all` frame rules and expected errors — PASS.
- `tests/xsamplefe_compat_cert.do`: `sample2` (STB-37 dm46) draws the same
  rows as `xsamplefe` at the observation level (its `uniform()` under
  `version 5.0` still uses mt64 because Stata picks the generator from
  `c(userversion)`), including `if`, `keep()`, and `by()` on data sorted by
  the strata; with `cluster()` the frames under `any`/`all`/strict are
  identical (checked at 0 percent), the number of clusters per stratum is
  the same, and both refuse split clusters, non-constant `by()`, `any`+`all`
  and an existing `keep()` variable. Documented differences: `in` with
  `by()` is accepted by `xsamplefe` (it never sorts) and refused by
  `sample`/`sample2`; a missing cluster value is one more cluster for
  `sample2` and outside the frame for `xsamplefe`. A pure-Stata reference of
  the unit draw (r-th smallest unit takes the r-th `runiform()` pair)
  reproduces `xsamplefe` bit for bit (pct, `by()`, `count`, shuffled rows).
  `sample` parity extended to `in`, missing and string strata, `by` prefix
  and `pduplicates(1e-100)` (7 uniform columns, same RNG state).
  `splitsample, cluster()` / `balance()` and `bsample, cluster() strata()`
  give the same cluster counts per stratum as `xsamplefe unit() by()` on a
  100-cluster panel and reject non-nested strata as `xsamplefe` does — PASS.
- `tests/xsamplefe_estimation_cert.do` (synthetic AKM panel, 3,000 workers x
  8 years, 150 firms, beta = 1): full data b = 0.99713 (se 0.00692); 20% of
  the workers b = 0.99018 (se 0.01573), no singletons, `xhdfe` = `reghdfe`
  on the sample to 1e-8; 20% of the rows with `sample` b = 1.02542
  (se 0.02185) after 1,027 singletons dropped; `movers(100) stayers(20)
  connected` b = 0.99777 (se 0.00801). Monte Carlo of 100 seeds at 10% of
  the workers: bias 0.00004, sd 0.01864, mean se 0.02266, 99% of the draws
  cover the full-data estimate at +/- 1.96 se. nlswork 30% of the women:
  tenure and age within 3 se of the full-data estimates — PASS.
- `tests/xsamplefe_mobility_cert.do` (same AKM panel: 67.4% movers, 1.029
  transitions per worker, 150 firms; nlswork idcode x ind_code: 55.9%
  movers): a 20% worker sample keeps the per-unit mobility of every retained
  worker exactly (distinct firms and transitions), covers all 150 firms, and
  its mover share (0.663) and class shares are within 3 binomial se of the
  population; `by(nmob)` (nmob = distinct firms per worker) reproduces the
  class counts exactly, int(n*20/100+.5), movers 0.674, 1.027 transitions
  per worker; `movers(100) stayers(20)` keeps all movers by design; the 20%
  sample is one connected component, the 5% sample fragments into 16
  (reported by `connected`); `sample 20` (rows) collapses the mover share
  to 0.259 and the transitions to 0.286 per worker; 20% of the firms
  collapses it to 0.153, and `unit(firm) group(worker)` restores the full
  histories but over-represents movers (0.828). nlswork: same conclusions
  (plain 0.565 vs 0.559; `by(nmob)` exact) — PASS.
- Synthetic 20M-row panel (2M workers, 200k firms, 10 years): 3.4 s at 48
  threads, 5.7 s at 1 thread; `sample 10` on the same data: 5.8 s.
- `g++ -Wall -Wextra -Wshadow -fsyntax-only` on the plugin: no warnings.

## 1.1.0 (08sep2026): audit fixes, connectivity diagnostics and `reconnect`

The measurements above were taken with 1.0.0 and still hold: on `credit`,
`patents`, `enron` and `synthetic-assortative` the 10 percent unit sample drawn
by 1.1.0 is **bit-identical** to the one drawn by 1.0.0 (0 differing rows out of
516,810 / 500,008 / 367,662 / 499,155 under `set seed 20260908`), because the
new tie-break only changes the outcome when two units tie on the first uniform
key, which does not happen under `mt64`.

### Connectivity of the unit-mobility graph

Reported when `connectivity`, `connected` or `reconnect` is specified (opt-in:
each graph costs a serial union-find over every frame row, so the default path
does not build one): `r(N_components_frame)`, `r(lcc_share_frame)`,
`r(N_components)`, `r(lcc_share)`, `r(lcc_units_share)`,
`r(lcc_mobility_share)`, `r(N_units_lcc_kept)`; missing otherwise. Whole-unit
sampling preserves the mobility of each unit but not the network:

| dataset | rows | frame: components | frame: largest (rows) | 10% unit sample: largest | after `reconnect` | units added |
|---|---:|---:|---:|---:|---:|---:|
| credit | 516,810 | 1 | 100.00% | 100.00% | 100.00% (target met) | 0 |
| enron | 367,662 | 1,887 | 98.36% | 96.18% | 98.36% | 35 |
| synthetic-assortative | 499,155 | 33,042 | 68.98% | 0.11% | 68.98% | 7,116 |
| patents | 500,008 | 25,229 | 76.02% | 0.76% | 76.03% | 5,334 |
| synthetic AKM, sparse (3,000 workers, 1,500 firms, 8% mobility) | 18,000 | 357 | 67.40% | 1.67% | 67.58% | 360 |

The sparse synthetic panel is the one in `tests/xsamplefe_mobility_cert.do`; its
357 components and 67.40 percent share are verified against a pure-Stata label
propagation, exactly (`< 1e-12` on the share). `reconnect` is deterministic:
identical indicator with `numthreads(1)`, `numthreads(4)` and `numthreads(8)`
and after shuffling the rows. `recontarget(50)` stops at 50.0 percent;
`recontarget(1)` on a sample that already has 1.7 percent adds nothing and
returns the untouched sample.

### Size and composition cost of `reconnect`

`reconnect` grows the largest component by adding eligible units that were not
drawn, choosing first the unit that joins the most rows: by construction it
prefers the hubs, and every added unit is a mover. That is not free. Measured
on `xsamplefe 10, absorb(id1 id2)`, `set seed 1` (mobility values per unit
counted with `!missing(id2)`, movers = units with two or more of them):

| dataset | 10% draw | after `reconnect` | added | mean mobility values per unit (pop / draw -> reconnect) | mover share (pop / draw -> reconnect) |
|---|---|---|---|---|---|
| patents (500,008 rows, 101,837 units) | 50,241 rows, 10,184 units, largest component 0.76% | 106,639 rows, 15,518 units, 76.03% | 5,334 units, 56,398 rows | 4.910 / 4.933 -> 6.872 | 0.918 / 0.920 -> 0.947 |
| synthetic-assortative (499,155 rows, 126,101 units) | 49,446 rows, 12,610 units, 0.11% | 101,386 rows, 19,726 units, 68.98% | 7,116 units, 51,940 rows | 1.556 / 1.549 -> 1.981 | 0.403 / 0.399 -> 0.601 |
| enron (367,662 rows, 36,692 units) | 37,595 rows, 3,669 units, 96.18% | 63,462 rows, 3,704 units, 98.36% | 35 units, 25,867 rows | 10.020 / 10.247 -> 17.133 | 0.694 / 0.690 -> 0.693 |

A 10 percent request therefore comes back at about 21 percent of the rows on
the first two datasets and 17 percent on `enron` — where only 35 units were
added, all of them hubs. The mean mobility per unit and the mover share rise
visibly, so the population composition is **not** preserved; `recontarget(#)`
below `r(lcc_share_frame)` is the lever that trades connectivity for size.

### `reconrule(gain)` versus `reconrule(key)`

`reconrule()` chooses which frontier unit is added next: `gain` (default) the
one that joins the most rows, `key` the one with the smallest uniform key, that
is in random order. Both reach the same target. Same three datasets, 10 percent
draw, `absorb(id1 id2)`, `set seed 1`, 16 threads, frame share as the target:

| dataset | rule | rows | units | added units | added rows | mean mobility values / unit | mover share | largest component | time |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| patents (pop 4.910 / 0.918) | `gain` | 106,639 | 15,518 | 5,334 | 56,398 | 6.872 | 0.947 | 76.03% | 10.5 s |
| | `key` | 124,331 | 22,304 | 12,120 | 74,090 | 5.574 | 0.951 | 76.04% | 16.0 s |
| synthetic-assortative (pop 1.556 / 0.403) | `gain` | 101,386 | 19,726 | 7,116 | 51,940 | 1.981 | 0.601 | 68.98% | 2.0 s |
| | `key` | 114,629 | 26,863 | 14,253 | 65,183 | 1.802 | 0.542 | 68.98% | 4.1 s |
| enron (pop 10.020 / 0.694) | `gain` | 63,462 | 3,704 | 35 | 25,867 | 17.133 | 0.693 | 98.36% | 0.2 s |
| | `key` | 66,517 | 6,241 | 2,572 | 28,922 | 10.658 | 0.711 | 98.39% | 4.2 s |

`key` is closer to the population mean number of mobility values per unit on
**all three** datasets (10.658 against 17.133 on `enron`, whose population is
10.020) and closer to the population mover share on
`synthetic-assortative` (0.542 against 0.601, population 0.403); `gain` returns
5-17 percent fewer rows, is 1.6x to 20x faster, and is marginally closer on the
mover share of `patents` (0.947 against 0.951, population 0.918) and `enron`
(0.693 against 0.711, population 0.694). **Neither rule dominates on all three,
so `gain` remains the default**; `key` is the right choice when the composition
of the sample matters more than its size.

Run time of the greedy under the default rule: 0.27 s on `enron`, 3.6 s on
`synthetic-assortative`, 11.3 s on `patents` in the earlier timing run
(0.2 / 2.0 / 10.5 s in the table above), against 0.16-0.30 s for the plain
call.

`reconnect` ignores the `by()` strata by design: the frontier is not restricted
to the stratum of the fragment being joined, so the per-stratum counts stop
being `int(n*#/100+.5)` and `r(N_units_reconnected)` / `r(N_reconnected)` are
totals, not broken down by stratum. This is documented in the help (Connectivity
and Options) and in the README, and was not changed.

### Cost of the diagnostics, and why they are opt-in

The first 1.1.0 implementation computed the two graphs on every call with a
mobility dimension. Interleaved A/B pairs then showed +7 percent on `credit`
and +15 percent on `patents` (`verbose` on `patents`: 16 ms for the frame graph
and 6 ms for the sample graph against about 110 ms of plugin work), which
violates contract 7. The diagnostics were therefore made opt-in
(`connectivity`, or implied by `connected` / `reconnect`) and the default path
was measured again, interleaved, three pairs of three repetitions
(`xsamplefe 10, absorb(id1 id2) numthreads(16)`, mean of the two warm
repetitions of each run):

| dataset | rows | 1.0.0 median | 1.1.0 default median | change | per-pair range |
|---|---:|---:|---:|---:|---|
| credit | 516,810 | 0.1185 s | 0.1180 s | **-0.4%** | -4.8% .. +2.1% |
| patents | 500,008 | 0.1395 s | 0.1415 s | **+1.4%** | -5.5% .. +5.9% |

Six interleaved pairs, five repetitions each, the first (cold) repetition of
every run discarded; medians over the 24 remaining timings per arm. The
per-pair differences straddle zero on both datasets, so the residual is inside
the noise of this shared host — the default path is back to the 1.0.0 cost.
`verbose` on `patents` confirms it: without the option there is no
`frame connectivity` and no `sample connectivity` phase; with `connectivity`
they cost 16.5 ms and 6.1 ms. `connected` itself became slightly cheaper than
in 1.0.0, because the component pass was fused with the graph build.

### Behaviour changes of 1.1.0

- `generate()`/`keep()` refuse reserved names, match existing variables exactly
  and build the indicator in a temporary variable before dropping the old one,
  so no name can destroy data (`generate(_all)` used to run `drop _all`).
- An empty frame (`if 0`, all unit values missing, zero observations) now
  produces the indicator (1 everywhere) and the full `r()` instead of exiting
  silently; the RNG is still untouched, as in `sample`.
- The `time()` variable is resolved before the default mobility dimension, so
  `absorb(worker year firm) balanced` picks `firm` whether the time comes from
  `xtset` or from `time(year)`.
- `absorb()` names are expanded with `unab`, and `c.(x z)` / `##(c.x c.z)`
  slope terms parse.
- Unit-mode ties on the first uniform key are broken by a hash of that key and
  of the unit rank instead of the later uniform columns, so the draw no longer
  depends on the number of rows (reproduced under `set rng kiss32` with
  1,000,000 units).
- Observation-mode parity with `sample` now also holds under `version 13, user`
  (two `float` columns).
- `connected` unites the units of a group, so the cut never splits a group.
- `balanced` (or `minperiods()`) with no non-missing period leaves no unit
  eligible, with a note.
- `movers()`/`stayers()` counts must be integers below 2^31; a count above the
  stratum keeps the stratum whole.
- `minobs()` and friends reject negative values (the `-1` sentinel is internal)
  and no longer answer to `min()`/`max()`.
- The plugin fails with a clear message instead of overflowing when the number
  of observations, of strata or of units plus mobility values exceeds
  2,147,483,647; the ado refuses datasets of 2^31 observations or more.
- The `r()` transport uses a `tempname` prefix, so user scalars named
  `__xsf_*` survive.
- The connectivity diagnostics are opt-in (`connectivity`, or implied by
  `connected` / `reconnect`); without them the seven `r()` are missing, the
  `connectivity:` line is not printed and no graph is built.
- New: `mobstrata`, `connectivity`, `reconnect`, `recontarget(#)`,
  `reconrule(gain|key)`, the `r()` listed above plus `r(N_units_partial)`,
  `r(N_units_ineligible_retained)` and the macro `r(reconrule)`.

### Certification

`bash tests/run_tests.sh` passes (45-50 s wall on this host, StataNow/MP 19.5),
and `bash tests/selftest.sh` passes: with `XSAMPLEFE_SELFTEST=1` the harness
runs `tests/xsamplefe_selftest_fail.do` (one deliberately false assert) before
the real certification files, `run_tests.sh` then exits 1, the log lacks the
success marker and contains "assertion is false"; the normal run that follows
exits 0 with the marker. Without the variable nothing changes.
Added to the four existing files: reserved/exact `generate()` names and data
integrity, empty frames, group-closure diagnostics and `connected` over groups,
`absorb()` abbreviations and `c.(x z)`, option domains, `group()` equal to the
unit, `__xsf_*` scalar safety, `time()` resolution and `balanced` with no
period, `sample` parity under `version 13, user`, the `kiss32` tie-break
invariance (1,000,000 units, one duplicated row, 1 and 8 threads), the
connectivity diagnostics (present with `connectivity`, missing without it)
against a pure-Stata component computation,
`reconnect` (target, determinism, whole units, no-op when the target is met),
`reconrule(key)` (same target, its own determinism over 1/8 threads and
shuffled rows), `mobstrata` equal to `by(nmob)`, and an optional block over
`XSF_SERGIO_DIR` (`patents`, `synthetic-assortative`, `enron`) that prints
"skipped" when the datasets are absent. Two vacuous asserts were replaced
(`assert r(N_outside) > 0` after an rclass helper, and
`assert r(n_components) >= 1`). The benchmark sweeps now write a
`name,ERROR,rc=#` row for every case that fails or whose data is missing:
that is how `synthetic-zigzag` and `synthetic-uniform-harder` disappeared from
the 1.0.0 CSV — both give `reghdfe`/`xhdfe` r(2001), insufficient observations,
on their 10 percent unit sample.

### Benchmark sweeps rerun with 1.1.0

`benchmarks/results/sweep_core23_20260908_v110.csv` and
`sweep_heavy_20260908_v110.csv` (same host, same day, 16 threads). Every
count is identical to the 1.0.0 CSVs on every dataset: rows, units, units
sampled, rows of the unit sample, `det`, `int`, `par`, `xhdfe` and `reghdfe`
N, and `maxdiff` to the last digit. The two previously silent cases now
appear as `synthetic-zigzag,ERROR,rc=2001` and
`synthetic-uniform-harder,ERROR,rc=2001`. Timings differ in both directions
and are not comparable between the two runs: the core-23 rerun overlapped
with other Stata jobs on the host (`sample` itself is 20-50 percent slower in
that CSV), and the heavy sets move by -20 to +12 percent on the same call
(`akm_v02_firstreg` 16 threads 16.9 -> 14.5 s, `simulated_panel` 29.2 -> 32.7 s
at 16 threads but 29.6 -> 28.5 s at 48 and 64.8 -> 53.6 s at 1). The
interleaved A/B pairs above are the evidence for invariant 7.

### The 2^31 guards, executed

One-off run (not part of the certification) on this host:

- `set obs 2147483647` (one byte variable), `xsamplefe 10`: rc 198,
  "datasets with 2,147,483,647 or more observations are not supported by the
  plugin", RNG state unchanged, before any uniform is drawn.
- `set obs 1073741824` with `unit(u) mobility(m)` where every row is its own
  unit and its own mobility value (`U + M = 2,147,483,648`, fewer than 2^31
  rows): rc 198, "the number of units plus mobility values (2147483648)
  exceeds the 2,147,483,647 limit of this plugin's 32-bit indices", after
  109 s of reading and ranking.

## Known limitations

- The Windows static build (`--windows`, cross or native MSYS2) and the macOS
  builds (universal without OpenMP; host-arch with Homebrew `libomp`) are
  implemented in the build script but were not exercised on this host (no
  mingw-w64 toolchain, no macOS). `INSTALL.md` documents them.
- `XHDFE_STATIC_GNU_LIBS=1` (embed `libstdc++`/`libgcc`) needs the static
  libraries, absent on this host; the shipped Linux binary needs a GCC 11 or
  newer `libstdc++` at run time.
- `by varlist, sort:` is not reproducible for `sample` nor for `xsamplefe`,
  because Stata's `sort` orders ties arbitrarily before the uniforms are drawn;
  use `by()` or `sort, stable`. In unit mode the draw itself is invariant to the
  row order, so only the prefix's own sort is at stake.
- `reconnect` may not be combined with a `group()` closure: groups are
  indivisible and adding a unit could split one. The command refuses it.
- `reconnect` ignores the `by()` strata, so the per-stratum counts after it are
  no longer `int(n*#/100+.5)`; they are reported.
- The 2^31 guards were executed once (section above); they are not part of
  the certification because the datasets take minutes and tens of GB.
