# ---- Directories ----
SIMDIR = build
OBJDIR = $(SIMDIR)/obj_dir

# ---- Verilator flags ----
VERILATOR = verilator
VERILATOR_FLAGS = --binary -j 0 --timing --trace --timescale 1ns/1ps +incdir+verilog +incdir+test \
	-Wno-WIDTHEXPAND \
	-Wno-WIDTHTRUNC \
	-Wno-SIDEEFFECT
#	-Wall

# ---- DUT / Testbench definitions ----
# CPU + regfile
DUT_CPU = \
	verilog/cpu.sv \
	verilog/regfile.sv \
	verilog/adder.sv \
	verilog/mult.sv \
	verilog/ntt_full.sv \
	verilog/ntt_butterfly.sv \
	verilog/modSwitch_qBBa_to_BBa.sv \
	verilog/fastBConv.sv \
	verilog/fastBConvEx_BBa_to_q.sv
TB_CPU  = test/cpu_test.sv

# base conversion
DUT_FASTBCONV = verilog/fastBConv.sv
TB_FASTBCONV  = test/tb_fastBConv.sv

# NTT
DUT_NTT_CORE = verilog/ntt_butterfly.sv verilog/ntt_full.sv
TB_NTT_FULL  = test/tb_full_mult.sv
TB_NTT_BIG   = test/tb_big.sv

# ModSwitch  (qBBa -> BBa)
DUT_MODSWITCH = verilog/modSwitch_qBBa_to_BBa.sv verilog/fastBConv.sv
TB_MODSWITCH  = test/tb_modSwitch_qBBa_to_BBa.sv

# fastBConvEx  (BBa -> q)
DUT_FASTBCONVEX = verilog/fastBConvEx_BBa_to_q.sv verilog/fastBConv.sv
TB_FASTBCONVEX  = test/tb_fastBConvEx_BBa_to_q.sv

# ct ct mul
TB_CPU_CTCTMUL = test/cpu_test_ctctmul.sv

# ---- Simulation targets ----
SIM_CPU          = $(SIMDIR)/cpu
SIM_FASTBCONV    = $(SIMDIR)/fastBConv
SIM_NTT_FULL     = $(SIMDIR)/ntt_full
SIM_NTT_BIG      = $(SIMDIR)/ntt_big
SIM_MODSWITCH    = $(SIMDIR)/modSwitch
SIM_FASTBCONVEX  = $(SIMDIR)/fastBConvEx
SIM_CPU_CTCTMUL  = $(SIMDIR)/cpu_ctctmul

# ---- Default ----
.PHONY: all
all: run-all

define VERILATOR_SIM
@mkdir -p $(SIMDIR)
$(VERILATOR) $(VERILATOR_FLAGS) \
	--Mdir $(OBJDIR) \
	-o $(abspath $@) \
	$^
endef

# ---- Build rules ----
$(SIM_CPU): $(DUT_CPU) $(TB_CPU)
	$(VERILATOR_SIM)

$(SIM_FASTBCONV): $(DUT_FASTBCONV) $(TB_FASTBCONV)
	$(VERILATOR_SIM)

$(SIM_NTT_FULL): $(DUT_NTT_CORE) $(TB_NTT_FULL)
	$(VERILATOR_SIM)

$(SIM_NTT_BIG): $(DUT_NTT_CORE) $(TB_NTT_BIG)
	$(VERILATOR_SIM)

$(SIM_MODSWITCH): $(DUT_MODSWITCH) $(TB_MODSWITCH)
	$(VERILATOR_SIM)

$(SIM_FASTBCONVEX): $(DUT_FASTBCONVEX) $(TB_FASTBCONVEX)
	$(VERILATOR_SIM)

$(SIM_CPU_CTCTMUL): $(DUT_CPU) $(TB_CPU_CTCTMUL)
	$(VERILATOR_SIM)

# ---- Run commands ----
.PHONY: run-cpu run-fastBConv run-ntt-full run-ntt-big run-modSwitch run-fastBConvEx run-cpu-ctctmul

run-cpu:         $(SIM_CPU)         ; ./$(SIM_CPU)
run-fastBConv:   $(SIM_FASTBCONV)   ; ./$(SIM_FASTBCONV)
run-ntt-full:    $(SIM_NTT_FULL)    ; ./$(SIM_NTT_FULL)
run-ntt-big:     $(SIM_NTT_BIG)     ; ./$(SIM_NTT_BIG)
run-modSwitch:   $(SIM_MODSWITCH)   ; ./$(SIM_MODSWITCH)
run-fastBConvEx: $(SIM_FASTBCONVEX) ; ./$(SIM_FASTBCONVEX)
run-cpu-ctctmul: $(SIM_CPU_CTCTMUL) ; ./$(SIM_CPU_CTCTMUL)

run-all: \
	run-cpu \
	run-fastBConv \
	run-ntt-full \
	run-ntt-big \
	run-modSwitch \
	run-fastBConvEx \
	run-cpu-ctctmul

# ---- Clean ----
.PHONY: clean
clean:
	rm -rf $(SIMDIR) *.vcd *.fst
