# Project Structure & File Organization

## Cây thư mục đề xuất

```
riscv_pipeline/
├── rtl/
│   ├── core/
│   ├── control/
│   ├── datapath/
│   ├── csr/
│   ├── hazard/
│   ├── cache/
│   └── memory/
├── tb/
│   ├── legacy/
│   └── uvm/
├── sim/
│   ├── hex/
│   └── out/
└── docs/
```

---

## Chi tiết từng thư mục

### `rtl/core/` — Tầng pipeline chính & top-level

| File | Mô tả |
|---|---|
| `top_module.v` | Top-level, nối tất cả các tầng và module |
| `pipeline.v` | Các thanh ghi pipeline giữa các tầng (pipeline_1_2 → pipeline_4_5) |
| `fetch_cycle.v` | Tầng IF: PC, nạp lệnh |
| `decode_cycle.v` | Tầng ID: giải mã lệnh, đọc thanh ghi |
| `execute_cycle.v` | Tầng EX: ALU, tính địa chỉ nhánh |
| `memory_cycle.v` | Tầng MEM: căn chỉnh dữ liệu load/store |
| `writeback_cycle.v` | Tầng WB: ghi kết quả về thanh ghi |

---

### `rtl/control/` — Đơn vị điều khiển

| File | Mô tả |
|---|---|
| `control_unit.v` | Điều phối main_decoder và alu_decoder; xử lý CSR/ECALL/MRET |
| `main_decoder.v` | Giải mã opcode → các tín hiệu điều khiển (reg_write, mem_write, …) |
| `alu_decoder.v` | Giải mã funct3/funct7/alu_op → alu_control [3:0] |

---

### `rtl/datapath/` — Các thành phần đường dữ liệu

| File | Mô tả |
|---|---|
| `alu.v` | Đơn vị ALU 32-bit (ADD/SUB/AND/OR/XOR/SLT/SLL/SRL/SRA/LUI/AUIPC) |
| `adder.v` | Bộ cộng 32-bit đơn giản (dùng cho PC+4 và branch adder) |
| `mux.v` | Các MUX: 2:1 (`mux`), 3:1 (`mux_3_1`), 4:1 (`mux_4to1`) |
| `extend.v` | Mở rộng dấu/zero cho các kiểu immediate (I/S/B/J/U/CSR) |
| `pc.v` | Thanh ghi Program Counter (có enable và reset) |
| `register_file.v` | File thanh ghi 32×32-bit (x0 luôn = 0, đọc kết hợp bypass) |

---

### `rtl/csr/` — Control & Status Registers

| File | Mô tả |
|---|---|
| `csr_file.v` | Lưu trữ CSR (mstatus, mtvec, mscratch, mepc, mcause); xử lý trap |
| `csr_alu.v` | Logic ghi CSR: CSRRW (ghi đè), CSRRS (set bit), CSRRC (clear bit) |

---

### `rtl/hazard/` — Phát hiện & xử lý hazard

| File | Mô tả |
|---|---|
| `hazard_unit.v` | Forwarding (MEM→EX, WB→EX), stall (load-use), flush (branch/jump) |

---

### `rtl/cache/` — L1 Cache

| File | Mô tả |
|---|---|
| `l1_icache.v` | L1 I-Cache 16 line direct-mapped, AXI4-Lite master (read-only) |
| `l1_dcache.v` | L1 D-Cache 16 line direct-mapped write-back, AXI4-Lite master (read/write) |

---

### `rtl/memory/` — Bộ nhớ & bus AXI

| File | Mô tả |
|---|---|
| `axi_interconnect.v` | AXI4-Lite crossbar: 2 master (I-cache, D-cache) → 1 slave (SRAM) |
| `axi_sram_wrapper.v` | Chuyển đổi AXI4-Lite ↔ giao diện native của EF_SRAM |
| `EF_SRAM_1024x32.v` | Wrapper macro SRAM 1024×32 (Efabless) |
| `EF_SRAM_1024x32_tt_180V_25C.v` | Mô hình timing behavioral của EF_SRAM (tt corner) |

---

### `tb/legacy/` — Testbench Verilog truyền thống

| File | Mô tả |
|---|---|
| `tb_full.v` | Testbench Verilog thuần: nạp hex, theo dõi pipeline cycle-by-cycle |

---

### `tb/uvm/` — UVM Testbench (SystemVerilog)

| File | Mô tả |
|---|---|
| `tb_top.sv` | Module top của UVM TB: clock gen, DUT, interface, `run_test()` |
| `riscv_if.sv` | SystemVerilog Interface: clocking blocks, assertions, tasks load/clear |
| `riscv_tb_pkg.sv` | Package: import tất cả UVM components theo đúng thứ tự |
| `riscv_seq_item.sv` | Transaction class: stimulus + observed fields, `decode_instr()` |
| `riscv_driver.sv` | UVM Driver + Sequencer: điều khiển reset, load hex, chờ cycles |
| `riscv_monitor.sv` | UVM Monitor: theo dõi reg-write, mem-access, branch, all-instr |
| `riscv_scoreboard.sv` | UVM Scoreboard: ISS reference model, so sánh kết quả DUT |
| `riscv_coverage.sv` | UVM Coverage: 7 covergroup (instr, hazard, mem, branch, CSR, …) |
| `riscv_sequences.sv` | Thư viện sequences: reset, load, run, alu/mem/branch/hazard/csr/full/random |
| `riscv_agent_env_test.sv` | Agent + Env + Base Test class |
| `riscv_tests.sv` | Các test cụ thể: alu_test, mem_test, branch_test, hazard_test, csr_test, full_test, random_test |

