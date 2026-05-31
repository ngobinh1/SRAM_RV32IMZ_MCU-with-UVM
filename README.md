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
│   ├── memory/
│   └── mult_div/
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
| `fetch_cycle.v` | Tầng IF: PC, nạp lệnh, tra cứu Branch Predictor |
| `branch_predictor.v` | Bộ dự đoán nhánh tĩnh/động (BTB + BHT) tại tầng IF |
| `decode_cycle.v` | Tầng ID: giải mã lệnh, đọc thanh ghi |
| `issue.v` | Tầng Issue: kiểm tra load-use hazard và điều kiện dispatch |
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

### `rtl/mult_div/` — Đơn vị tính toán nhân chia (M-Extension)

| File | Mô tả |
|---|---|
| `muldiv_alu.v` | Bộ đồng xử lý thực hiện các phép nhân (1 chu kỳ) và phép chia (32 chu kỳ) |

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
| `muldiv_test.hex` | Test các lệnh nhân chia (M-Extension) |
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
| `$readmemh` không tìm thấy .hex | Đảm bảo truyền đúng tham số `+HEX_DIR=sim/hex/` cho vsim |


