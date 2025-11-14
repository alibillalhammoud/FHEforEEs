# ===== Makefile: build & run BOTH tests =====

# ---- Files ----
DUT_CTCT  = verilog/ct_ct_add.sv
TB_CTCT   = test/tb_ct_add.sv     # your CT+CT testbench filename

DUT_CTPT  = verilog/ct_pt_add.sv
TB_CTPT   = test/tb_ct_pt_add.sv  # your CT+PT testbench filename

# ---- Outputs ----
SIMDIR    = build
SIM_CTCT  = $(SIMDIR)/simv_ctct
SIM_CTPT  = $(SIMDIR)/simv_ctpt

# ---- Default target ----
.PHONY: all
all: run-all

# ---- Build rules ----
$(SIM_CTCT): $(DUT_CTCT) $(TB_CTCT)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_CTCT) \
	    -debug_access+all +v2k \
	    $(DUT_CTCT) $(TB_CTCT)

$(SIM_CTPT): $(DUT_CTPT) $(TB_CTPT)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_CTPT) \
	    -debug_access+all +v2k \
	    $(DUT_CTPT) $(TB_CTPT)

# ---- Run rules ----
.PHONY: run-ctct run-ctpt run-all
run-ctct: $(SIM_CTCT)
	$(SIM_CTCT)

run-ctpt: $(SIM_CTPT)
	$(SIM_CTPT)

run-all: run-ctct run-ctpt

# ---- Clean ----
.PHONY: clean
clean:
	rm -rf $(SIMDIR) simv simv.daidir csrc ucli.key *.vpd *.vcd
