VCS ?= vcs
SEED ?= 1
PLI_FLAGS ?=
.PHONY: sim
sim:
	mkdir -p build
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps $(PLI_FLAGS) -f scripts/files.f -top tb_fifo -o build/simv -l build/compile.log
	./build/simv +ntb_random_seed=$(SEED) -l build/simulation.log
