// =============================================================================
// riscv_driver.sv
//
// For a processor, the driver does not push transactions into the DUT. It loads
// the program: each instruction item is written into instruction memory at the
// next word address. The core then fetches it through the zero-wait memory.
// Each loaded item is also announced on prog_ap so the scoreboard can mirror
// the program into its reference model.
// =============================================================================
class riscv_driver extends uvm_driver #(riscv_transaction);
  `uvm_component_utils(riscv_driver)

  localparam int MEM_WORDS = 4096;      // must match riscv_if MEM_WORDS

  virtual riscv_if vif;
  uvm_analysis_port #(riscv_transaction) prog_ap;
  int unsigned next_word;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    prog_ap = new("prog_ap", this);
    if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface 'vif' not set for riscv_driver")
  endfunction

  task run_phase(uvm_phase phase);
    riscv_transaction req;

    // Clear memory first so unloaded locations read as zero.
    for (int i = 0; i < MEM_WORDS; i++) vif.mem[i] = 32'h0;
    next_word = 0;

    forever begin
      seq_item_port.get_next_item(req);
      if (next_word >= MEM_WORDS)
        `uvm_fatal("PROG_OVF", "program does not fit in instruction memory")
      req.addr = next_word * 4;
      vif.mem[next_word] = req.insn;
      prog_ap.write(req);
      next_word++;
      seq_item_port.item_done();
    end
  endtask
endclass
