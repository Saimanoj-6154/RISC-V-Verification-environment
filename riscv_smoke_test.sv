// Phase 3 test: directed smoke program.
class riscv_smoke_test extends riscv_base_test;
  `uvm_component_utils(riscv_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_sequence();
    riscv_smoke_seq seq;
    seq = riscv_smoke_seq::type_id::create("seq");
    seq.start(env.agent.sqr);
  endtask
endclass
