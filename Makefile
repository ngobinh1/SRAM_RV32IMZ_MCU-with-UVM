# ==============================================================
# Makefile — RISC-V Pipeline (QuestaSim)
# Targets:
#   make sim_legacy            — chạy testbench Verilog truyền thống
#   make sim_uvm TEST=<name>   — chạy UVM test (mặc định: riscv_full_test)
#   make sim_uvm_gui TEST=<name> — mở GUI QuestaSim với UVM test
#   make clean                 — xóa toàn bộ output
# ==============================================================

# --------------------------------------------------------------
# Công cụ
# --------------------------------------------------------------
VLOG   := vlog
VSIM   := vsim
VLIB   := vlib
VMAP   := vmap

# --------------------------------------------------------------
# Thư viện UVM tích hợp sẵn trong QuestaSim
# Kiểm tra đường dẫn thực tế bằng: echo $UVM_HOME
# Nếu dùng UVM built-in của Questa thì chỉ cần -L uvm
# --------------------------------------------------------------
UVM_HOME   := $(QUESTA_HOME)/questasim/verilog_src/uvm-1.2
UVM_SRC    := $(UVM_HOME)/src

# --------------------------------------------------------------
# Thư mục
# --------------------------------------------------------------
RTL_CORE    := rtl/core
RTL_CTRL    := rtl/control
RTL_DP      := rtl/datapath
RTL_CSR     := rtl/csr
RTL_HAZARD  := rtl/hazard
RTL_CACHE   := rtl/cache
RTL_MEM     := rtl/memory
RTL_MULT_DIV:= rtl/mult_div
TB_LEGACY   := tb/legacy
TB_UVM      := tb/uvm
SIM_OUT     := sim/out
HEX_DIR     := sim/hex

# --------------------------------------------------------------
# Tên UVM test mặc định (override bằng: make sim_uvm TEST=riscv_alu_test)
# --------------------------------------------------------------
TEST       ?= riscv_full_test
VERBOSITY  ?= UVM_MEDIUM
SEED       ?= random

# --------------------------------------------------------------
# Danh sách file RTL (theo thứ tự phụ thuộc: leaf → top)
# --------------------------------------------------------------
RTL_FILES :=                                          \
  $(RTL_MEM)/EF_SRAM_1024x32.tt_180V_25C.v           \
  $(RTL_MEM)/EF_SRAM_1024x32.v                        \
  $(RTL_MEM)/axi_sram_wrapper.v                       \
  $(RTL_MEM)/axi_interconnect.v                       \
  $(RTL_CACHE)/l1_icache.v                            \
  $(RTL_CACHE)/l1_dcache.v                            \
  $(RTL_HAZARD)/hazard_unit.v                         \
  $(RTL_CSR)/csr_alu.v                                \
  $(RTL_CSR)/csr_file.v                               \
  $(RTL_MULT_DIV)/muldiv_alu.v                        \
  $(RTL_DP)/adder.v                                   \
  $(RTL_DP)/mux.v                                     \
  $(RTL_DP)/extend.v                                  \
  $(RTL_DP)/pc.v                                      \
  $(RTL_DP)/register_file.v                           \
  $(RTL_DP)/alu.v                                     \
  $(RTL_CTRL)/alu_decoder.v                           \
  $(RTL_CTRL)/main_decoder.v                          \
  $(RTL_CTRL)/control_unit.v                          \
  $(RTL_CORE)/branch_predictor.v                      \
  $(RTL_CORE)/pipeline.v                              \
  $(RTL_CORE)/fetch_cycle.v                           \
  $(RTL_CORE)/decode_cycle.v                          \
  $(RTL_CORE)/issue.v                                 \
  $(RTL_CORE)/execute_cycle.v                         \
  $(RTL_CORE)/memory_cycle.v                          \
  $(RTL_CORE)/writeback_cycle.v                       \
  $(RTL_CORE)/riscv_defs.v                            \
  $(RTL_CORE)/store_buffer.v                          \
  $(RTL_CORE)/lsu.v                                   \
  $(RTL_CORE)/riscv_mmu.v                             \
  $(RTL_CORE)/top_module.v

