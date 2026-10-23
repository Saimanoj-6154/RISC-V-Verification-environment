// =============================================================================
// reference_model.sv
//
// Golden RV32I model (an instruction-set simulator). It is written independently
// of rtl/dut/riscv_core.sv: it executes one instruction at a time from its own
// memory image and register file. The scoreboard steps it once per retired
// instruction and compares every observable effect against the DUT.
//
// Lives under rtl/models/ by project convention, but it is a class compiled into
// riscv_pkg (see tb/pkg/riscv_pkg.sv).
// =============================================================================
class riscv_ref_model extends uvm_object;
  `uvm_object_utils(riscv_ref_model)

  bit [31:0] pc;
  bit [31:0] x   [32];
  bit [31:0] mem [bit [31:0]];     // sparse word memory, key = byte_addr[31:2]

  function new(string name = "riscv_ref_model");
    super.new(name);
    pc = 32'h0;
    foreach (x[i]) x[i] = 32'h0;
  endfunction

  // ---------------------------------------------------------------------------
  // Memory
  // ---------------------------------------------------------------------------
  function void load_word(bit [31:0] byte_addr, bit [31:0] data);
    mem[byte_addr[31:2]] = data;
  endfunction

  function bit [31:0] read_word(bit [31:0] byte_addr);
    if (mem.exists(byte_addr[31:2])) return mem[byte_addr[31:2]];
    return 32'h0;
  endfunction

  // True when the next instruction is ECALL or EBREAK (end of program).
  function bit at_halt();
    bit [31:0] w = read_word(pc);
    return (w == INSN_ECALL) || (w == 32'h0010_0073);
  endfunction

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  // Byte-enable mask for an access of size funct3[1:0] at byte offset 'off'.
  function bit [3:0] size_mask(bit [2:0] f3, bit [1:0] off);
    bit [3:0] m = 4'h0;
    int       n = 1 << f3[1:0];
    for (int i = 0; i < n; i++) m[off + i] = 1'b1;
    return m;
  endfunction

  // Sign- or zero-extend a load result taken from the aligned word.
  function bit [31:0] extend_load(bit [31:0] word, bit [1:0] off, bit [2:0] f3);
    bit [31:0] sh = word >> (8 * off);
    case (f3)
      3'b000:  return {{24{sh[7]}},  sh[7:0]};    // LB
      3'b001:  return {{16{sh[15]}}, sh[15:0]};   // LH
      3'b010:  return sh;                         // LW
      3'b100:  return {24'h0, sh[7:0]};           // LBU
      3'b101:  return {16'h0, sh[15:0]};          // LHU
      default: return 32'h0;
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  // Execute the instruction at pc. Fills 'exp' with the expected retirement
  // record and advances architectural state. Do not call when at_halt() is true.
  // ---------------------------------------------------------------------------
  function void step(output riscv_transaction exp);
    bit [31:0] insn, a, b, imm_i, imm_s, imm_b, imm_u, imm_j;
    bit [31:0] addr, opnd, result, npc, lw;
    bit [6:0]  op, f7;
    bit [4:0]  rd, rs1, rs2;
    bit [2:0]  f3;
    bit [3:0]  mask;
    bit        wr, taken;
    int        size;

    insn  = read_word(pc);
    op    = insn[6:0];
    rd    = insn[11:7];
    f3    = insn[14:12];
    rs1   = insn[19:15];
    rs2   = insn[24:20];
    f7    = insn[31:25];
    a     = x[rs1];
    b     = x[rs2];
    imm_i = {{20{insn[31]}}, insn[31:20]};
    imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
    imm_u = {insn[31:12], 12'h0};
    imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

    result = 32'h0;
    wr     = 1'b0;
    npc    = pc + 32'd4;
    mask   = 4'h0;
    addr   = 32'h0;
    lw     = 32'h0;
    taken  = 1'b0;

    exp        = riscv_transaction::type_id::create("exp");
    exp.pc     = pc;
    exp.insn   = insn;

    case (op)
      OP_LUI:   begin wr = 1'b1; result = imm_u; end
      OP_AUIPC: begin wr = 1'b1; result = pc + imm_u; end
      OP_JAL:   begin wr = 1'b1; result = pc + 32'd4; npc = pc + imm_j; end
      OP_JALR:  begin wr = 1'b1; result = pc + 32'd4; npc = (a + imm_i) & 32'hFFFF_FFFE; end

      OP_BRANCH: begin
        case (f3)
          3'b000:  taken = (a == b);
          3'b001:  taken = (a != b);
          3'b100:  taken = ($signed(a) <  $signed(b));
          3'b101:  taken = ($signed(a) >= $signed(b));
          3'b110:  taken = (a <  b);
          3'b111:  taken = (a >= b);
          default: taken = 1'b0;
        endcase
        if (taken) npc = pc + imm_b;
      end

      OP_LOAD: begin
        addr   = a + imm_i;
        lw     = read_word(addr);
        mask   = size_mask(f3, addr[1:0]);
        wr     = 1'b1;
        result = extend_load(lw, addr[1:0], f3);
        exp.mem_addr  = addr;
        exp.mem_rmask = mask;
        exp.mem_rdata = lw;
      end

      OP_STORE: begin
        addr = a + imm_s;
        size = 1 << f3[1:0];
        lw   = read_word(addr);
        for (int i = 0; i < size; i++)
          lw[8*(addr[1:0] + i) +: 8] = b[8*i +: 8];
        mem[addr[31:2]] = lw;
        mask = size_mask(f3, addr[1:0]);
        exp.mem_addr  = addr;
        exp.mem_wmask = mask;
        exp.mem_wdata = b << (8 * addr[1:0]);
      end

      OP_IMM, OP_REG: begin
        opnd = (op == OP_REG) ? b : imm_i;
        wr   = 1'b1;
        case (f3)
          3'b000:  result = (op == OP_REG && f7[5]) ? (a - opnd) : (a + opnd);
          3'b001:  result = a << opnd[4:0];
          3'b010:  result = ($signed(a) < $signed(opnd)) ? 32'd1 : 32'd0;
          3'b011:  result = (a < opnd) ? 32'd1 : 32'd0;
          3'b100:  result = a ^ opnd;
          3'b101:  begin
            if (f7[5]) result = $signed(a) >>> opnd[4:0];
            else       result = a >> opnd[4:0];
          end
          3'b110:  result = a | opnd;
          default: result = a & opnd;
        endcase
      end

      default: ;   // FENCE is an architectural no-op
    endcase

    if (wr && rd != 5'd0) begin
      x[rd]        = result;
      exp.rd_addr  = rd;
      exp.rd_wdata = result;
    end
    exp.next_pc = npc;
    pc = npc;
  endfunction
endclass
