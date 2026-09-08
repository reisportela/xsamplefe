#!/usr/bin/env bash
# Run the xsamplefe Stata certification suite.
#   STATA_BIN=stata-mp                 Stata executable (default: stata-mp, then stata-se, stata)
#   XSAMPLEFE_BUILD_PLUGIN=1           rebuild stata/xsamplefe.plugin first
#   XSAMPLEFE_BUILD_ARGS="--linux --openmp"
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

STATA_BIN="${STATA_BIN:-stata-mp}"
if ! command -v "${STATA_BIN}" >/dev/null 2>&1; then
  if command -v stata-se >/dev/null 2>&1; then
    STATA_BIN="stata-se"
  elif command -v stata >/dev/null 2>&1; then
    STATA_BIN="stata"
  else
    echo "Error: Stata executable not found. Set STATA_BIN=/path/to/stata." >&2
    exit 127
  fi
fi

if [[ "${XSAMPLEFE_BUILD_PLUGIN:-0}" == "1" ]]; then
  # shellcheck disable=SC2086
  bash "${REPO_ROOT}/stata/tools/build-xsamplefe-plugin.sh" ${XSAMPLEFE_BUILD_ARGS:-}
fi

export XSAMPLEFE_TEST_DIR="${SCRIPT_DIR}"
export XSAMPLEFE_ADOPATH="${XSAMPLEFE_ADOPATH:-${REPO_ROOT}/stata}"

OUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "${OUT_DIR}"
(
  cd "${OUT_DIR}"
  "${STATA_BIN}" -b do "${SCRIPT_DIR}/testall.do"
)

LOG_FILE="${OUT_DIR}/testall.log"
if ! grep -q "XSAMPLEFE CERTIFICATION TESTS COMPLETED SUCCESSFULLY" "${LOG_FILE}"; then
  echo "xsamplefe certification failed. Last log lines:" >&2
  tail -n 60 "${LOG_FILE}" >&2
  exit 1
fi
echo "xsamplefe certification passed (${LOG_FILE})"