# --------------------------------------------------------------
# Cờ chung cho vlog
# --------------------------------------------------------------
VLOG_COMMON_FLAGS :=                                  \
  -timescale 1ns/1ps                                  \
  +define+functional                                  \
  +incdir+$(RTL_CORE)                                 \
  +incdir+$(RTL_CTRL)                                 \
  +incdir+$(RTL_DP)                                   \
  +incdir+$(RTL_CSR)                                  \
  +incdir+$(RTL_HAZARD)                               \
  +incdir+$(RTL_CACHE)                                \
  +incdir+$(RTL_MEM)                                  \
  +incdir+$(RTL_MULT_DIV)

# ==============================================================
# TARGET: tạo thư mục work và output
# ==============================================================
$(SIM_OUT):
	mkdir -p $(SIM_OUT)

work:
	$(VLIB) work
	$(VMAP) work work

# ==============================================================
# TARGET: biên dịch RTL (dùng chung cho cả legacy và UVM)
# ==============================================================
compile_rtl: work $(SIM_OUT)
	$(VLOG) $(VLOG_COMMON_FLAGS) $(RTL_FILES) \
	  2>&1 | tee $(SIM_OUT)/compile_rtl.log
	@echo ">>> RTL compiled OK"

# ==============================================================
# TARGET: LEGACY TESTBENCH
# ==============================================================

## Bước 1: biên dịch legacy TB (Verilog)
compile_legacy: compile_rtl
	$(VLOG) $(VLOG_COMMON_FLAGS) \
	  $(TB_LEGACY)/tb_full.v \
	  2>&1 | tee $(SIM_OUT)/compile_legacy.log
	@echo ">>> Legacy TB compiled OK"

## Bước 2: chạy mô phỏng legacy (không có GUI)
sim_legacy: compile_legacy
	$(VSIM) -c work.tb_riscv_pipeline_mega           \
	  -do "run -all; quit -f"                         \
	  -l $(SIM_OUT)/legacy_sim.log
	@echo ">>> Legacy simulation done. Log: $(SIM_OUT)/legacy_sim.log"

## Bước 3 (tuỳ chọn): mở GUI cho legacy TB
sim_legacy_gui: compile_legacy
	$(VSIM) work.tb_riscv_pipeline_mega               \
	  -do "add wave -r /*; run -all"                  \
	  -l $(SIM_OUT)/legacy_sim.log

# ==============================================================
# TARGET: UVM TESTBENCH
# ==============================================================

## Bước 1: biên dịch UVM package và TB (SystemVerilog)
compile_uvm: work $(SIM_OUT)
	$(VLOG) $(VLOG_COMMON_FLAGS) +define+UVM_MEM $(RTL_FILES) \
	  2>&1 | tee $(SIM_OUT)/compile_rtl_uvm.log
	$(VLOG) -sv $(VLOG_COMMON_FLAGS) +define+UVM_MEM  \
	  +incdir+$(UVM_SRC)                              \
	  +incdir+$(TB_UVM) +incdir+$(TB_UVM)/axi_slave_agent +incdir+$(TB_UVM)/riscv_agent \
	  $(UVM_SRC)/uvm_pkg.sv                           \
	  $(RTL_CORE)/rvfi_tracer.sv                      \
	  $(TB_UVM)/riscv_agent/riscv_if.sv                           \
	  $(TB_UVM)/axi_slave_agent/axi_slave_if.sv       \
	  $(TB_UVM)/riscv_tb_pkg.sv                       \
	  $(TB_UVM)/tb_top.sv                             \
	  2>&1 | tee $(SIM_OUT)/compile_uvm.log
	@echo ">>> UVM TB compiled OK"

