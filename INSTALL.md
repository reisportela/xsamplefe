# xsamplefe 1.2.0 — installing on another machine

## Contents of the archive

| path | what |
|---|---|
| `stata/xsamplefe.ado`, `xsamplefe.sthlp`, `xsamplefe.pkg`, `stata.toc` | the command, its help and the net-install descriptors |
| `stata/xsamplefe.plugin` | compiled Linux x86-64 plugin (GCC 11, OpenMP) |
| `stata/src/xsamplefe_plugin.cpp`, `stata/tools/` | the single source file, the build script and the bundled Stata plugin interface (`_deps/stplugin.{h,c}`, `mingw_stdio_shim.h`); no other dependency |
| `tests/` | certification suite (`run_tests.sh` → `testall.do` → four `*_cert.do`), harness self-test (`selftest.sh`) |
| `README.md`, `docs/VALIDATION_20260908.md` | overview, contracts, validation record |

## 1. Make the command visible to Stata

Either add the folder to the ado-path for the session

```stata
adopath ++ "/path/to/xsamplefe-1.2.0/stata"
```

or install it permanently

```stata
net install xsamplefe, from("/path/to/xsamplefe-1.2.0/stata") replace
```

`xsamplefe` loads `xsamplefe.plugin` from the same folder as `xsamplefe.ado`.
After replacing the plugin in a running session type `discard`.

## 2. The plugin binary

### Linux (shipped binary)

`stata/xsamplefe.plugin` was built on AlmaLinux 9 with GCC 11.5 and needs at
run time only `libgomp.so.1`, `libstdc++.so.6` (GCC 11 or newer:
`GLIBCXX_3.4.29`), `libgcc_s.so.1` and glibc 2.14 or newer. Check with

```bash
ldd stata/xsamplefe.plugin
```

If a library is missing or too old, rebuild (a few seconds; needs `g++` with
OpenMP, i.e. any recent GCC or Clang with `libgomp`/`libomp`):

```bash
bash stata/tools/build-xsamplefe-plugin.sh --linux --openmp
ldd stata/xsamplefe.plugin | grep libgomp        # must be present
```

`XHDFE_STATIC_GNU_LIBS=1` before the command embeds `libstdc++`/`libgcc`
(requires the static libraries, e.g. `libstdc++-static` on RHEL-like systems).

### macOS

Xcode command line tools (`xcode-select --install`). Default build: universal
binary (x86-64 + arm64), OpenMP off (single thread, same results):

```bash
bash stata/tools/build-xsamplefe-plugin.sh
```

With OpenMP (recommended for large data): `brew install libomp`, then

```bash
bash stata/tools/build-xsamplefe-plugin.sh --openmp
```

which builds for the host architecture only. `LIBOMP_PREFIX=/path` if `brew`
is not on the PATH.

### Windows

Native, in an MSYS2 MINGW64 shell (`pacman -S mingw-w64-x86_64-gcc zip`):

```bash
bash stata/tools/build-xsamplefe-plugin.sh --windows
```

or cross-compiled from Linux/WSL (`apt-get install g++-mingw-w64-x86-64`):

```bash
bash stata/tools/build-xsamplefe-plugin.sh --windows
```

The Windows plugin links the GNU runtimes statically, so no DLL has to ship
next to it (`objdump -p xsamplefe.plugin | grep DLL` shows only system DLLs).

The macOS and Windows paths of the build script have not been exercised on
the packaging host (no macOS, no mingw-w64 there); report any failure with
the script's output.

## 3. Certification on the new machine

Needs Stata (MP/SE), `reghdfe` (`ssc install reghdfe`) and `sample2`
(`net install dm46, from(http://www.stata.com/stb/stb37)`); `xhdfe` is optional
(`XHDFE_ADOPATH=/path/to/xhdfe/stata` enables the reghdfe/xhdfe comparison).

```bash
STATA_BIN=stata-mp bash tests/run_tests.sh      # must end with the success marker
bash tests/selftest.sh                          # proves the harness fails on a failing assert
```

`XSAMPLEFE_BUILD_PLUGIN=1 bash tests/run_tests.sh` rebuilds the plugin first.
The mobility certification runs an extra block on the core-23 benchmark
datasets when `XSF_SERGIO_DIR` points at them; otherwise it prints "skipped".

## 4. First runs on real data

```stata
. use bigpanel, clear
. xtset worker year
. set seed 1
. xsamplefe 10, absorb(worker firm year) connectivity generate(s)   // 10% of workers, all spells; graph diagnostics in r()
. return list
. xsamplefe 10, absorb(worker firm year) mobstrata generate(s2)     // proportional mobility classes
. xsamplefe 10, absorb(worker firm year) reconnect generate(s3)     // largest component back to the frame share (sample grows)
. xsamplefe 10, absorb(worker firm year) minmovers(2) generate(s4)  // drop firms with fewer than 2 movers (cascades)
. xsamplefe 5,  absorb(worker firm year) movers(100) stayers(5) connected   // all movers, 5% stayers, largest component
. reghdfe y x if s == 1, absorb(worker firm year)
. xhdfe   y x if s == 1, absorb(worker firm year)
```

Whole units are always kept or dropped together; the draw depends only on the
seed and the set of unit values (not on row order or threads); without a
sampling unit the rows are exactly those of `sample`. `r(lcc_share_frame)`
versus `r(lcc_share)` tells how much of the connected structure the sample
kept; `reconnect` restores the frame's share at the cost of a larger sample
that over-represents large units (numbers in `help xsamplefe`, Connectivity).
