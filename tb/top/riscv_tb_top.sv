// =============================================================================
// riscv_tb_top.sv
// Clock, reset, DUT, interface, and UVM startup.
// =============================================================================
`timescale 1ns/1ps
module riscv_tb_top;
  import uvm_pkg::*;
  import riscv_pkg::*;

  logic clk   = 1'b0;
  logic rst_n = 1'b0;

  always #5 clk = ~clk;            // 100 MHz

  initial begin
    #50;
    rst_n = 1'b1;                  // release reset after 50 ns
  end

  riscv_if #(.MEM_WORDS(4096)) vif (.clk(clk), .rst_n(rst_n));

  riscv_core #(.RESET_PC(32'h0000_0000)) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .imem_addr   (vif.imem_addr),
    .imem_rdata  (vif.imem_rdata),
    .dmem_req    (vif.dmem_req),
    .dmem_we     (vif.dmem_we),
    .dmem_addr   (vif.dmem_addr),
    .dmem_wdata  (vif.dmem_wdata),
    .dmem_be     (vif.dmem_be),
    .dmem_rdata  (vif.dmem_rdata),
    .halt        (vif.halt),
    .illegal     (vif.illegal),
    .rvfi_valid  (vif.rvfi_valid),
    .rvfi_pc     (vif.rvfi_pc),
    .rvfi_insn   (vif.rvfi_insn),
    .rvfi_next_pc(vif.rvfi_next_pc),
    .rvfi_rd_addr(vif.rvfi_rd_addr),
    .rvfi_rd_wdata(vif.rvfi_rd_wdata),
    .rvfi_mem_addr(vif.rvfi_mem_addr),
    .rvfi_mem_rmask(vif.rvfi_mem_rmask),
    .rvfi_mem_wmask(vif.rvfi_mem_wmask),
    .rvfi_mem_rdata(vif.rvfi_mem_rdata),
    .rvfi_mem_wdata(vif.rvfi_mem_wdata)
  );

  initial begin
    uvm_config_db#(virtual riscv_if)::set(null, "*", "vif", vif);
    run_test();                    // test chosen with +UVM_TESTNAME=...
  end
endmodule
