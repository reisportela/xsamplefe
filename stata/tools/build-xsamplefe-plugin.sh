#!/usr/bin/env bash
# Build from the bundled SDK. No downloads, installers, or system changes.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATA_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DEPS_DIR="${SCRIPT_DIR}/_deps"

usage() {
  cat <<'EOF'
Usage: build-xsamplefe-plugin.sh [target] [options]

Targets (default: this host):
  --linux            Linux x86-64, GCC with OpenMP
  --windows          Windows x86-64, MSYS2 UCRT64/MINGW64 or a MinGW-w64 cross compiler
  --macos-arm64      macOS Apple Silicon, Apple Clang and ARM64 libomp
  --macos-intel      macOS Intel, Apple Clang and x86-64 libomp
  --macos            macOS, architecture of the current shell

Options:
  --arch ARCH        x86_64 or arm64; arm64 is supported only for macOS
  --output FILE      output .plugin path; default: stata/xsamplefe_<platform>.plugin
  --openmp           OpenMP on (default for every target; production builds)
  --no-openmp        serial diagnostic build
  --march-native     Linux-only CPU tuning; do not redistribute that binary
  --no-march-native  disable CPU tuning (default)
  --dry-run          print the build plan without invoking the compiler or writing files
  --help             show this help without writing files

Environment:
  CXX                compiler executable (not a shell command with arguments)
  LIBOMP_PREFIX      macOS libomp prefix; otherwise read from brew --prefix libomp
  LIBOMP_PREFIX_ARM64 / LIBOMP_PREFIX_X86_64
                     architecture-specific overrides, including cross-architecture Mac builds
  XSAMPLEFE_STATIC_GNU_LIBS=1
                     Linux: static libstdc++/libgcc; libgomp/glibc remain dynamic
  XSAMPLEFE_TARGET / XSAMPLEFE_OPENMP / XSAMPLEFE_ENABLE_MARCH_NATIVE
                     defaults overridden by explicit options

Legacy XHDFE_* defaults remain accepted. Windows GNU runtimes are linked statically.
Mac builds require macOS and the Xcode command line tools; Linux cannot substitute
for a Mac SDK. A Mac libomp library must contain the requested architecture.
Existing output files are backed up in the printed build directory before replacement.
After net install, run discard in Stata before using a newly built plugin.
EOF
}

fail() { echo "Error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"; }
print_command() { printf '  '; printf '%q ' "$@"; printf '\n'; }

TARGET="${XSAMPLEFE_TARGET:-${XHDFE_TARGET:-}}"
OPENMP_MODE="${XSAMPLEFE_OPENMP:-${XHDFE_OPENMP:-on}}"
MARCH_NATIVE_MODE="${XSAMPLEFE_ENABLE_MARCH_NATIVE:-${XHDFE_ENABLE_MARCH_NATIVE:-off}}"
ARCH=""
OUT_PLUGIN=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --linux) TARGET=linux; shift ;;
    --windows|--win|--win64) TARGET=windows; shift ;;
    --macos) TARGET=macos; shift ;;
    --macos-arm64) TARGET=macos; ARCH=arm64; shift ;;
    --macos-intel) TARGET=macos; ARCH=x86_64; shift ;;
    --arch|--output)
      [[ $# -ge 2 && -n "$2" ]] || fail "$1 requires a value"
      if [[ "$1" == --arch ]]; then ARCH="$2"; else OUT_PLUGIN="$2"; fi
      shift 2 ;;
    --openmp) OPENMP_MODE=on; shift ;;
    --no-openmp) OPENMP_MODE=off; shift ;;
    --march-native|--native) MARCH_NATIVE_MODE=on; shift ;;
    --no-march-native) MARCH_NATIVE_MODE=off; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1 (use --help)" ;;
  esac
done

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"
if [[ -z "$TARGET" ]]; then
  case "$UNAME_S" in
    Linux) TARGET=linux ;; # WSL is Linux unless --windows is explicitly requested.
    Darwin) TARGET=macos ;;
    MINGW*|MSYS*|CYGWIN*) TARGET=windows ;;
    *) fail "unsupported host: $UNAME_S" ;;
  esac
