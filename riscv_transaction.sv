// =============================================================================
// riscv_transaction.sv
//
// One instruction as seen by the environment.
//   Driven (sequence -> driver):  insn, and addr (assigned by the driver).
//   Observed (monitor -> scoreboard): everything else, taken from the core's
//   retirement port for one executed instruction.
// =============================================================================
class riscv_transaction extends uvm_sequence_item;
  `uvm_object_utils(riscv_transaction)

  // Driven
  rand bit [31:0] insn;
  bit      [31:0] addr;       // word address assigned by the driver

  // Observed (retirement record)
  bit [31:0] pc;
  bit [31:0] next_pc;
  bit [4:0]  rd_addr;
  bit [31:0] rd_wdata;
  bit [31:0] mem_addr;
  bit [3:0]  mem_rmask;
  bit [3:0]  mem_wmask;
  bit [31:0] mem_rdata;
  bit [31:0] mem_wdata;

  function new(string name = "riscv_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("pc=%08h insn=%08h rd=x%0d rd_wdata=%08h next_pc=%08h mem_addr=%08h rmask=%b wmask=%b",
                     pc, insn, rd_addr, rd_wdata, next_pc, mem_addr, mem_rmask, mem_wmask);
  endfunction
endclass