## Bước 2: chạy UVM test (không có GUI)
## Dùng: make sim_uvm TEST=riscv_alu_test VERBOSITY=UVM_HIGH SEED=12345
sim_uvm: compile_uvm
	$(VSIM) -c work.tb_top                            \
	  -sv_seed $(SEED)                                \
	  +UVM_TESTNAME=$(TEST)                           \
	  +UVM_VERBOSITY=$(VERBOSITY)                     \
	  +UVM_NO_RELNOTES                                \
	  +HEX_DIR=$(HEX_DIR)/                            \
	  -sv_lib $(QUESTA_HOME)/questasim/uvm-1.2/linux_x86_64/uvm_dpi \
	  -do "coverage save -onexit $(SIM_OUT)/$(TEST).ucdb; run -all; quit -f" \
	  -l $(SIM_OUT)/$(TEST)_sim.log
	@echo ">>> UVM test [$(TEST)] done."
	@echo "    Log    : $(SIM_OUT)/$(TEST)_sim.log"
	@echo "    UCDB   : $(SIM_OUT)/$(TEST).ucdb"

## Bước 3: mở GUI cho UVM test (có waveform)
sim_uvm_gui: compile_uvm
	$(VSIM) work.tb_top                               \
	  -sv_seed $(SEED)                                \
	  +UVM_TESTNAME=$(TEST)                           \
	  +UVM_VERBOSITY=$(VERBOSITY)                     \
	  +UVM_NO_RELNOTES                                \
	  +HEX_DIR=$(HEX_DIR)/                            \
	  -L uvm                                          \
	  -voptargs="+acc"                                \
	  -do "add wave -r /tb_top/dut/*; run -all"      \
	  -l $(SIM_OUT)/$(TEST)_gui.log

# ==============================================================
# TARGET: tổng hợp coverage report từ tất cả UCDB
# ==============================================================
coverage_report:
	rm -f $(SIM_OUT)/merged.ucdb
	vcover merge $(SIM_OUT)/merged.ucdb $(SIM_OUT)/*.ucdb
	vcover report -html -details -output $(SIM_OUT)/coverage_html \
	  $(SIM_OUT)/merged.ucdb
	@echo ">>> Coverage report: $(SIM_OUT)/coverage_html/index.html"

# ==============================================================
# TARGET: chạy toàn bộ UVM regression (tất cả các test)
# ==============================================================
regression: compile_uvm
	@for TEST_NAME in riscv_alu_test riscv_mem_test riscv_branch_test \
	                  riscv_hazard_test riscv_csr_test riscv_full_test; do \
	  echo ">>> Running: $$TEST_NAME"; \
	  $(VSIM) -c work.tb_top                          \
	    -sv_seed random                               \
	    +UVM_TESTNAME=$$TEST_NAME                     \
	    +UVM_VERBOSITY=UVM_MEDIUM                     \
	    +UVM_NO_RELNOTES                              \
	    +HEX_DIR=$(HEX_DIR)/                          \
	    -sv_lib $(QUESTA_HOME)/questasim/uvm-1.2/linux_x86_64/uvm_dpi \
	    -do "coverage save -onexit $(SIM_OUT)/$$TEST_NAME.ucdb; run -all; quit -f" \
	    -l $(SIM_OUT)/$$TEST_NAME.log;                \
	done
	$(MAKE) coverage_report
	@echo ">>> Regression complete."

# ==============================================================
# TARGET: Biên dịch file assembly (.S) sang file HEX (.hex)
# Dùng: make compile_asm ASM=sim/custom_tests/test_simple.S HEX=sim/hex/test_simple.hex
# ==============================================================
compile_asm:
	@if [ -z "$(ASM)" ] || [ -z "$(HEX)" ]; then \
		echo "Usage: make compile_asm ASM=<path_to_assembly.S> HEX=<path_to_output.hex>"; \
		exit 1; \
	fi
	./sim/compile_hex.py $(ASM) $(HEX)

# ==============================================================
# TARGET: dọn dẹp
# ==============================================================
clean:
	rm -rf work/ $(SIM_OUT)/
	rm -f transcript vsim.wlf modelsim.ini
	@echo ">>> Cleaned."

.PHONY: work compile_rtl compile_legacy sim_legacy sim_legacy_gui \
        compile_uvm sim_uvm sim_uvm_gui coverage_report regression clean compile_asm
