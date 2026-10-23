// =============================================================================
// riscv_base_seq.sv
//
// Base sequence. Holds the RV32I instruction encoders, so each sequence can
// build programs without hand-written hex. Each send_insn() call appends one
// instruction to the program image.
// =============================================================================
class riscv_base_seq extends uvm_sequence #(riscv_transaction);
  `uvm_object_utils(riscv_base_seq)

  function new(string name = "riscv_base_seq");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // RV32I encoders
  // ---------------------------------------------------------------------------
  static function bit [31:0] enc_r(bit [6:0] f7, bit [4:0] rs2, bit [4:0] rs1,
                                   bit [2:0] f3, bit [4:0] rd, bit [6:0] op);
    return {f7, rs2, rs1, f3, rd, op};
  endfunction

  static function bit [31:0] enc_i(int imm, bit [4:0] rs1, bit [2:0] f3,
                                   bit [4:0] rd, bit [6:0] op);
    return {imm[11:0], rs1, f3, rd, op};
  endfunction

  static function bit [31:0] enc_s(int imm, bit [4:0] rs2, bit [4:0] rs1, bit [2:0] f3);
    return {imm[11:5], rs2, rs1, f3, imm[4:0], OP_STORE};
  endfunction

  static function bit [31:0] enc_b(int off, bit [4:0] rs2, bit [4:0] rs1, bit [2:0] f3);
    return {off[12], off[10:5], rs2, rs1, f3, off[4:1], off[11], OP_BRANCH};
  endfunction

  static function bit [31:0] enc_u(bit [19:0] imm20, bit [4:0] rd, bit [6:0] op);
    return {imm20, rd, op};
  endfunction

  static function bit [31:0] enc_j(int off, bit [4:0] rd);
    return {off[20], off[10:1], off[11], off[19:12], rd, OP_JAL};
  endfunction

  // Send one instruction word to the driver.
  task send_insn(bit [31:0] insn);
    riscv_transaction req;
    req = riscv_transaction::type_id::create("req");
    start_item(req);
    req.insn = insn;
    finish_item(req);
  endtask

  virtual task body();
  endtask
endclass
