# RISC-V-Verification-environment
A reusable UVM-based verification environment for verifying a RISC-V processor core using SystemVerilog and Universal Verification Methodology (UVM).

## Features

- UVM-based reusable architecture
- Layered verification components
- Randomized instruction generation
- Directed and constrained-random testing
- Functional coverage
- Scoreboard-based checking
- Regression support
- Modular and scalable design

---

## Verification Components

- Interface
- Transaction
- Driver
- Monitor
- Sequencer
- Agent
- Environment
- Scoreboard
- Functional Coverage
- Test Library

## Directory Structure

```text
docs/           Documentation
rtl/            DUT and reference models
tb/             Complete UVM Testbench
sim/            Simulation scripts
regression/     Regression framework

```

## Repo Structure
```
riscv-verification-env/
│
├── README.md
├── LICENSE
├── .gitignore
│
├── docs/
│   ├── verification_plan.md
│   ├── architecture.md
│   ├── test_plan.md
│   ├── coverage_plan.md
│   └── protocol_reference.md
│
├── rtl/
│   ├── dut/
│   │   └── riscv_core.sv
│   └── models/
│       └── reference_model.sv
│
├── tb/
│   ├── interfaces/
│   │   └── riscv_if.sv
│   │
│   ├── pkg/
│   │   └── riscv_pkg.sv
│   │
│   ├── agents/
│   │   └── riscv_agent/
│   │       ├── riscv_transaction.sv
│   │       ├── riscv_driver.sv
│   │       ├── riscv_monitor.sv
│   │       ├── riscv_sequencer.sv
│   │       └── riscv_agent.sv
│   │
│   ├── sequences/
│   │   ├── riscv_base_seq.sv
│   │   ├── riscv_smoke_seq.sv
│   │   ├── riscv_random_seq.sv
│   │   ├── riscv_interrupt_seq.sv
│   │   ├── riscv_exception_seq.sv
│   │   ├── riscv_branch_seq.sv
│   │   ├── riscv_load_store_seq.sv
│   │   └── riscv_csr_seq.sv
│   │
│   ├── scoreboard/
│   │   └── riscv_scoreboard.sv
│   │
│   ├── coverage/
│   │   └── riscv_coverage.sv
│   │
│   ├── env/
│   │   ├── riscv_env_cfg.sv
│   │   └── riscv_env.sv
│   │
│   ├── tests/
│   │   ├── riscv_base_test.sv
│   │   ├── riscv_smoke_test.sv
│   │   ├── riscv_random_test.sv
│   │   ├── riscv_interrupt_test.sv
│   │   ├── riscv_exception_test.sv
│   │   ├── riscv_branch_test.sv
│   │   ├── riscv_memory_test.sv
│   │   └── riscv_regression_test.sv
│   │
│   └── top/
│       └── riscv_tb_top.sv
│
├── sim/
│   ├── filelists/
│   │   └── riscv_tb.f
│   │
│   ├── scripts/
│   │   ├── compile.sh
│   │   ├── run.sh
│   │   └── clean.sh
│   │
│   ├── logs/
│   ├── waves/
│   └── Makefile
│
├── regression/
│   ├── scripts/
│   │   └── regress.py
│   └── results/
│
└── verif_ip/
verif_ip/       Optional verification IP
```
## Testbench Architecture

```
                +---------------------+
                |    UVM Test         |
                +----------+----------+
                           |
                    +------+------+
                    |    Env      |
                    +------+------+
                           |
       +-------------------+------------------+
       |                                      |
+------+-------+                    +---------+--------+
| RISC-V Agent |                    | Scoreboard      |
+------+-------+                    +---------+--------+
       |                                      |
+------+-------+                    +---------+--------+
| Driver        |                   | Coverage         |
| Sequencer     |                   +------------------+
| Monitor       |
+------+-------+
       |
+------+-------+
| Interface     |
+------+-------+
       |
+------+-------+
| DUT (RISC-V) |
+--------------+
```

---
