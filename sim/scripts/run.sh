#!/usr/bin/env bash
# Run one test:  sim/scripts/run.sh <uvm_test_name> [seed] [uvm_verbosity]
# Exits non-zero if any UVM_ERROR or UVM_FATAL was reported.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TEST="${1:-riscv_smoke_test}"
SEED="${2:-1}"
VERB="${3:-UVM_MEDIUM}"
LOG="sim/logs/${TEST}_seed${SEED}.log"
WLF="sim/waves/${TEST}_seed${SEED}.wlf"

vsim -c -sv_seed "$SEED" -l "$LOG" -wlf "$WLF" \
     +UVM_TESTNAME="$TEST" +UVM_VERBOSITY="$VERB" \
     -do "run -all; quit -f" work.riscv_tb_top

echo "----- UVM summary ($LOG) -----"
grep -E "^UVM_(WARNING|ERROR|FATAL) +:" "$LOG" || true
ERRS=$(grep -E "^UVM_(ERROR|FATAL) +:" "$LOG" | awk '{s+=$NF} END{print s+0}')
if [ "$ERRS" -gt 0 ]; then echo "RESULT: FAIL ($ERRS errors)"; exit 1; fi
echo "RESULT: PASS"
