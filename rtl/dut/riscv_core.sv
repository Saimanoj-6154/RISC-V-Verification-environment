// =============================================================================
// riscv_core.sv
//
// Single-cycle RV32I core: base integer instructions only. No CSRs, no
// interrupts, no traps beyond halting.
//
// Memory model expected by this core:
//   - imem_addr / imem_rdata : combinational (zero-wait) instruction fetch
//   - dmem_*                 : combinational read; write on the clock edge
//                              when dmem_req && dmem_we
//
// Halting:
//   - ECALL / EBREAK          -> halt = 1, illegal = 0
//   - illegal instruction     -> halt = 1, illegal = 1
//   - misaligned load/store   -> halt = 1, illegal = 1
//   - misaligned jump/branch  -> halt = 1, illegal = 1
//   Once halted, the PC and register file stop updating.
//
// Retirement port (RVFI-style): each instruction that executes without
// halting is reported on rvfi_* in the cycle it executes, so the
// verification environment can compare it against a reference model.
// =============================================================================

module riscv_core #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction memory
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,

  // Data memory
  output logic        dmem_req,
  output logic        dmem_we,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_be,
  input  logic [31:0] dmem_rdata,

  // Status
  output logic        halt,
  output logic        illegal,

  // Retirement port (RVFI-style)
  output logic        rvfi_valid,
  output logic [31:0] rvfi_pc,
  output logic [31:0] rvfi_insn,
  output logic [31:0] rvfi_next_pc,
  output logic [4:0]  rvfi_rd_addr,
  output logic [31:0] rvfi_rd_wdata,
  output logic [31:0] rvfi_mem_addr,
  output logic [3:0]  rvfi_mem_rmask,
  output logic [3:0]  rvfi_mem_wmask,
  output logic [31:0] rvfi_mem_rdata,
  output logic [31:0] rvfi_mem_wdata
);

  // ---------------------------------------------------------------------------
  // Opcodes (insn[6:0])
  // ---------------------------------------------------------------------------
  localparam logic [6:0]  OP_LUI    = 7'b0110111;
  localparam logic [6:0]  OP_AUIPC  = 7'b0010111;
  localparam logic [6:0]  OP_JAL    = 7'b1101111;
  localparam logic [6:0]  OP_JALR   = 7'b1100111;
  localparam logic [6:0]  OP_BRANCH = 7'b1100011;
  localparam logic [6:0]  OP_LOAD   = 7'b0000011;
  localparam logic [6:0]  OP_STORE  = 7'b0100011;
  localparam logic [6:0]  OP_IMM    = 7'b0010011;
  localparam logic [6:0]  OP_REG    = 7'b0110011;
  localparam logic [6:0]  OP_FENCE  = 7'b0001111;
  localparam logic [6:0]  OP_SYSTEM = 7'b1110011;

  localparam logic [31:0] INSN_ECALL  = 32'h0000_0073;
  localparam logic [31:0] INSN_EBREAK = 32'h0010_0073;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  logic [31:0] pc;
  logic [31:0] regs [0:31];

  // ---------------------------------------------------------------------------
  // Instruction fields
  // ---------------------------------------------------------------------------
  logic [31:0] insn;
  logic [6:0]  opcode;
  logic [4:0]  rd, rs1, rs2;
  logic [2:0]  funct3;
  logic [6:0]  funct7;

  assign insn      = imem_rdata;
  assign imem_addr = pc;
  assign opcode    = insn[6:0];
  assign rd        = insn[11:7];
  assign funct3    = insn[14:12];
  assign rs1       = insn[19:15];
  assign rs2       = insn[24:20];
  assign funct7    = insn[31:25];

  // Immediates
  logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

  assign imm_i = {{20{insn[31]}}, insn[31:20]};
  assign imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
  assign imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
  assign imm_u = {insn[31:12], 12'b0};
  assign imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

  // Register reads (x0 is hard-wired to zero)
  logic [31:0] rs1_val, rs2_val;

  assign rs1_val = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
  assign rs2_val = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

  // ---------------------------------------------------------------------------
  // Opcode decode
  // ---------------------------------------------------------------------------
  logic is_lui, is_auipc, is_jal, is_jalr, is_branch;
  logic is_load, is_store, is_opimm, is_op, is_fence, is_system;

  assign is_lui    = (opcode == OP_LUI);
  assign is_auipc  = (opcode == OP_AUIPC);
  assign is_jal    = (opcode == OP_JAL);
  assign is_jalr   = (opcode == OP_JALR);
  assign is_branch = (opcode == OP_BRANCH);
  assign is_load   = (opcode == OP_LOAD);
  assign is_store  = (opcode == OP_STORE);
  assign is_opimm  = (opcode == OP_IMM);
  assign is_op     = (opcode == OP_REG);
  assign is_fence  = (opcode == OP_FENCE);
  assign is_system = (opcode == OP_SYSTEM);

  // Encoding legality (ECALL/EBREAK count as legal here; they halt separately)
  logic legal_insn;

  always_comb begin
    legal_insn = 1'b0;
    if (is_lui || is_auipc || is_jal) begin
      legal_insn = 1'b1;
    end else if (is_jalr) begin
      legal_insn = (funct3 == 3'b000);
    end else if (is_branch) begin
      legal_insn = (funct3 == 3'b000) || (funct3 == 3'b001) ||
                   (funct3 == 3'b100) || (funct3 == 3'b101) ||
                   (funct3 == 3'b110) || (funct3 == 3'b111);
    end else if (is_load) begin
      legal_insn = (funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010) ||
                   (funct3 == 3'b100) || (funct3 == 3'b101);
    end else if (is_store) begin
      legal_insn = (funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010);
    end else if (is_opimm) begin
      if (funct3 == 3'b001)
        legal_insn = (funct7 == 7'b0000000);
      else if (funct3 == 3'b101)
        legal_insn = (funct7 == 7'b0000000) || (funct7 == 7'b0100000);
      else
        legal_insn = 1'b1;
    end else if (is_op) begin
      legal_insn = (funct7 == 7'b0000000) ||
                   ((funct7 == 7'b0100000) && ((funct3 == 3'b000) || (funct3 == 3'b101)));
    end else if (is_fence) begin
      legal_insn = (funct3 == 3'b000);
    end else if (is_system) begin
      legal_insn = (insn == INSN_ECALL) || (insn == INSN_EBREAK);
    end
  end

  // ---------------------------------------------------------------------------
  // Memory address and alignment
  // ---------------------------------------------------------------------------
  logic [31:0] dmem_addr_calc;
  logic [3:0]  access_mask;
  logic        mem_misaligned;

  assign dmem_addr_calc = rs1_val + (is_store ? imm_s : imm_i);
  assign dmem_addr      = dmem_addr_calc;
  assign access_mask    = mem_mask(funct3, dmem_addr_calc[1:0]);
  assign mem_misaligned = (is_load || is_store) &&
                          (((funct3[1:0] == 2'b01) && dmem_addr_calc[0]) ||
                           ((funct3[1:0] == 2'b10) && (dmem_addr_calc[1:0] != 2'b00)));

  // ---------------------------------------------------------------------------
  // ALU
  // ---------------------------------------------------------------------------
  logic [31:0] alu_a, alu_b, alu_out;
  logic [31:0] sra_out;
  logic [4:0]  shamt;
  logic        sub_sra;   // funct7[5]: SUB (OP, funct3=000) or SRA/SRAI (funct3=101)

  assign alu_a   = rs1_val;
  assign alu_b   = is_op ? rs2_val : imm_i;
  assign shamt   = alu_b[4:0];
  assign sub_sra = funct7[5];
  assign sra_out = $signed(alu_a) >>> shamt;

  always_comb begin
    case (funct3)
      3'b000:  alu_out = (is_op && sub_sra) ? (alu_a - alu_b) : (alu_a + alu_b);
      3'b001:  alu_out = alu_a << shamt;
      3'b010:  alu_out = {31'b0, ($signed(alu_a) < $signed(alu_b))};
      3'b011:  alu_out = {31'b0, (alu_a < alu_b)};
      3'b100:  alu_out = alu_a ^ alu_b;
      3'b101:  alu_out = sub_sra ? sra_out : (alu_a >> shamt);
      3'b110:  alu_out = alu_a | alu_b;
      default: alu_out = alu_a & alu_b;
    endcase
  end

  // ---------------------------------------------------------------------------
  // Branch condition
  // ---------------------------------------------------------------------------
  logic branch_taken;

  always_comb begin
    case (funct3)
      3'b000:  branch_taken = (rs1_val == rs2_val);
      3'b001:  branch_taken = (rs1_val != rs2_val);
      3'b100:  branch_taken = ($signed(rs1_val) <  $signed(rs2_val));
      3'b101:  branch_taken = ($signed(rs1_val) >= $signed(rs2_val));
      3'b110:  branch_taken = (rs1_val <  rs2_val);
      default: branch_taken = (rs1_val >= rs2_val);
    endcase
  end

  // ---------------------------------------------------------------------------
  // Next PC
  // ---------------------------------------------------------------------------
  logic [31:0] next_pc;
  logic        jump_taken;
  logic        jump_misaligned;

  assign jump_taken      = is_jal || is_jalr || (is_branch && branch_taken);
  assign jump_misaligned = jump_taken && next_pc[1];   // no C extension: targets must be 4-byte aligned

  always_comb begin
    if (is_jal)                         next_pc = pc + imm_j;
    else if (is_jalr)                   next_pc = (rs1_val + imm_i) & 32'hFFFF_FFFE;
    else if (is_branch && branch_taken) next_pc = pc + imm_b;
    else                                next_pc = pc + 32'd4;
  end

  // ---------------------------------------------------------------------------
  // Halt / illegal
  // ---------------------------------------------------------------------------
  assign illegal = !legal_insn || mem_misaligned || jump_misaligned;
  assign halt    = illegal || is_system;

  // ---------------------------------------------------------------------------
  // Data memory interface
  // ---------------------------------------------------------------------------
  logic [31:0] store_data, load_raw, load_val;

  assign dmem_req   = (is_load || is_store) && !halt;
  assign dmem_we    = is_store && !halt;
  assign dmem_be    = access_mask;
  assign store_data = rs2_val << {dmem_addr_calc[1:0], 3'b000};
  assign dmem_wdata = store_data;
  assign load_raw   = dmem_rdata >> {dmem_addr_calc[1:0], 3'b000};

  logic [7:0]  lb_byte;
  logic [15:0] lh_half;
  logic        lb_sign, lh_sign;

  assign lb_byte = load_raw[7:0];
  assign lh_half = load_raw[15:0];
  assign lb_sign = load_raw[7];
  assign lh_sign = load_raw[15];

  always_comb begin
    case (funct3)
      3'b000:  load_val = {{24{lb_sign}}, lb_byte};    // LB
      3'b001:  load_val = {{16{lh_sign}}, lh_half};    // LH
      3'b010:  load_val = load_raw;                    // LW
      3'b100:  load_val = {24'b0, lb_byte};            // LBU
      default: load_val = {16'b0, lh_half};            // LHU
    endcase
  end

  // ---------------------------------------------------------------------------
  // Register writeback
  // ---------------------------------------------------------------------------
  logic        writes_rd;
  logic        reg_we;
  logic [31:0] rd_wdata;

  assign writes_rd = is_lui || is_auipc || is_jal || is_jalr ||
                     is_load || is_opimm || is_op;
  assign reg_we    = writes_rd && !halt && (rd != 5'd0);

  always_comb begin
    if (is_lui)                 rd_wdata = imm_u;
    else if (is_auipc)          rd_wdata = pc + imm_u;
    else if (is_jal || is_jalr) rd_wdata = pc + 32'd4;
    else if (is_load)           rd_wdata = load_val;
    else                        rd_wdata = alu_out;
  end

  // ---------------------------------------------------------------------------
  // State update
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= RESET_PC;
      for (int i = 0; i < 32; i++) regs[i] <= 32'd0;
    end else if (!halt) begin
      pc <= next_pc;
      if (reg_we) regs[rd] <= rd_wdata;
    end
  end

  // ---------------------------------------------------------------------------
  // Retirement port (RVFI-style)
  // ---------------------------------------------------------------------------
  assign rvfi_valid     = rst_n && !halt;
  assign rvfi_pc        = pc;
  assign rvfi_insn      = insn;
  assign rvfi_next_pc   = next_pc;
  assign rvfi_rd_addr   = reg_we ? rd : 5'd0;
  assign rvfi_rd_wdata  = reg_we ? rd_wdata : 32'd0;
  assign rvfi_mem_addr  = (is_load || is_store) ? dmem_addr_calc : 32'd0;
  assign rvfi_mem_rmask = is_load  ? access_mask : 4'd0;
  assign rvfi_mem_wmask = is_store ? access_mask : 4'd0;
  assign rvfi_mem_rdata = is_load  ? dmem_rdata : 32'd0;
  assign rvfi_mem_wdata = is_store ? store_data : 32'd0;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  // Byte-enable mask for an access of size funct3[1:0] at byte offset 'off'.
  function automatic logic [3:0] mem_mask(input logic [2:0] f3, input logic [1:0] off);
    logic [3:0] m;
    case (f3[1:0])
      2'b00:   m = 4'b0001 << off;   // byte
      2'b01:   m = 4'b0011 << off;   // halfword
      default: m = 4'b1111;          // word
    endcase
    return m;
  endfunction

endmodule
