#!/usr/bin/env bash
# Self-test of the xsamplefe certification harness: it proves that
# tests/run_tests.sh fails, loudly, when a certification file fails.
#
#   1. XSAMPLEFE_SELFTEST=1 makes testall.do run tests/xsamplefe_selftest_fail.do
#      (one deliberately false assert) before the real certification files. The
#      run must exit non-zero, and testall.log must lack the success marker and
#      contain "assertion is false".
#   2. The normal run must exit 0 and print the marker.
#
# Same environment variables as run_tests.sh (STATA_BIN, XSAMPLEFE_ADOPATH,
# XHDFE_ADOPATH, ...). Step 2 runs the full certification, so this takes about
# as long as run_tests.sh plus a few seconds.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/output"
LOG_FILE="${OUT_DIR}/testall.log"
MARKER="XSAMPLEFE CERTIFICATION TESTS COMPLETED SUCCESSFULLY"
mkdir -p "${OUT_DIR}"

fail=0
note() { echo "  $*"; }
bad() { echo "  FAIL: $*" >&2; fail=1; }

echo "== 1/2 injected failure: run_tests.sh must report it"
XSAMPLEFE_SELFTEST=1 bash "${SCRIPT_DIR}/run_tests.sh" >"${OUT_DIR}/selftest_injected.out" 2>&1
rc=$?
cp -f "${LOG_FILE}" "${OUT_DIR}/selftest_injected.log" 2>/dev/null || true
note "exit status ${rc}"
if [[ ${rc} -eq 0 ]]; then bad "run_tests.sh exited 0 with a failing certification file"; fi
if [[ ! -f "${OUT_DIR}/selftest_injected.log" ]]; then
  bad "no testall.log was produced"
else
  if grep -q "${MARKER}" "${OUT_DIR}/selftest_injected.log"; then
    bad "the success marker is in the log of a failing run"
  else
    note "success marker absent, as required"
  fi
  if grep -q "assertion is false" "${OUT_DIR}/selftest_injected.log"; then
    note "the failed assert is visible in the log"
  else
    bad "the log does not contain \"assertion is false\""
  fi
fi

echo "== 2/2 normal run: run_tests.sh must pass"
bash "${SCRIPT_DIR}/run_tests.sh" >"${OUT_DIR}/selftest_normal.out" 2>&1
rc=$?
note "exit status ${rc}"
if [[ ${rc} -ne 0 ]]; then bad "run_tests.sh failed on the normal path (see ${OUT_DIR}/selftest_normal.out)"; fi
if grep -q "${MARKER}" "${LOG_FILE}"; then
  note "success marker present, as required"
else
  bad "the success marker is missing from the normal run"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "xsamplefe harness self-test FAILED" >&2
  exit 1
fi
echo "xsamplefe harness self-test passed"
