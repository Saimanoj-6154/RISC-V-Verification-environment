// Top-level environment: agent (program loader + retirement monitor) and scoreboard.
class riscv_env extends uvm_env;
  `uvm_component_utils(riscv_env)

  riscv_agent      agent;
  riscv_scoreboard sb;
  riscv_env_cfg    cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(riscv_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "riscv_env_cfg not set")
    agent = riscv_agent::type_id::create("agent", this);
    sb    = riscv_scoreboard::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.drv.prog_ap.connect(sb.prog_imp);
    agent.mon.retire_ap.connect(sb.retire_imp);
  endfunction
endclass
