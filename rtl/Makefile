# ---- Directories ----
SIMDIR   = build
SYNTH_DIR = synth
LIB      = /usr/caen/misc/class/eecs470/lib/verilog/lec25dscc25.v

# ---- DUT / Testbench definitions ----
# CPU + regfile
DUT_CPU = verilog/cpu.sv verilog/regfile.sv verilog/adder.sv verilog/mult.sv
TB_CPU  = test/cpu_test.sv

DUT_RF  = verilog/regfile.sv
TB_RF   = test/tb_regfile.sv

# base conversion
DUT_FASTBCONV = verilog/fastBConv.sv
TB_FASTBCONV  = test/tb_fastBConv.sv

# NTT
DUT_NTT_CORE = verilog/ntt_butterfly.sv verilog/ntt_full.sv
TB_NTT_FULL  = test/tb_full_mult.sv
TB_NTT_BIG   = test/tb_big.sv

# Multipliers
DUT_MULT = verilog/mult.sv
TCL_MULT = $(SYNTH_DIR)/mult_synth.tcl
SYNTH_MULT = $(SYNTH_DIR)/mult.vg
SYNTH_REP_MULT = $(SYNTH_DIR)/mult.rep

# ---- Simulation targets ----
SIM_CPU    = $(SIMDIR)/simv_cpu
SIM_RF     = $(SIMDIR)/simv_regfile
SIM_FASTBCONV = $(SIMDIR)/simv_fastBConv
SIM_NTT_FULL = $(SIMDIR)/simv_ntt_full
SIM_NTT_BIG  = $(SIMDIR)/simv_ntt_big

# ---- Synthesis TCL / output files ----
TCL_NTT        = $(SYNTH_DIR)/ntt_butt_synth.tcl
SYNTH_NTT      = $(SYNTH_DIR)/ntt_butterfly.vg
SYNTH_REP_NTT  = $(SYNTH_DIR)/ntt_butterfly.rep

# ---- Default ----
.PHONY: all
all: run-all

# ---- Generic VCS simulation pattern ----
define VCS_SIM
@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
module load vcs/2023.12-SP2-1 || true
vcs -sverilog -full64 -timescale=1ns/1ps \
    +incdir+verilog +incdir+test \
    -Mdir=$(SIMDIR)/csrc -o $@ \
    -debug_access+all +v2k \
    $^
endef

# ---- Generic DVE (waveform view) simulation pattern ----
define DVE_SIM
@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
module load vcs/2023.12-SP2-1 || true
vcs -sverilog -full64 -timescale=1ns/1ps \
    +incdir+verilog +incdir+test \
    -Mdir=$(SIMDIR)/csrc -o $@ \
    -R -gui -debug_access+all -kdb +v2k \
    $^
endef


# ---- Simulation rules ----
$(SIM_CPU): $(DUT_CPU) $(TB_CPU)
	$(VCS_SIM)

$(SIM_RF): $(DUT_RF) $(TB_RF)
	$(VCS_SIM)

$(SIM_FASTBCONV): $(DUT_FASTBCONV) $(TB_FASTBCONV)
	$(VCS_SIM)

$(SIM_NTT_FULL): $(DUT_NTT_CORE) $(TB_NTT_FULL)
	$(VCS_SIM)

$(SIM_NTT_BIG): $(DUT_NTT_CORE) $(TB_NTT_BIG)
	$(VCS_SIM)

# ---- DVE debugger support ----
.PHONY: dve-cpu dve-regfile dve-fastBConv dve-ntt-full dve-ntt-big

$(SIMDIR)/dve_cpu: $(DUT_CPU) $(TB_CPU)
	$(DVE_SIM)

dve-cpu: $(SIMDIR)/dve_cpu

$(SIMDIR)/dve_regfile: $(DUT_RF) $(TB_RF)
	$(DVE_SIM)

dve-regfile: $(SIMDIR)/dve_regfile

$(SIMDIR)/dve_fastBConv: $(DUT_FASTBCONV) $(TB_FASTBCONV)
	$(DVE_SIM)

dve-fastBConv: $(SIMDIR)/dve_fastBConv

$(SIMDIR)/dve_ntt_full: $(DUT_NTT_CORE) $(TB_NTT_FULL)
	$(DVE_SIM)

dve-ntt-full: $(SIMDIR)/dve_ntt_full

$(SIMDIR)/dve_ntt_big: $(DUT_NTT_CORE) $(TB_NTT_BIG)
	$(DVE_SIM)

dve-ntt-big: $(SIMDIR)/dve_ntt_big

# ---- Run commands ----
.PHONY: run-regfile run-cpu run-fastBConv run-ntt-full run-ntt-big
run-regfile: $(SIM_RF); $(SIM_RF)
run-cpu: $(SIM_CPU); $(SIM_CPU)
run-fastBConv: $(SIM_FASTBCONV); $(SIM_FASTBCONV)
run-ntt-full: $(SIM_NTT_FULL); $(SIM_NTT_FULL)
run-ntt-big: $(SIM_NTT_BIG); $(SIM_NTT_BIG)

run-all: run-regfile run-cpu run-fastBConv run-ntt-full run-ntt-big

# ---- Synthesis helpers ----
.PHONY: synth
synth:
	mkdir -p $(SYNTH_DIR)

define SYNTH_TARGET
$1: $2 $3 | synth
	@echo "Synthesizing $4 with Design Compiler..."
	cd $(SYNTH_DIR) && dc_shell-t -f $(notdir $3) | tee $4_synth.out
	@echo "Generated $@"
endef

$(eval $(call SYNTH_TARGET,$(SYNTH_MULT),verilog/mult.sv,$(TCL_MULT),mult))
$(eval $(call SYNTH_TARGET,$(SYNTH_NTT),verilog/ntt_butterfly.sv,$(TCL_NTT),ntt_butterfly))

.PHONY: synth-mult synth-ntt
synth-mult: $(SYNTH_MULT)
synth-ntt: $(SYNTH_NTT)

# ---- Slack reporting helper ----
define SLACK
.PHONY: slack-$2
slack-$2: $1
	@echo "=== $2 timing slack (from $3) ==="
	@if [ -f "$3" ]; then \
	    grep -i "slack" $3 | head -n 20; \
	else \
	    echo "ERROR: $3 not found. Did synthesis succeed?"; \
	    exit 1; \
	fi
endef

$(eval $(call SLACK,$(SYNTH_MULT),mult,$(SYNTH_REP_MULT)))
$(eval $(call SLACK,$(SYNTH_NTT),ntt_butterfly,$(SYNTH_REP_NTT)))

# ---- Clean ----
.PHONY: clean
clean:
	rm -rf $(SIMDIR) simv simv.daidir csrc ucli.key *.vpd *.vcd synth