---

### `sim/hex/` — Chương trình test dạng hex

| File | Mô tả |
|---|---|
| `full_test.hex` | Chương trình test tổng hợp |
| `alu_test.hex` | Test ALU R-type và I-type |
| `mem_test.hex` | Test load/store các width và alignment |
| `branch_test.hex` | Test branch taken/not-taken và JAL/JALR |
| `hazard_test.hex` | Test load-use stall |
| `csr_test.hex` | Test CSR instructions và ECALL/MRET |
| `extra_coverage.hex` | Bổ sung coverage còn thiếu |

---

### `sim/out/` — Output mô phỏng

```
sim/out/
├── dump_uvm.vcd      # Waveform từ UVM sim
├── uvm_sim.log       # Log UVM
└── legacy_sim.log    # Log legacy sim
```

---

## Makefile (QuestaSim)

Lưu nội dung bên dưới thành file tên `Makefile` đặt tại **thư mục gốc** của project.

```makefile
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
UVM_HOME   ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
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
  $(RTL_MEM)/EF_SRAM_1024x32_tt_180V_25C.v           \
  $(RTL_MEM)/EF_SRAM_1024x32.v                        \
  $(RTL_MEM)/axi_sram_wrapper.v                       \
  $(RTL_MEM)/axi_interconnect.v                       \
  $(RTL_CACHE)/l1_icache.v                            \
  $(RTL_CACHE)/l1_dcache.v                            \
  $(RTL_HAZARD)/hazard_unit.v                         \
  $(RTL_CSR)/csr_alu.v                                \
  $(RTL_CSR)/csr_file.v                               \
  $(RTL_DP)/adder.v                                   \
  $(RTL_DP)/mux.v                                     \
  $(RTL_DP)/extend.v                                  \
  $(RTL_DP)/pc.v                                      \
  $(RTL_DP)/register_file.v                           \
  $(RTL_DP)/alu.v                                     \
  $(RTL_CTRL)/alu_decoder.v                           \
  $(RTL_CTRL)/main_decoder.v                          \
  $(RTL_CTRL)/control_unit.v                          \
  $(RTL_CORE)/pipeline.v                              \
  $(RTL_CORE)/fetch_cycle.v                           \
  $(RTL_CORE)/decode_cycle.v                          \
  $(RTL_CORE)/execute_cycle.v                         \
  $(RTL_CORE)/memory_cycle.v                          \
  $(RTL_CORE)/writeback_cycle.v                       \
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
  +incdir+$(RTL_MEM)

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
compile_uvm: compile_rtl
	$(VLOG) -sv $(VLOG_COMMON_FLAGS)                  \
	  +incdir+$(UVM_SRC)                              \
	  +incdir+$(TB_UVM)                               \
	  $(UVM_SRC)/uvm_pkg.sv                           \
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
	  -L uvm                                          \
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
	    -L uvm                                        \
	    -do "coverage save -onexit $(SIM_OUT)/$$TEST_NAME.ucdb; run -all; quit -f" \
	    -l $(SIM_OUT)/$$TEST_NAME.log;                \
	done
	$(MAKE) coverage_report
	@echo ">>> Regression complete."

# ==============================================================
# TARGET: dọn dẹp
# ==============================================================
clean:
	rm -rf work/ $(SIM_OUT)/
	rm -f transcript vsim.wlf modelsim.ini
	@echo ">>> Cleaned."

.PHONY: work compile_rtl compile_legacy sim_legacy sim_legacy_gui \
        compile_uvm sim_uvm sim_uvm_gui coverage_report regression clean
```

---

## Hướng dẫn sử dụng nhanh

```bash
# Lần đầu: tạo thư mục output
mkdir -p sim/out

# Chạy legacy testbench
make sim_legacy

# Mở GUI cho legacy (xem waveform)
make sim_legacy_gui

# Chạy một UVM test cụ thể
make sim_uvm TEST=riscv_alu_test

# Chạy với seed cố định và verbosity cao
make sim_uvm TEST=riscv_branch_test SEED=42 VERBOSITY=UVM_HIGH

# Mở GUI cho UVM test
make sim_uvm_gui TEST=riscv_mem_test

# Chạy toàn bộ regression + xuất coverage HTML
make regression

# Dọn dẹp
make clean
```

---

## Lưu ý khi dùng QuestaSim

| Vấn đề | Giải pháp |
|---|---|
| `UVM_HOME` không đúng | Chạy `echo $QUESTA_HOME` và kiểm tra đường dẫn `verilog_src/uvm-*/src` |
| Lỗi `uvm_pkg not found` | Thêm `-L questa_uvm_pkg` vào lệnh `vsim` thay cho `-L uvm` |
| SRAM macro báo X | Thêm `+define+functional` vào `VLOG_COMMON_FLAGS` để bỏ timing check |
| Waveform không thấy nội bộ | Thêm `-voptargs="+acc"` vào lệnh `vsim` khi dùng GUI |
| `$readmemh` không tìm thấy .hex | Truyền `+HEX_DIR=sim/hex/` và sửa code dùng plusarg (xem bảng thay đổi bên dưới) |


