# Reference audit of the unit-level pipeline

`tests/run_tests.sh` certifies `xsamplefe` with designs chosen by hand. This
directory adds a differential test: random designs, each one run by
`xsamplefe` and by a reference implementation written from the help file, and
every difference reported. It is separate from the certification and does not
replace it.

```bash
env -u LD_LIBRARY_PATH bash tests/audit/run_audit.sh 2000            # 2,000 mixed designs
env -u LD_LIBRARY_PATH bash tests/audit/run_audit.sh 2000 3 reconnect
```

The arguments are the number of designs, the seed of the designs and the
focus: `mixed` (default), `reconnect` (sparse graphs, small draws, `reconnect`
in every design), `prune` (`minmovers()` and `connected`) or `closure`
(`group()` different from the unit). `STATA_BIN` and `XSAMPLEFE_ADOPATH` are
read as in `tests/run_tests.sh`. It needs Stata 16 or newer (frames) and
`python3`; no other package. The run ends with `XSAMPLEFE AUDIT PASSED` and
exit status 0, or with the designs that differ and status 1.

## What is compared

| File | Role |
|---|---|
| `gen_cases.py` | draws the designs: data, command and options |
| `oracle.py` | the reference: frame, eligibility, strata, draw, group closure, `reconnect`, `minmovers()`, `connected`, stored results |
| `compare.py` | the retention indicator row by row, 45 stored results, the expected errors and the random-number state after an error |

The designs cover numeric, string, negative, non-integer and large unit
values, `absorb()` forms, `group()`/`individual()`, `if`, `in`, `any`/`all`,
`by()` with missing values, frequency weights, eligibility bounds, rates,
`mobstrata`, the graph options and thread counts from 1 to 48. The reference
takes the same uniform keys as the command (the first column drawn after
`set seed`), so the two must agree exactly.

## What it does not cover

- Observation-level sampling: the certification compares it with `sample`.
- Ties between uniform keys: the reference leaves those designs undecided
  (essentially none under `mt64`). The certification tests the tie rule.
- Large data: the reference recomputes the graph at every step, so the designs
  stay below a few hundred units.
- Platforms other than the one it runs on.

## Why it exists

An audit of 1.4.2 (29 September 2026) built 36 deliberate defects, one at a
time, and ran the certification on each. Five real defects passed it: the
bounds of `minmovers()` and `maxobs()`, the order in which `reconnect` takes
the frontier, `r(lcc_units_share)` and `r(N_movers_retained)`. This test
detected all five. The certification has since been extended and detects them
too; the random designs remain the broader net.
