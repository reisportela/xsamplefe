#!/usr/bin/env bash
# Build the self-contained Stata plugin `xsamplefe.plugin` (panel / fixed-effect
# aware sampling). The plugin has no third-party dependencies: it needs only
# stplugin.{h,c} (bundled in _deps) and a C++17 compiler with OpenMP. On
# Windows the GNU runtimes (libgcc, libstdc++, libgomp, winpthread) are linked
# statically so that no DLL has to ship next to the plugin.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATA_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

BUILD_DIR="${SCRIPT_DIR}/_build"
DEPS_DIR="${SCRIPT_DIR}/_deps"
STPLUGIN_H="${DEPS_DIR}/stplugin.h"
STPLUGIN_C="${DEPS_DIR}/stplugin.c"
mkdir -p "${BUILD_DIR}" "${DEPS_DIR}"

download() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
    return
  fi
  echo "Error: neither curl nor wget is available to download $url" >&2
  exit 1
}

if [[ ! -f "${STPLUGIN_H}" ]]; then
  echo "Downloading stplugin.h..."
  download "https://www.stata.com/plugins/stplugin.h" "${STPLUGIN_H}"
fi
if [[ ! -f "${STPLUGIN_C}" ]]; then
  echo "Downloading stplugin.c..."
  download "https://www.stata.com/plugins/stplugin.c" "${STPLUGIN_C}"
fi

OUT_PLUGIN="${STATA_DIR}/xsamplefe.plugin"

usage() {
  cat <<'EOF'
Usage: build-xsamplefe-plugin.sh [--windows|--linux] [--openmp|--no-openmp] [--march-native]

Builds the Stata plugin `xsamplefe.plugin` next to xsamplefe.ado.

Targets:
  --windows    Build a Windows (PE/DLL) plugin using mingw-w64 (static GNU runtimes):
               cross build from Linux/WSL (apt-get install g++-mingw-w64-x86-64) or
               native build in an MSYS2 MINGW64 shell (pacman -S mingw-w64-x86_64-gcc).
  --linux      Build a Linux/macOS (ELF/Mach-O) plugin using the native toolchain
               (default when no target is given; macOS gives a universal binary).

OpenMP:
  --openmp     Enable OpenMP (default on Linux and Windows; production builds must
               use it). On macOS it needs Homebrew libomp (brew install libomp) and
               builds for the host architecture only.
  --no-openmp  Disable OpenMP (default on macOS; diagnostic builds elsewhere).

Environment:
  XHDFE_STATIC_GNU_LIBS=1   Linux: embed libstdc++/libgcc (portable binary; libgomp
                            and glibc stay dynamic).
  LIBOMP_PREFIX=/path       macOS: libomp prefix when brew is not on PATH.

CPU tuning:
  --march-native   Tune for the build host (opt-in; not for redistribution).
EOF
}

TARGET="${XHDFE_TARGET:-}"
OPENMP_MODE="${XHDFE_OPENMP:-}"
MARCH_NATIVE_MODE="${XHDFE_ENABLE_MARCH_NATIVE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --windows|--win|--win64) TARGET="windows"; shift ;;
    --linux) TARGET="linux"; shift ;;
    --openmp) OPENMP_MODE="on"; shift ;;
    --no-openmp) OPENMP_MODE="off"; shift ;;
    --march-native|--native) MARCH_NATIVE_MODE="on"; shift ;;
    --no-march-native) MARCH_NATIVE_MODE="off"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

UNAME_S="$(uname -s)"
if [[ -z "${TARGET}" ]]; then
  case "${UNAME_S}" in
    Darwin) TARGET="linux" ;;
    Linux) if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then TARGET="windows"; else TARGET="linux"; fi ;;
    MINGW*|MSYS*|CYGWIN*) TARGET="windows" ;;
    *) TARGET="linux" ;;
  esac
fi

SYSTEM_DEF="OPUNIX"
if [[ "${UNAME_S}" == "Darwin" ]]; then
  SYSTEM_DEF="APPLEMAC"
fi

if [[ "${TARGET}" == "windows" ]]; then
  # Cross build (Linux/WSL) uses the mingw-w64 triplet; a native MSYS2 MINGW64
  # shell has plain g++ (and usually the triplet too).
  if [[ -z "${CXX:-}" ]]; then
    if command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1; then CXX="x86_64-w64-mingw32-g++"
    elif [[ "${UNAME_S}" == MINGW* || "${UNAME_S}" == MSYS* ]]; then CXX="g++"
    else CXX="x86_64-w64-mingw32-g++"; fi
  fi
  if [[ -z "${STRIP_BIN:-}" ]]; then
    if command -v x86_64-w64-mingw32-strip >/dev/null 2>&1; then STRIP_BIN="x86_64-w64-mingw32-strip"; else STRIP_BIN="strip"; fi
  fi
  SYSTEM_DEF="STWIN32"
  if [[ -z "${OPENMP_MODE}" ]]; then OPENMP_MODE="on"; fi
else
  if [[ "${UNAME_S}" == "Darwin" ]]; then CXX="${CXX:-clang++}"; else CXX="${CXX:-g++}"; fi
  STRIP_BIN="${STRIP_BIN:-strip}"
  if [[ -z "${OPENMP_MODE}" ]]; then
    if [[ "${UNAME_S}" == "Darwin" ]]; then OPENMP_MODE="off"; else OPENMP_MODE="on"; fi
  fi
fi

