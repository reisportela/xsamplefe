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
```

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
bash stata/tools/build-xsamplefe-plugin.sh --linux --openmp   # Linux / macOS
bash stata/tools/build-xsamplefe-plugin.sh --windows           # mingw-w64 cross build, static runtimes
```

Requirements: a C++17 compiler with OpenMP (GCC/Clang; mingw-w64 for Windows).
The Stata plugin interface files (`stplugin.h`/`stplugin.c`) are bundled, so
the build works offline.

## Tests and validation

```bash
bash tests/run_tests.sh                     # needs Stata and reghdfe
XSAMPLEFE_BUILD_PLUGIN=1 bash tests/run_tests.sh
```

The certification checks bit-identity with `sample` (rows and RNG state),
whole-unit integrity, thread and row-order invariance, balanced panels,
mobility rates and bounds, `group()`/`individual()` closure, frame rules and
expected errors. `benchmarks/` contains the sweeps over the `xhdfe` core-23 /
core-24 benchmark datasets and `docs/VALIDATION_20260908.md` the results
(all datasets: determinism, integrity and parity OK; `reghdfe` and `xhdfe`
agree on the samples to 1e-11 or better; 173M rows sampled in 29 s).

## Author and license

Miguel Portela (Universidade do Minho / NIPE). MIT license. `sample2` is by
Jeroen Weesie; the observation-level semantics follow StataCorp's `sample`.
