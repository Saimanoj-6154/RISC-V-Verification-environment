// Run-time configuration shared by the environment and the test.
class riscv_env_cfg extends uvm_object;
  `uvm_object_utils(riscv_env_cfg)

  virtual riscv_if vif;
  int unsigned     timeout_cycles = 2000;   // cycles to wait for the core to halt

  function new(string name = "riscv_env_cfg");
    super.new(name);
  endfunction
endclass