fi
case "$TARGET" in linux|windows|macos) ;; *) fail "invalid target: $TARGET" ;; esac
case "$OPENMP_MODE" in on|1|ON|true|yes) OPENMP_MODE=on ;; off|0|OFF|false|no) OPENMP_MODE=off ;; *) fail "invalid OpenMP mode: $OPENMP_MODE" ;; esac
case "$MARCH_NATIVE_MODE" in on|1|ON|true|yes) MARCH_NATIVE_MODE=on ;; off|0|OFF|false|no) MARCH_NATIVE_MODE=off ;; *) fail "invalid CPU tuning mode: $MARCH_NATIVE_MODE" ;; esac
if [[ -z "$ARCH" ]]; then
  if [[ "$TARGET" == macos ]]; then ARCH="$UNAME_M"; else ARCH=x86_64; fi
fi
case "$ARCH" in x86_64|amd64) ARCH=x86_64 ;; arm64|aarch64) ARCH=arm64 ;; *) fail "unsupported architecture: $ARCH" ;; esac
[[ "$TARGET" == macos || "$ARCH" == x86_64 ]] || fail "$TARGET Stata builds require x86_64"
[[ "$MARCH_NATIVE_MODE" == off || "$TARGET" == linux ]] || fail "--march-native is supported only on Linux"
if [[ "$DRY_RUN" == 0 ]]; then
  case "$TARGET:$UNAME_S" in
    linux:Linux|windows:Linux|windows:MINGW*|windows:MSYS*|windows:CYGWIN*|macos:Darwin) ;;
    *) fail "cannot build $TARGET on $UNAME_S with this script; use a native toolchain for that target" ;;
  esac
fi

SYSTEM_DEF=OPUNIX
LINK_MODE=-shared
case "$TARGET" in
  linux) PLATFORM=linux64; CXX="${CXX:-g++}" ;;
  windows)
    PLATFORM=win64; SYSTEM_DEF=STWIN32
    if [[ -z "${CXX:-}" ]]; then
      case "$UNAME_S" in MINGW*|MSYS*) CXX=g++ ;; *) CXX=x86_64-w64-mingw32-g++ ;; esac
    fi ;;
  macos)
    SYSTEM_DEF=APPLEMAC; LINK_MODE=-bundle; CXX="${CXX:-clang++}"
    if [[ "$ARCH" == arm64 ]]; then PLATFORM=macarm64; else PLATFORM=macintel64; fi ;;
