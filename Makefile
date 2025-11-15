DUT_CTCT  = verilog/ct_ct_add.sv
TB_CTCT   = test/tb_ct_add.sv     

DUT_CTPT  = verilog/ct_pt_add.sv
TB_CTPT   = test/tb_ct_pt_add.sv  
SIMDIR    = build
SIM_CTCT  = $(SIMDIR)/simv_ctct
SIM_CTPT  = $(SIMDIR)/simv_ctpt

.PHONY: all
all: run-all

$(SIM_CTPT): $(DUT_CTPT) $(TB_CTPT)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    +define+N_SLOTS=8 \
	    +define+W_BITS=16 \
	    +define+Q_MOD=7710 \
	    +define+T_MOD=257 \
	    +define+DELTA=30 \
	    -Mdir=$(SIMDIR)/csrc -o $(SIM_CTPT) \
	    -debug_access+all +v2k \
	    $(DUT_CTPT) $(TB_CTPT)

$(SIM_CTCT): $(DUT_CTCT) $(TB_CTCT)
	@mkdir -p $(SIMDIR) $(SIMDIR)/csrc
	module load vcs/2023.12-SP2-1 || true
	vcs -sverilog -full64 -timescale=1ns/1ps \
	    +incdir+verilog \
	    +define+N_SLOTS=8 \
	    +define+W_BITS=16 \
	    +define+Q_MOD=7710 \
	    +define+T_MOD=257 \
	    +define+DELTA=30 \
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
	    +define+N_SLOTS=8 \
	    +define+W_BITS=16 \
	    +define+Q_MOD=7710 \
	    +define+T_MOD=257 \
	    +define+DELTA=30 \
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
	    +define+N_SLOTS=8 \
	    +define+W_BITS=16 \
	    +define+Q_MOD=7710 \
	    +define+T_MOD=257 \
	    +define+DELTA=30 \
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
	    +define+N_SLOTS=8 \
	    +define+W_BITS=16 \
	    +define+Q_MOD=7710 \
	    +define+T_MOD=257 \
	    +define+DELTA=30 \
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

run-all: run-ctct run-ctpt run-ctptmult run-modsingle run-modvector

.PHONY: clean
clean:
	rm -rf $(SIMDIR) simv simv.daidir csrc ucli.key *.vpd *.vcd
