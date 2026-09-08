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
