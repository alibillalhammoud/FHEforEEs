DUT_CTCT  = verilog/ct_ct_add.sv
TB_CTCT   = test/tb_ct_add.sv     

DUT_CTPT  = verilog/ct_pt_add.sv
TB_CTPT   = test/tb_ct_pt_add.sv  
SIMDIR    = build
SIM_CTCT  = $(SIMDIR)/simv_ctct
SIM_CTPT  = $(SIMDIR)/simv_ctpt

# ---- Synthesis config ----
LIB            = /usr/caen/misc/class/eecs470/lib/verilog/lec25dscc25.v
SYNTH_DIR      = synth

TCL_CTCT       = $(SYNTH_DIR)/ct_ct_add_synth.tcl
SYNTH_CTCT     = $(SYNTH_DIR)/ct_ct_add.vg
SYNTH_REP_CTCT = $(SYNTH_DIR)/ct_ct_add.rep

TCL_CTPT       = $(SYNTH_DIR)/ct_pt_add_synth.tcl
SYNTH_CTPT     = $(SYNTH_DIR)/ct_pt_add.vg
SYNTH_REP_CTPT = $(SYNTH_DIR)/ct_pt_add.rep

TCL_MULT       = $(SYNTH_DIR)/mult_synth.tcl
SYNTH_MULT     = $(SYNTH_DIR)/mult.vg
SYNTH_REP_MULT = $(SYNTH_DIR)/mult.rep

TCL_NTT        = $(SYNTH_DIR)/ntt_butt_synth.tcl
SYNTH_NTT      = $(SYNTH_DIR)/ntt_butterfly.vg
SYNTH_REP_NTT  = $(SYNTH_DIR)/ntt_butterfly.rep

.PHONY: all
all: run-all

$(SIM_CTPT): $(DUT_CTPT) $(TB_CTPT)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_CTPT) \
	    -debug_access+all +v2k \
	    $(DUT_CTPT) $(TB_CTPT)

$(SIM_CTCT): $(DUT_CTCT) $(TB_CTCT)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_CTCT) \
	    -debug_access+all +v2k \
	    $(DUT_CTCT) $(TB_CTCT)


# ---- Files for ct_pt_mult ----
DUT_CTPTM = verilog/ct_pt_mult.sv
TB_CTPTM  = test/tb_ct_pt_mult.sv
SIM_CTPTM = $(SIMDIR)/simv_ctptmult

$(SIM_CTPTM): $(DUT_CTPTM) $(TB_CTPTM)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_CTPTM) \
	    -debug_access+all +v2k \
	    $(DUT_CTPTM) $(TB_CTPTM)

.PHONY: run-ctptmult
run-ctptmult: $(SIM_CTPTM)
	$(SIM_CTPTM)


# ---- Files for mod_single test ----
DUT_MODS   = verilog/mod_single.sv
TB_MODS    = test/tb_mod_single.sv
SIM_MODS   = $(SIMDIR)/simv_modsingle

$(SIM_MODS): $(DUT_MODS) $(TB_MODS)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_MODS) \
	    -debug_access+all +v2k \
	    $(DUT_MODS) $(TB_MODS)

.PHONY: run-modsingle
run-modsingle: $(SIM_MODS)
	$(SIM_MODS)


# ---- Files for mod_vector test ----
DUT_MV   = verilog/mod_vector.sv
TB_MV    = test/tb_mod_vector.sv
SIM_MV   = $(SIMDIR)/simv_modvector

$(SIM_MV): $(DUT_MV) $(TB_MV)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_MV) \
	    -debug_access+all +v2k \
	    $(DUT_MV) $(TB_MV)

.PHONY: run-modvector
run-modvector: $(SIM_MV)
	$(SIM_MV)

.PHONY: run-ctct run-ctpt run-all
run-ctct: $(SIM_CTCT)
	$(SIM_CTCT)

run-ctpt: $(SIM_CTPT)
	$(SIM_CTPT)

DUT_RF   = verilog/regfile.sv
TB_RF    = test/tb_regfile.sv
SIM_RF   = $(SIMDIR)/simv_regfile

$(SIM_RF): $(DUT_RF) $(TB_RF)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog +incdir+test \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_RF) \
	    -debug_access+all +v2k \
	    $(DUT_RF) $(TB_RF)

.PHONY: run-regfile
run-regfile: $(SIM_RF)
	$(SIM_RF)


