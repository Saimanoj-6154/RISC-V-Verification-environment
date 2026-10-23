`timescale 1ns/1ps
// =============================================================================
// riscv_if.sv
//
// Bundles the core's memory buses, status outputs and retirement port, and owns
// the unified word-addressed memory that backs both instruction fetch and data
// access. Reads are zero-wait and combinational; writes commit on the clock edge.
//
// The memory lives here (rather than in the top module) so the UVM driver can
// load programs through the virtual interface.
// =============================================================================
interface riscv_if #(parameter int MEM_WORDS = 4096) (
  input logic clk,
  input logic rst_n
);
  // Memory buses
  logic [31:0] imem_addr;
  logic [31:0] imem_rdata;
  logic        dmem_req;
  logic        dmem_we;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_be;
  logic [31:0] dmem_rdata;

  // Status
  logic        halt;
  logic        illegal;

  // Retirement port
  logic        rvfi_valid;
  logic [31:0] rvfi_pc;
  logic [31:0] rvfi_insn;
  logic [31:0] rvfi_next_pc;
  logic [4:0]  rvfi_rd_addr;
  logic [31:0] rvfi_rd_wdata;
  logic [31:0] rvfi_mem_addr;
  logic [3:0]  rvfi_mem_rmask;
  logic [3:0]  rvfi_mem_wmask;
  logic [31:0] rvfi_mem_rdata;
  logic [31:0] rvfi_mem_wdata;

  // Unified memory, word-addressed
  logic [31:0] mem [0:MEM_WORDS-1];

  function automatic int unsigned widx(input logic [31:0] addr);
    return (addr >> 2) & (MEM_WORDS - 1);
  endfunction

  // Zero-wait combinational reads
  assign imem_rdata = mem[widx(imem_addr)];
  assign dmem_rdata = mem[widx(dmem_addr)];

  // Byte-enabled synchronous write
  always @(posedge clk) begin
    if (dmem_req && dmem_we) begin
      for (int b = 0; b < 4; b++)
        if (dmem_be[b]) mem[widx(dmem_addr)][8*b +: 8] <= dmem_wdata[8*b +: 8];
    end
  end
endinterface
