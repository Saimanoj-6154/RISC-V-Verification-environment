// =============================================================================
// riscv_monitor.sv
//
// Watches the retirement port. On every cycle where rvfi_valid is high (one
// instruction executed without halting), it packages the retirement record into
// a riscv_transaction and broadcasts it on retire_ap. Sampling happens on the
// rising edge, before the core's registers update.
// =============================================================================
class riscv_monitor extends uvm_monitor;
  `uvm_component_utils(riscv_monitor)

  virtual riscv_if vif;
  uvm_analysis_port #(riscv_transaction) retire_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    retire_ap = new("retire_ap", this);
    if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface 'vif' not set for riscv_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    riscv_transaction t;
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n && vif.rvfi_valid) begin
        t = riscv_transaction::type_id::create("retire");
        t.pc        = vif.rvfi_pc;
        t.insn      = vif.rvfi_insn;
        t.next_pc   = vif.rvfi_next_pc;
        t.rd_addr   = vif.rvfi_rd_addr;
        t.rd_wdata  = vif.rvfi_rd_wdata;
        t.mem_addr  = vif.rvfi_mem_addr;
        t.mem_rmask = vif.rvfi_mem_rmask;
        t.mem_wmask = vif.rvfi_mem_wmask;
        t.mem_rdata = vif.rvfi_mem_rdata;
        t.mem_wdata = vif.rvfi_mem_wdata;
        retire_ap.write(t);
      end
    end
  endtask
endclass