run-all: run-ctct run-ctpt run-ctptmult run-modsingle run-modvector run-regfile


# ---- Synthesis for ct_ct_add ----

# ensure synth directory exists
synth:
	mkdir -p $(SYNTH_DIR)

# Run Design Compiler using ct_ct_add_synth.tcl
$(SYNTH_CTCT): $(DUT_CTCT) $(TCL_CTCT) | synth
	@echo "Synthesizing ct_ct_add with Design Compiler..."
	cd $(SYNTH_DIR) && \
	dc_shell-t -f $(notdir $(TCL_CTCT)) | tee ct_ct_add_synth.out
	@echo "Generated $@"

.PHONY: synth-ctct
synth-ctct: $(SYNTH_CTCT)

# ---- Synthesis for ct_pt_add ----

$(SYNTH_CTPT): $(DUT_CTPT) $(TCL_CTPT) | synth
	@echo "Synthesizing ct_pt_add with Design Compiler..."
	cd $(SYNTH_DIR) && \
	dc_shell-t -f $(notdir $(TCL_CTPT)) | tee ct_pt_add_synth.out
	@echo "Generated $@"

.PHONY: synth-ctpt
synth-ctpt: $(SYNTH_CTPT)

# ---- Synthesis for mult ----

$(SYNTH_MULT): verilog/mult.sv $(TCL_MULT) | synth
	@echo "Synthesizing mult with Design Compiler..."
	cd $(SYNTH_DIR) && \
	dc_shell-t -f $(notdir $(TCL_MULT)) | tee mult_synth.out
	@echo "Generated $@"

.PHONY: synth-mult
synth-mult: $(SYNTH_MULT)

# ---- Synthesis for ntt_butterfly ----

$(SYNTH_NTT): verilog/ntt_butt.sv $(TCL_NTT) | synth
	@echo "Synthesizing ntt_butterfly with Design Compiler..."
	cd $(SYNTH_DIR) && \
	dc_shell-t -f $(notdir $(TCL_NTT)) | tee ntt_butt_synth.out
	@echo "Generated $@"

.PHONY: synth-ntt
synth-ntt: $(SYNTH_NTT)

# ---- Slack report helpers ----
.PHONY: slack
slack: $(SYNTH_CTCT)
	@echo "=== ct_ct_add timing slack (from $(SYNTH_REP_CTCT)) ==="
	@if [ -f "$(SYNTH_REP_CTCT)" ]; then \
	    grep -i "slack" $(SYNTH_REP_CTCT) | head -n 20; \
	else \
	    echo "ERROR: $(SYNTH_REP_CTCT) not found. Did synthesis succeed?"; \
	    exit 1; \
	fi

.PHONY: slack-ctpt
slack-ctpt: $(SYNTH_CTPT)
	@echo "=== ct_pt_add timing slack (from $(SYNTH_REP_CTPT)) ==="
	@if [ -f "$(SYNTH_REP_CTPT)" ]; then \
	    grep -i "slack" $(SYNTH_REP_CTPT) | head -n 20; \
	else \
	    echo "ERROR: $(SYNTH_REP_CTPT) not found. Did synthesis succeed?"; \
	    exit 1; \
	fi

.PHONY: slack-mult
slack-mult: $(SYNTH_MULT)
	@echo "=== mult timing slack (from $(SYNTH_REP_MULT)) ==="
	@if [ -f "$(SYNTH_REP_MULT)" ]; then \
	    grep -i "slack" $(SYNTH_REP_MULT) | head -n 20; \
	else \
	    echo "ERROR: $(SYNTH_REP_MULT) not found. Did synthesis succeed?"; \
	    exit 1; \
	fi

.PHONY: slack-ntt
slack-ntt: $(SYNTH_NTT)
	@echo "=== ntt_butterfly timing slack (from $(SYNTH_REP_NTT)) ==="
	@if [ -f "$(SYNTH_REP_NTT)" ]; then \
	    grep -i "slack" $(SYNTH_REP_NTT) | head -n 20; \
	else \
	    echo "ERROR: $(SYNTH_REP_NTT) not found. Did synthesis succeed?"; \
	    exit 1; \
	fi

.PHONY: clean
clean:
	rm -rf $(SIMDIR) simv simv.daidir csrc ucli.key *.vpd *.vcd synth
