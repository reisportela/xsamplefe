# xsamplefe — installation and optional compilation

## Install or update from GitHub

In Stata 14 or newer:

```stata
net install xsamplefe, from("https://github.com/reisportela/xsamplefe/releases/latest/download") replace
discard
help xsamplefe
```

The URL follows the latest stable release; it is not tied to a version number.
Stata selects the correct binary automatically. No compilation is needed.
The release includes Linux x86-64, Windows x86-64, Mac Intel and Mac ARM plugins,
built and tested through the plugin interface on their native GitHub runners.
Actual Stata validation is currently on Linux (StataNow/MP 19.5); the minimum
Stata version declaration is not certification on every older Stata release.

Retrieve the installation check and tutorials into the current directory:

```stata
net get xsamplefe, from("https://github.com/reisportela/xsamplefe/releases/latest/download")
do xsamplefe_check.do
do xsamplefe_basics.do
do xsamplefe_tour.do
```

The check restores current data and RNG. The tutorials start with `clear`, so
save your work before running them. When downloading these do-files again,
preserve any local edits and use a new folder, or deliberately add `replace`.

## Offline installation

Download [xsamplefe.zip](https://github.com/reisportela/xsamplefe/releases/latest/download/xsamplefe.zip)
and extract it. This standalone archive includes all four binaries and the
Mac OpenMP runtimes. It can be shared with colleagues without a source checkout.
The release page also offers smaller ZIPs for each individual platform and
`SHA256SUMS.txt` for verifying downloads.

## Contents of the archive

| path | what |
|---|---|
| `stata/xsamplefe.ado`, `xsamplefe.sthlp`, `xsamplefe.pkg`, `stata.toc` | the command, its help and the net-install descriptors |
| `stata/xsamplefe_*.plugin` | compiled plugins for Linux, Windows, Mac Intel and Mac ARM |
| `stata/xsamplefe_libomp_*.dylib` | bundled Mac OpenMP runtimes, installed beside the plugin |
| `stata/xsamplefe_basics.do`, `stata/xsamplefe_tour.do` | self-contained courses using artificial data |
| `stata/xsamplefe_check.do` | short installation check; restores current data and RNG |
| `stata/xsamplefe_license.txt` | MIT license included in net installations |
| `stata/src/xsamplefe_plugin.cpp`, `stata/tools/` | the single source file, the build script and the bundled Stata plugin interface (`_deps/stplugin.{h,c}`, `mingw_stdio_shim.h`); no other dependency |
| `tests/` (source checkout) | reusable certification; the ZIP carries the standalone check and tutorials |
| `README.md`, `INSTALL.md`, `LICENSE`, `stata/RELEASE.json` | instructions, license and source/build identity |

### Make the extracted command visible to Stata

Install from the extracted folder. The descriptor
selects the platform-specific binary and installs it as `xsamplefe.plugin`:

```stata
net describe xsamplefe, from("/path/to/xsamplefe/stata")
net install xsamplefe, from("/path/to/xsamplefe/stata") replace
discard
```

Replace the example path with the actual extracted folder, including `stata`.
For session-only adopath use in a source checkout, build with
`--output stata/xsamplefe.plugin`, then run:

```stata
adopath ++ "/path/to/xsamplefe/stata"
discard
```

`xsamplefe` loads `xsamplefe.plugin` from the same folder as `xsamplefe.ado`.
After replacing the plugin in a running session type `discard`.

The descriptor refuses installation when the required platform binary is absent.
The ZIP does not include Stata or compilers. On Windows, use forward slashes
in the path, for example `C:/Users/yourname/Downloads/xsamplefe/stata`.

Retrieve the example do-files separately (save any unsaved data first):

```stata
net get xsamplefe, from("/path/to/xsamplefe/stata")
do xsamplefe_check.do
do xsamplefe_basics.do
do xsamplefe_tour.do
```

## System requirements and optional source builds

The source checkout contains the C++17 source, build script and bundled Stata
plugin SDK. Once the compiler and OpenMP prerequisites are installed, the build
script works offline and performs no downloads or software installations.

### Linux x86-64

The release build uses AlmaLinux 9 and GCC 11 in GitHub Actions. Use an
environment with glibc 2.34 or newer and GCC 11-compatible runtime libraries:
`libgomp.so.1`, `libstdc++.so.6`, and `libgcc_s.so.1`. Check with:

```bash
ldd stata/xsamplefe_linux64.plugin
```

If a runtime is older, build from source with a C++17/OpenMP compiler on that
machine; the script defaults to GCC:

```bash
bash stata/tools/build-xsamplefe-plugin.sh --linux --openmp
ldd stata/xsamplefe_linux64.plugin | grep libgomp
```

`XSAMPLEFE_STATIC_GNU_LIBS=1` before the command embeds `libstdc++`/`libgcc`
(requires the static libraries, e.g. `libstdc++-static` on RHEL-like systems).

### macOS

The release targets macOS 14 or newer on Apple Silicon and macOS 15 or newer
on Intel. Choose the architecture of **Stata**, including Intel when running
Intel Stata through Rosetta. The release bundles an architecture-matched OpenMP
runtime, relocated to load beside the plugin; Homebrew is not needed to use it.

For an optional source build, run on macOS with its SDK:

Use the Xcode command line tools (`xcode-select --install`) and an OpenMP runtime
matching the architecture of Stata. With Homebrew already installed,
`brew install libomp` provides the native runtime. Build Apple Silicon with:

```bash
bash stata/tools/build-xsamplefe-plugin.sh --macos-arm64
```

Build Intel with:

```bash
bash stata/tools/build-xsamplefe-plugin.sh --macos-intel
```

Outputs are `xsamplefe_macarm64.plugin` and `xsamplefe_macintel64.plugin` in
`stata/`. `--macos` chooses the current shell's architecture. For Intel Stata
under Rosetta, explicitly choose Intel and supply an Intel libomp.
`LIBOMP_PREFIX` overrides Homebrew discovery; `LIBOMP_PREFIX_ARM64` and
`LIBOMP_PREFIX_X86_64` take precedence for their respective targets.
The script checks libomp's architecture with `lipo` before compiling, and checks
the plugin architecture and runtime dependency afterwards. Mac builds need
macOS and its SDK; a Linux Clang installation is not sufficient.

### Windows

The release targets 64-bit Windows 10 or newer and statically links GNU/OpenMP
runtimes. It does not require MSYS2 or a compiler to run.

For an optional source build:

Native, in an MSYS2 **UCRT64** shell with `mingw-w64-ucrt-x86_64-gcc`, or a
MINGW64 shell with `mingw-w64-x86_64-gcc`:

```bash
bash stata/tools/build-xsamplefe-plugin.sh --windows
```

or cross-compiled from Linux/WSL (`apt-get install g++-mingw-w64-x86-64`):

```bash
bash stata/tools/build-xsamplefe-plugin.sh --windows
```

The result is `stata/xsamplefe_win64.plugin`. The script verifies the compiler
target and the PE x86-64 output, links GNU runtimes statically, and rejects GNU/MSYS
runtime DLL imports. Stata itself can run normally from the Windows desktop;
use MSYS2 only for the compilation. Linux/WSL is treated as Linux by default;
cross-compilation always requires the explicit `--windows` option.

All release binaries come from the GitHub Actions workflow, which loads and
exercises each plugin natively before packaging it. This does not replace
testing inside Stata on Windows and Mac; run `xsamplefe_check.do` there and
report the OS, Stata version, xsamplefe version and reproducible command if it fails.

All four targets use OpenMP by default. `--no-openmp` is for serial diagnosis;
`--march-native` is Linux-only and unsuitable for binaries sent to other machines.
`--output` chooses an explicit .plugin destination. Builds use temporary files
on the destination filesystem, validate the result, and retain a backup of any
previous output before replacement. The script performs no downloads or installs.

## Certification on the new machine

The ZIP's `xsamplefe_check.do` and tutorials need only Stata and
xsamplefe. The source checkout's full suite additionally needs
`reghdfe` (`ssc install reghdfe`) and `sample2`
(`net install dm46, from(http://www.stata.com/stb/stb37)`); `xhdfe` is optional
(`XHDFE_ADOPATH=/path/to/xhdfe/stata` enables the reghdfe/xhdfe comparison).

```bash
STATA_BIN=stata-mp bash tests/run_tests.sh      # must end with the success marker
bash tests/selftest.sh                          # proves the harness fails on a failing assert
```

`XSAMPLEFE_BUILD_PLUGIN=1 bash tests/run_tests.sh` rebuilds the plugin first.
Every run has a new log directory under `tests/output/`. The self-test checks
injected assertion failures, stale logs, and a command that never starts Stata.
For offline tests, set `XSAMPLEFE_FIXTURE_DIR` to a directory containing the
official public `nlswork.dta`; existing assertions remain unchanged.

The mobility certification runs an extra block on the core-23 benchmark
datasets when `XSF_SERGIO_DIR` points at them; otherwise it prints "skipped".

## First runs on real data

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

Whole units are kept or dropped together unless a different `group()` applies
group closure; that rule preserves groups and can leave units partial.
The random keys depend only on the
seed and the set of unit values (not on row order or threads); without a
sampling unit the rows are exactly those of `sample`. `r(lcc_share_frame)`
versus `r(lcc_share)` tells how much of the connected structure the sample
kept; `reconnect` restores the frame's share at the cost of a larger sample
that over-represents large units (numbers in `help xsamplefe`, Connectivity).
