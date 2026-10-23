// =============================================================================
// riscv_pkg.sv
// Package for the RISC-V UVM environment. Include order matters: each file may
// only reference classes declared above it.
// =============================================================================
package riscv_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // RV32I opcodes (insn[6:0])
  localparam bit [6:0]  OP_LUI    = 7'b0110111;
  localparam bit [6:0]  OP_AUIPC  = 7'b0010111;
  localparam bit [6:0]  OP_JAL    = 7'b1101111;
  localparam bit [6:0]  OP_JALR   = 7'b1100111;
  localparam bit [6:0]  OP_BRANCH = 7'b1100011;
  localparam bit [6:0]  OP_LOAD   = 7'b0000011;
  localparam bit [6:0]  OP_STORE  = 7'b0100011;
  localparam bit [6:0]  OP_IMM    = 7'b0010011;
  localparam bit [6:0]  OP_REG    = 7'b0110011;
  localparam bit [6:0]  OP_FENCE  = 7'b0001111;
  localparam bit [6:0]  OP_SYSTEM = 7'b1110011;

  localparam bit [31:0] INSN_ECALL = 32'h0000_0073;

  `include "riscv_transaction.sv"
  `include "reference_model.sv"
  `include "riscv_sequencer.sv"
  `include "riscv_driver.sv"
  `include "riscv_monitor.sv"
  `include "riscv_agent.sv"
  `include "riscv_base_seq.sv"
  `include "riscv_smoke_seq.sv"
  `include "riscv_scoreboard.sv"
  `include "riscv_env_cfg.sv"
  `include "riscv_env.sv"
  `include "riscv_base_test.sv"
  `include "riscv_smoke_test.sv"

endpackage
