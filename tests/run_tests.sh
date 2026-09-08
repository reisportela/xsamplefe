#!/usr/bin/env bash
# Run the xsamplefe Stata certification suite.
#   STATA_BIN=stata-mp                 Stata executable (default: stata-mp, then stata-se, stata)
#   XSAMPLEFE_BUILD_PLUGIN=1           rebuild stata/xsamplefe.plugin first
#   XSAMPLEFE_BUILD_ARGS="--linux --openmp"
#   XHDFE_ADOPATH=/path/to/xhdfe/stata  optional: enables the reghdfe/xhdfe comparison
#                                      (default: a sibling xhdfe checkout, if present)
#   XSAMPLEFE_SELFTEST=1              inject tests/xsamplefe_selftest_fail.do (one
#                                      deliberately false assert) before the real
#                                      certification files; the run must then fail.
#                                      Used by tests/selftest.sh, which checks that
#                                      this script reports a failing certification.
# Requires reghdfe and sample2 (net install dm46, from(http://www.stata.com/stb/stb37)).
# XSAMPLEFE_FIXTURE_DIR may contain nlswork.dta for offline certification.
# XSAMPLEFE_TEST_OUTDIR selects a new output directory; an existing log is refused.
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
  bash "${REPO_ROOT}/stata/tools/build-xsamplefe-plugin.sh" ${XSAMPLEFE_BUILD_ARGS:-} \
    --output "${REPO_ROOT}/stata/xsamplefe.plugin"
fi

# Help lint: Stata's GUI Viewer truncates SMCL source lines at 245 characters
# and a cut inside a directive breaks the rendering from there on (translate
# does not catch it). Refuse lines over 160 bytes, unbalanced braces on a
# physical line, CR line endings and invalid UTF-8.
HELP_FILE="${REPO_ROOT}/stata/xsamplefe.sthlp"
if ! iconv -f UTF-8 -t UTF-8 "${HELP_FILE}" >/dev/null 2>&1; then
  echo "help lint: ${HELP_FILE} is not valid UTF-8" >&2; exit 1
fi
if grep -q $'\r' "${HELP_FILE}"; then
  echo "help lint: ${HELP_FILE} has CR line endings" >&2; exit 1
fi
if ! LC_ALL=C awk -v f="${HELP_FILE}" '
  length($0) > 160 { printf "help lint: %s:%d: line has %d bytes (max 160)\n", f, NR, length($0) > "/dev/stderr"; bad = 1 }
  { o = gsub(/{/, "{"); c = gsub(/}/, "}"); if (o != c) { printf "help lint: %s:%d: unbalanced braces\n", f, NR > "/dev/stderr"; bad = 1 } }
  END { exit bad }' "${HELP_FILE}"; then
  exit 1
fi

export XSAMPLEFE_TEST_DIR="${SCRIPT_DIR}"
export XSAMPLEFE_ADOPATH="${XSAMPLEFE_ADOPATH:-${REPO_ROOT}/stata}"
if [[ -z "${XHDFE_ADOPATH:-}" && -f "${REPO_ROOT}/../xhdfe/stata/xhdfe.ado" ]]; then
  XHDFE_ADOPATH="$(cd -- "${REPO_ROOT}/../xhdfe/stata" && pwd)"
fi
export XHDFE_ADOPATH="${XHDFE_ADOPATH:-}"

if [[ -n "${XSAMPLEFE_TEST_OUTDIR:-}" ]]; then
  OUT_DIR="${XSAMPLEFE_TEST_OUTDIR}"
else
  mkdir -p "${SCRIPT_DIR}/output"
  OUT_DIR="$(mktemp -d "${SCRIPT_DIR}/output/cert_XXXXXXXX")"
fi
mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd -- "${OUT_DIR}" && pwd)"
LOG_FILE="${OUT_DIR}/testall.log"
if [[ -e "${LOG_FILE}" ]]; then
  echo "Refusing to overwrite or reuse an existing certification log: ${LOG_FILE}" >&2
  exit 1
fi
if [[ -e "${OUT_DIR}/testall.do" ]]; then
  echo "Refusing to overwrite an existing test driver: ${OUT_DIR}/testall.do" >&2
  exit 1
fi
cp "${SCRIPT_DIR}/testall.do" "${OUT_DIR}/testall.do"
echo "xsamplefe certification log: ${LOG_FILE}"
export XSAMPLEFE_TEST_OUTDIR="${OUT_DIR}"
(
  cd "${OUT_DIR}"
  "${STATA_BIN}" -b do testall.do
)

if [[ ! -f "${LOG_FILE}" ]] || ! grep -Fxq "XSAMPLEFE CERTIFICATION TESTS COMPLETED SUCCESSFULLY" "${LOG_FILE}"; then
  echo "xsamplefe certification failed. Last log lines:" >&2
  if [[ -f "${LOG_FILE}" ]]; then tail -n 60 "${LOG_FILE}" >&2; fi
  exit 1
fi
echo "xsamplefe certification passed (${LOG_FILE})"
