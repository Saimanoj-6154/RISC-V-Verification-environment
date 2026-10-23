// =============================================================================
// riscv_scoreboard.sv
//
// Two inputs:
//   prog_imp   : program words written by the driver. They are mirrored into the
//                reference model's memory, so the model fetches what the DUT
//                should fetch.
//   retire_imp : one record per retired instruction from the monitor. For each
//                record, the reference model executes the same instruction from
//                its own state, and every observable field is compared.
// =============================================================================
`uvm_analysis_imp_decl(_prog)
`uvm_analysis_imp_decl(_retire)

class riscv_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_scoreboard)

  uvm_analysis_imp_prog   #(riscv_transaction, riscv_scoreboard) prog_imp;
  uvm_analysis_imp_retire #(riscv_transaction, riscv_scoreboard) retire_imp;

  riscv_ref_model ref_model;
  int unsigned    num_retired;
  int unsigned    num_errors;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    prog_imp   = new("prog_imp", this);
    retire_imp = new("retire_imp", this);
    ref_model  = riscv_ref_model::type_id::create("ref_model");
  endfunction

  // Program word from the driver
  function void write_prog(riscv_transaction t);
    ref_model.load_word(t.addr, t.insn);
  endfunction

  // Retired instruction from the monitor
  function void write_retire(riscv_transaction t);
    riscv_transaction exp;
    num_retired++;
    if (ref_model.at_halt()) begin
      num_errors++;
      `uvm_error("EXTRA_RETIRE", $sformatf("DUT retired an instruction after the reference halted: %s",
                                           t.convert2string()))
      return;
    end
    ref_model.step(exp);
    compare(t, exp);
  endfunction

  function void compare(riscv_transaction t, riscv_transaction exp);
    check_field(t, "pc",        t.pc,        exp.pc);
    check_field(t, "insn",      t.insn,      exp.insn);
    check_field(t, "next_pc",   t.next_pc,   exp.next_pc);
    check_field(t, "rd_addr",   t.rd_addr,   exp.rd_addr);
    check_field(t, "rd_wdata",  t.rd_wdata,  exp.rd_wdata);
    check_field(t, "mem_addr",  t.mem_addr,  exp.mem_addr);
    check_field(t, "mem_rmask", t.mem_rmask, exp.mem_rmask);
    check_field(t, "mem_wmask", t.mem_wmask, exp.mem_wmask);
    if (exp.mem_rmask != 0)
      check_field(t, "mem_rdata", t.mem_rdata, exp.mem_rdata);
    if (exp.mem_wmask != 0)  // compare only the byte lanes actually written
      check_field(t, "mem_wdata", t.mem_wdata & lane_mask(exp.mem_wmask),
                                  exp.mem_wdata & lane_mask(exp.mem_wmask));
  endfunction

  function void check_field(riscv_transaction t, string field,
                            bit [31:0] got, bit [31:0] want);
    if (got !== want) begin
      num_errors++;
      `uvm_error("MISMATCH", $sformatf("%s DUT=0x%08h REF=0x%08h :: %s",
                                       field, got, want, t.convert2string()))
    end
  endfunction

  // Expand a 4-bit byte-enable into a 32-bit data mask.
  function bit [31:0] lane_mask(bit [3:0] be);
    bit [31:0] m = 32'h0;
    for (int b = 0; b < 4; b++)
      if (be[b]) m[8*b +: 8] = 8'hFF;
    return m;
  endfunction

  // Used by the test to confirm the DUT and reference agree on the halt point.
  function bit [31:0] ref_pc();
    return ref_model.pc;
  endfunction

  function bit ref_at_halt();
    return ref_model.at_halt();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf("retired=%0d field_errors=%0d", num_retired, num_errors), UVM_LOW)
  endfunction
endclass
