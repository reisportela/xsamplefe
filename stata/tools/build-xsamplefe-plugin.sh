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
  --windows    Build a Windows (PE/DLL) plugin using mingw-w64 (static GNU runtimes).
  --linux      Build a Linux/macOS (ELF/Mach-O) plugin using the native toolchain.

OpenMP:
  --openmp     Enable OpenMP (default on Linux; production builds must use it).
  --no-openmp  Disable OpenMP (diagnostic builds only).

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
  CXX="${CXX:-x86_64-w64-mingw32-g++}"
  STRIP_BIN="${STRIP_BIN:-x86_64-w64-mingw32-strip}"
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
  fi
  exit 1
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
  compile_flags+=( -fopenmp )
  link_flags+=( -fopenmp )
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

if [[ "${UNAME_S}" == "Darwin" && "${TARGET}" != "windows" ]]; then
  echo "Building ${OUT_PLUGIN} (universal: x86_64 + arm64)"
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