if ! command -v "${CXX}" >/dev/null 2>&1; then
  echo "Error: compiler not found: ${CXX}" >&2
  if [[ "${TARGET}" == "windows" ]]; then
    echo "Install mingw-w64 (Ubuntu/Debian): apt-get install -y g++-mingw-w64-x86-64" >&2
    echo "On Windows: MSYS2 MINGW64 shell with pacman -S mingw-w64-x86_64-gcc" >&2
  elif [[ "${UNAME_S}" == "Darwin" ]]; then
    echo "Install the Xcode command line tools: xcode-select --install" >&2
  fi
  exit 1
fi

# macOS: Apple clang has no OpenMP runtime; --openmp uses Homebrew's libomp
# (brew install libomp) and then builds for the host architecture only, since
# the universal (x86_64 + arm64) binary cannot link a single-arch libomp.
OMP_PREFIX=""
if [[ "${UNAME_S}" == "Darwin" && "${TARGET}" != "windows" && "${OPENMP_MODE}" == "on" ]]; then
  OMP_PREFIX="${LIBOMP_PREFIX:-$(brew --prefix libomp 2>/dev/null || true)}"
  if [[ -z "${OMP_PREFIX}" || ! -f "${OMP_PREFIX}/include/omp.h" ]]; then
    echo "Error: --openmp on macOS needs Homebrew libomp (brew install libomp), or set LIBOMP_PREFIX." >&2
    exit 1
  fi
fi

if [[ -z "${MARCH_NATIVE_MODE}" ]]; then MARCH_NATIVE_MODE="off"; fi

link_flag="-shared"
if [[ "${UNAME_S}" == "Darwin" && "${TARGET}" != "windows" ]]; then
  link_flag="-bundle"
fi

if [[ "${TARGET}" == "windows" ]]; then CXX_STD="gnu++17"; else CXX_STD="c++17"; fi
compile_flags=( "-std=${CXX_STD}" -O3 -DNDEBUG "-DSYSTEM=${SYSTEM_DEF}" -I"${DEPS_DIR}" )
link_flags=( "${link_flag}" )
if [[ "${TARGET}" != "windows" ]]; then
  compile_flags+=( -fPIC -pthread )
  link_flags+=( -pthread )
else
  compile_flags+=( -include "${SCRIPT_DIR}/mingw_stdio_shim.h" )
  # No DLL dependencies: embed the GNU runtimes (libgcc, libstdc++, libgomp,
  # winpthread) into the plugin itself.
  link_flags+=( -static -static-libgcc -static-libstdc++ )
fi
if [[ "${MARCH_NATIVE_MODE}" == "on" && "${TARGET}" != "windows" && "${UNAME_S}" != "Darwin" ]]; then
  compile_flags+=( -march=native -mtune=native )
fi
if [[ "${OPENMP_MODE}" == "on" ]]; then
  if [[ -n "${OMP_PREFIX}" ]]; then
    compile_flags+=( -Xpreprocessor -fopenmp -I"${OMP_PREFIX}/include" )
    link_flags+=( -L"${OMP_PREFIX}/lib" -lomp )
  else
    compile_flags+=( -fopenmp )
    link_flags+=( -fopenmp )
  fi
fi
if [[ "${TARGET}" != "windows" && "${UNAME_S}" == "Linux" && "${XHDFE_STATIC_GNU_LIBS:-}" =~ ^(1|ON|on|true|yes)$ ]]; then
  link_flags+=( -static-libstdc++ -static-libgcc )
fi

SRC="${STATA_DIR}/src/xsamplefe_plugin.cpp"

compile_plugin() {
  local out="$1"
  shift
  "${CXX}" "${compile_flags[@]}" "$@" "${link_flags[@]}" \
    -x c++ "${STPLUGIN_C}" -x none "${SRC}" -o "${out}"
}

if [[ "${UNAME_S}" == "Darwin" && "${TARGET}" != "windows" && -n "${OMP_PREFIX}" ]]; then
  echo "Building ${OUT_PLUGIN} (macOS $(uname -m), OpenMP via ${OMP_PREFIX})"
  compile_plugin "${OUT_PLUGIN}"
elif [[ "${UNAME_S}" == "Darwin" && "${TARGET}" != "windows" ]]; then
  echo "Building ${OUT_PLUGIN} (universal: x86_64 + arm64, OpenMP off)"
  tmp_x86="${BUILD_DIR}/xsamplefe.plugin.x86_64"
  tmp_arm="${BUILD_DIR}/xsamplefe.plugin.arm64"
  compile_plugin "${tmp_x86}" -target x86_64-apple-macos10.12
  compile_plugin "${tmp_arm}" -target arm64-apple-macos11
  lipo -create -output "${OUT_PLUGIN}" "${tmp_x86}" "${tmp_arm}"
else
  echo "Building ${OUT_PLUGIN} (target=${TARGET}, openmp=${OPENMP_MODE})"
  compile_plugin "${OUT_PLUGIN}"
fi

if command -v "${STRIP_BIN}" >/dev/null 2>&1; then
  if [[ "${UNAME_S}" == "Darwin" && "${TARGET}" != "windows" ]]; then
    "${STRIP_BIN}" -x "${OUT_PLUGIN}" || true
  else
    "${STRIP_BIN}" "${OUT_PLUGIN}" || true
  fi
fi

if [[ "${TARGET}" != "windows" && "${UNAME_S}" == "Linux" ]]; then
  if [[ "${OPENMP_MODE}" == "on" ]] && ! ldd "${OUT_PLUGIN}" | grep -q 'libgomp'; then
    echo "Error: --openmp was requested but ${OUT_PLUGIN} does not link libgomp." >&2
    exit 1
  fi
fi

echo "Done: ${OUT_PLUGIN}"
