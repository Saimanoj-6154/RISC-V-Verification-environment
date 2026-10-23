# Usage (run from sim/):
#   make compile
#   make run TEST=riscv_smoke_test SEED=1
#   make clean
TEST ?= riscv_smoke_test
SEED ?= 1

.PHONY: compile run clean

compile:
	./scripts/compile.sh

run:
	./scripts/run.sh $(TEST) $(SEED)

clean:
	./scripts/clean.sh
