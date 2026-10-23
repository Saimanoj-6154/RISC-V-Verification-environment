// =============================================================================
// riscv_smoke_seq.sv
//
// Directed program covering ALU immediates and register ops, a store/load pair,
// a taken forward branch, a jump, and an ECALL to end the program.
// Expected: 13 retirements, halt at the ECALL (word 15, pc 0x3C).
// =============================================================================
class riscv_smoke_seq extends riscv_base_seq;
  `uvm_object_utils(riscv_smoke_seq)

  function new(string name = "riscv_smoke_seq");
    super.new(name);
  endfunction

  virtual task body();
    send_insn(enc_u(20'h1, 5'd1, OP_LUI));                              // x1 = 0x1000 (data base)
    send_insn(enc_i(5,  5'd0, 3'b000, 5'd2, OP_IMM));                   // ADDI  x2 = 5
    send_insn(enc_i(7,  5'd0, 3'b000, 5'd3, OP_IMM));                   // ADDI  x3 = 7
    send_insn(enc_r(7'b0000000, 5'd3, 5'd2, 3'b000, 5'd4, OP_REG));     // ADD   x4 = 12
    send_insn(enc_r(7'b0100000, 5'd2, 5'd3, 3'b000, 5'd5, OP_REG));     // SUB   x5 = 2
    send_insn(enc_s(0, 5'd4, 5'd1, 3'b010));                            // SW    x4, 0(x1)
    send_insn(enc_i(0, 5'd1, 3'b010, 5'd6, OP_LOAD));                   // LW    x6 = 12
    send_insn(enc_i(3, 5'd2, 3'b001, 5'd7, OP_IMM));                    // SLLI  x7 = 40
    send_insn(enc_b(8, 5'd4, 5'd6, 3'b000));                            // BEQ   x6,x4,+8 (taken)
    send_insn(enc_i(99, 5'd0, 3'b000, 5'd8, OP_IMM));                   // skipped
    send_insn(enc_i(15, 5'd2, 3'b100, 5'd9, OP_IMM));                   // XORI  x9 = 10
    send_insn(enc_i(-8, 5'd0, 3'b000, 5'd11, OP_IMM));                  // ADDI  x11 = -8
    send_insn(enc_i({7'b0100000, 5'd1}, 5'd11, 3'b101, 5'd12, OP_IMM)); // SRAI  x12 = -4
    send_insn(enc_j(8, 5'd13));                                         // JAL   x13,+8 (taken)
    send_insn(enc_i(99, 5'd0, 3'b000, 5'd14, OP_IMM));                  // skipped
    send_insn(32'h0000_0073);                                           // ECALL
  endtask
endclass