esac
if [[ -z "$OUT_PLUGIN" ]]; then OUT_PLUGIN="${STATA_DIR}/xsamplefe_${PLATFORM}.plugin"; fi
[[ "$OUT_PLUGIN" == /* ]] || OUT_PLUGIN="${PWD}/${OUT_PLUGIN}"
[[ "$OUT_PLUGIN" == *.plugin ]] || fail "--output must name a .plugin file"

compile_flags=( -std=c++17 -O3 -DNDEBUG "-DSYSTEM=${SYSTEM_DEF}" -I"${DEPS_DIR}" )
link_flags=( "$LINK_MODE" )
case "$TARGET" in
  linux) compile_flags+=( -m64 -fPIC -pthread ); link_flags+=( -pthread ) ;;
  windows)
    compile_flags[0]=-std=gnu++17
    compile_flags+=( -m64 -include "${SCRIPT_DIR}/mingw_stdio_shim.h" )
    link_flags+=( -static -static-libgcc -static-libstdc++ -Wl,--no-insert-timestamp ) ;;
  macos) compile_flags+=( -arch "$ARCH" -fPIC -pthread ); link_flags+=( -pthread ) ;;
esac
if [[ "$MARCH_NATIVE_MODE" == on ]]; then compile_flags+=( -march=native -mtune=native ); fi
OMP_PREFIX=""
if [[ "$OPENMP_MODE" == on ]]; then
  if [[ "$TARGET" == macos ]]; then
    if [[ "$ARCH" == arm64 ]]; then OMP_PREFIX="${LIBOMP_PREFIX_ARM64:-${LIBOMP_PREFIX:-}}"
    else OMP_PREFIX="${LIBOMP_PREFIX_X86_64:-${LIBOMP_PREFIX:-}}"; fi
    if [[ -z "$OMP_PREFIX" && "$DRY_RUN" == 0 ]] && command -v brew >/dev/null 2>&1; then
      OMP_PREFIX="$(brew --prefix libomp 2>/dev/null || true)"
    fi
    if [[ -z "$OMP_PREFIX" ]]; then
      if [[ "$DRY_RUN" == 1 ]]; then OMP_PREFIX="<libomp-prefix-for-${ARCH}>"
      else fail "install libomp for $ARCH and set LIBOMP_PREFIX (or use Homebrew)"; fi
    fi
    compile_flags+=( -Xpreprocessor -fopenmp -I"${OMP_PREFIX}/include" )
    link_flags+=( "${OMP_PREFIX}/lib/libomp.dylib" -Xlinker -rpath -Xlinker "${OMP_PREFIX}/lib" )
  else
    compile_flags+=( -fopenmp ); link_flags+=( -fopenmp )
  fi
fi
if [[ "$TARGET" == linux && "${XSAMPLEFE_STATIC_GNU_LIBS:-${XHDFE_STATIC_GNU_LIBS:-0}}" =~ ^(1|ON|on|true|yes)$ ]]; then
  link_flags+=( -static-libstdc++ -static-libgcc )
fi

SRC="${STATA_DIR}/src/xsamplefe_plugin.cpp"
STPLUGIN_C="${DEPS_DIR}/stplugin.c"
echo "Target: ${PLATFORM}; architecture: ${ARCH}; OpenMP: ${OPENMP_MODE}"
echo "Output: ${OUT_PLUGIN}"
if [[ "$DRY_RUN" == 1 ]]; then
  print_command "$CXX" "${compile_flags[@]}" -x c++ "$STPLUGIN_C" -x none "$SRC" "${link_flags[@]}" -o "$OUT_PLUGIN"
  echo "Plan only: compiler, SDK, runtime architecture and resulting binary have not been validated."
  exit 0
fi

need "$CXX"
[[ -f "$SRC" && -f "$STPLUGIN_C" && -f "${DEPS_DIR}/stplugin.h" ]] || fail "incomplete source archive: bundled C++ source and stplugin.{h,c} are required"
if [[ "$TARGET" == windows ]]; then
  [[ -f "${SCRIPT_DIR}/mingw_stdio_shim.h" ]] || fail "bundled Windows stdio shim is missing"
  case "$("$CXX" -dumpmachine)" in x86_64*mingw*) ;; *) fail "Windows requires an x86_64 MinGW-w64 compiler (MSYS2 UCRT64/MINGW64 or cross compiler)" ;; esac
  if [[ -z "${OBJDUMP:-}" ]]; then
    if command -v x86_64-w64-mingw32-objdump >/dev/null 2>&1; then OBJDUMP=x86_64-w64-mingw32-objdump
    else OBJDUMP=objdump; fi
  fi
  need "$OBJDUMP"
elif [[ "$TARGET" == macos ]]; then
  need lipo; need otool
  if [[ "$OPENMP_MODE" == on ]]; then
    [[ -f "${OMP_PREFIX}/include/omp.h" && -f "${OMP_PREFIX}/lib/libomp.dylib" ]] || fail "libomp headers/library missing under $OMP_PREFIX"
    lipo -verify_arch "$ARCH" "${OMP_PREFIX}/lib/libomp.dylib" || fail "libomp does not contain $ARCH; select the matching LIBOMP_PREFIX"
  fi
else
  need readelf
fi
if [[ "$OPENMP_MODE" == on ]]; then
  definitions="$("$CXX" "${compile_flags[@]}" -dM -E -x c++ - < /dev/null)"
  [[ "$definitions" == *'#define _OPENMP '* ]] || fail "compiler did not enable OpenMP; refusing a serial production build"
fi
[[ ! -L "$OUT_PLUGIN" && ! -L "${OUT_PLUGIN}.build.txt" ]] || fail "refusing a symlink output"
[[ ! -e "$OUT_PLUGIN" || -f "$OUT_PLUGIN" ]] || fail "output is not a regular file"
[[ ! -e "${OUT_PLUGIN}.build.txt" || -f "${OUT_PLUGIN}.build.txt" ]] || fail "build receipt is not a regular file"
OUT_DIR="$(dirname -- "$OUT_PLUGIN")"
mkdir -p "$OUT_DIR"
WORK_DIR="$(mktemp -d "${OUT_DIR}/.tmp-xsamplefe-${PLATFORM}.XXXXXX")"
echo "Build directory: ${WORK_DIR}"
"$CXX" "${compile_flags[@]}" -x c++ "$STPLUGIN_C" -x none "$SRC" "${link_flags[@]}" -o "${WORK_DIR}/xsamplefe.plugin"

case "$TARGET" in
  linux)
    header="$(LC_ALL=C readelf -h "${WORK_DIR}/xsamplefe.plugin")"
    [[ "$header" == *ELF64* && "$header" == *'Advanced Micro Devices X86-64'* ]] || fail "output is not Linux x86-64 ELF"
    if [[ "$OPENMP_MODE" == on ]]; then
      dynamic="$(LC_ALL=C readelf -d "${WORK_DIR}/xsamplefe.plugin")"
      [[ "$dynamic" == *libgomp* || "$dynamic" == *libomp* ]] || fail "output has no OpenMP runtime dependency"
    fi ;;
  windows)
    header="$(LC_ALL=C "$OBJDUMP" -f "${WORK_DIR}/xsamplefe.plugin")"
    [[ "$header" == *pei-x86-64* ]] || fail "output is not a Windows x86-64 PE library"
    imports="$(LC_ALL=C "$OBJDUMP" -p "${WORK_DIR}/xsamplefe.plugin")"
    if printf '%s\n' "$imports" | grep -Ei 'DLL Name:.*(libgcc|libstdc\+\+|libgomp|libwinpthread|libquadmath|libssp|msys-2|cygwin1)' >/dev/null; then
      fail "Windows output depends on a non-static GNU/MSYS runtime"
    fi ;;
  macos)
    lipo -verify_arch "$ARCH" "${WORK_DIR}/xsamplefe.plugin"
    if [[ "$OPENMP_MODE" == on ]]; then
      dynamic="$(otool -L "${WORK_DIR}/xsamplefe.plugin")"
      [[ "$dynamic" == *libomp.dylib* ]] || fail "output has no libomp dependency"
    fi ;;
esac

# Keep exported plugin entry points; omit local/debug symbols from distribution.
if [[ -z "${STRIP_BIN:-}" ]]; then
  if [[ "$TARGET" == windows ]] && command -v x86_64-w64-mingw32-strip >/dev/null 2>&1; then
    STRIP_BIN=x86_64-w64-mingw32-strip
  else STRIP_BIN=strip; fi
fi
need "$STRIP_BIN"
if [[ "$TARGET" == macos ]]; then "$STRIP_BIN" -x "${WORK_DIR}/xsamplefe.plugin"
else "$STRIP_BIN" "${WORK_DIR}/xsamplefe.plugin"; fi

# Only validated build outputs replace a previous binary. Backups are retained.
if [[ -f "$OUT_PLUGIN" ]]; then cp -p "$OUT_PLUGIN" "${WORK_DIR}/previous.plugin"; fi
if [[ -f "${OUT_PLUGIN}.build.txt" ]]; then cp -p "${OUT_PLUGIN}.build.txt" "${WORK_DIR}/previous.build.txt"; fi
{
  printf 'platform=%s\narchitecture=%s\nopenmp=%s\nmarch_native=%s\n' "$PLATFORM" "$ARCH" "$OPENMP_MODE" "$MARCH_NATIVE_MODE"
  printf 'compiler='; "$CXX" --version | sed -n '1p'
  printf 'built_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
} > "${WORK_DIR}/build.txt"
mv "${WORK_DIR}/xsamplefe.plugin" "$OUT_PLUGIN"
mv "${WORK_DIR}/build.txt" "${OUT_PLUGIN}.build.txt"
echo "Done: ${OUT_PLUGIN}"
echo "Install using the package descriptor (net install), or explicitly build --output stata/xsamplefe.plugin for adopath use."
