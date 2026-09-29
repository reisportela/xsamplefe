#!/usr/bin/env bash
# Differential test of xsamplefe against the reference implementation in
# tests/audit/oracle.py, on random unit-level designs. Separate from the
# certification (tests/run_tests.sh), which it does not replace.
#   bash tests/audit/run_audit.sh [cases] [seed] [focus]
#     cases   number of random designs (default 2000)
#     seed    seed of the designs (default 1)
#     focus   mixed (default), reconnect, prune or closure
#   STATA_BIN, XSAMPLEFE_ADOPATH      as in tests/run_tests.sh
#   XSAMPLEFE_AUDIT_OUTDIR            a new output directory (default: tests/output/audit_*)
#   OMP_NUM_THREADS                   team of the calls without numthreads() (default 4)
# Needs Stata 16 or newer (frames) and python3; no other package.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CASES="${1:-2000}"
SEED="${2:-1}"
FOCUS="${3:-mixed}"
STATA_BIN="${STATA_BIN:-stata-mp}"
ADOPATH="${XSAMPLEFE_ADOPATH:-${REPO_ROOT}/stata}"

if [[ -n "${XSAMPLEFE_AUDIT_OUTDIR:-}" ]]; then
  OUT_DIR="${XSAMPLEFE_AUDIT_OUTDIR}"
  if [[ -e "${OUT_DIR}" ]]; then
    echo "Refusing to reuse an existing output directory: ${OUT_DIR}" >&2
    exit 1
  fi
else
  mkdir -p "${REPO_ROOT}/tests/output"
  OUT_DIR="$(mktemp -d "${REPO_ROOT}/tests/output/audit_XXXXXXXX")/run"
fi

python3 "${SCRIPT_DIR}/gen_cases.py" --cases "${CASES}" --seed "${SEED}" --focus "${FOCUS}" \
  --out "${OUT_DIR}" --adopath "${ADOPATH}"
(
  cd "${OUT_DIR}"
  OMP_NUM_THREADS="${OMP_NUM_THREADS:-4}" "${STATA_BIN}" -b do run.do
)
if ! grep -Fxq "XSAMPLEFE AUDIT RUN COMPLETED" "${OUT_DIR}/run.log"; then
  echo "The Stata run did not finish. Last log lines:" >&2
  tail -n 30 "${OUT_DIR}/run.log" >&2
  exit 1
fi
python3 "${SCRIPT_DIR}/compare.py" --out "${OUT_DIR}"
