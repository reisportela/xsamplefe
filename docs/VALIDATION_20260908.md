# xsamplefe 1.0.0 — validation record (08sep2026)

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
- Synthetic 20M-row panel (2M workers, 200k firms, 10 years): 3.4 s at 48
  threads, 5.7 s at 1 thread; `sample 10` on the same data: 5.8 s.
- `g++ -Wall -Wextra -Wshadow -fsyntax-only` on the plugin: no warnings.

## Known limitations

- The Windows static build (`--windows`) is implemented but was not exercised
  on this host (no mingw-w64 toolchain).
- `by varlist, sort:` is not reproducible for `sample` nor for `xsamplefe`,
  because Stata's `sort` orders ties arbitrarily before the uniforms are drawn;
  use `by()` or `sort, stable`.
