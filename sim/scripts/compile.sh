#!/usr/bin/env bash
# Compile the RTL and UVM testbench with Questa/ModelSim.
#   UVM_HOME  directory that contains src/uvm_pkg.sv (UVM 1.2 source tree)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

: "${UVM_HOME:?set UVM_HOME to your UVM 1.2 source directory}"

[ -d work ] || vlib work
vlog -sv -timescale 1ns/1ps +incdir+"$UVM_HOME/src" "$UVM_HOME/src/uvm_pkg.sv" \
     -f sim/filelists/riscv_tb.f
