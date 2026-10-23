// =============================================================================
// riscv_base_test.sv
//
// Builds the environment and runs the flow shared by every test:
//   1. run_sequence()  - the test loads a program through the agent
//   2. wait for halt   - the core reaches ECALL/EBREAK or stops on an error
//   3. check end state - DUT and reference must agree on where the program ended
// Tests override run_sequence() only.
// =============================================================================
class riscv_base_test extends uvm_test;
  `uvm_component_utils(riscv_base_test)

  riscv_env        env;
  riscv_env_cfg    cfg;
  virtual riscv_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface 'vif' not found")
    cfg     = riscv_env_cfg::type_id::create("cfg");
    cfg.vif = vif;
    uvm_config_db#(riscv_env_cfg)::set(this, "env*", "cfg", cfg);
    env = riscv_env::type_id::create("env", this);
  endfunction

  // Overridden by each test to choose the stimulus.
  virtual task run_sequence();
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_sequence();
    wait_for_halt();
    check_end_state();
    phase.drop_objection(this);
  endtask

  task wait_for_halt();
    int unsigned cycles = 0;
    while (vif.halt !== 1'b1 && cycles < cfg.timeout_cycles) begin
      @(posedge vif.clk);
      cycles++;
    end
    if (vif.halt !== 1'b1)
      `uvm_error("TIMEOUT", $sformatf("core did not halt within %0d cycles", cfg.timeout_cycles))
    else
      `uvm_info("HALT", $sformatf("core halted at pc=0x%08h after %0d cycles", vif.rvfi_pc, cycles), UVM_LOW)
  endtask

  function void check_end_state();
    if (vif.illegal === 1'b1)
      `uvm_error("ILLEGAL", "DUT halted on an illegal instruction or misaligned access")
    if (vif.rvfi_pc !== env.sb.ref_pc())
      `uvm_error("HALT_PC", $sformatf("DUT halted at pc=0x%08h, reference model at pc=0x%08h",
                                      vif.rvfi_pc, env.sb.ref_pc()))
    if (!env.sb.ref_at_halt())
      `uvm_error("REF_HALT", "DUT halted but the reference model is not at ECALL/EBREAK")
  endfunction
endclass
