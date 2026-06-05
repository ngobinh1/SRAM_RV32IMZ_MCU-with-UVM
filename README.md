# Project Structure & File Organization

## Cây thư mục

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
| `riscv_mmu.v` | Đơn vị quản lý bộ nhớ (MMU) và phiên dịch địa chỉ ảo (Sv32) |
| `rvfi_tracer.sv` | Interface kết nối chuẩn RVFI (RISC-V Formal Interface) để gỡ lỗi |
| `riscv_defs.v` | Định nghĩa các hằng số, macros dùng trong core |

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
| `csr_file.v` | Lưu trữ CSR (mstatus, mtvec, mscratch, mepc, mcause, satp, v.v.); xử lý trap/exceptions |
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
| `l1_icache.v` | L1 I-Cache nâng cao: 2-Way Set Associative, AXI4-Lite master (read-only) |
| `l1_dcache.v` | L1 D-Cache nâng cao: 2-Way Set Associative write-back, AXI4-Lite master (read/write) |

---

### `rtl/memory/` — Bộ nhớ & bus AXI

| File | Mô tả |
|---|---|
| `axi_interconnect.v` | AXI4-Lite crossbar: 2 master (I-cache, D-cache) → 1 slave (SRAM) |
| `axi_sram_wrapper.v` | Chuyển đổi AXI4-Lite ↔ giao diện native của EF_SRAM |
| `EF_SRAM_1024x32.v` | Wrapper macro SRAM 1024×32 (Efabless) |
| `EF_SRAM_1024x32.tt_180V_25C.v` | Mô hình timing behavioral của EF_SRAM (tt corner) |
| `axi4_full_master.v` | Module AXI4 Full Master hỗ trợ giao dịch burst tốc độ cao |

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
| `tb_muldiv.v` | Testbench riêng lẻ cho khối nhân chia `muldiv_alu` |

---

### `tb/uvm/` — UVM Testbench (SystemVerilog)

| File | Mô tả |
|---|---|
| `tb_top.sv` | Module top của UVM TB: clock gen, DUT, interface, `run_test()` |
| `riscv_if.sv` | SystemVerilog Interface: clocking blocks, assertions, tasks load/clear |
| `riscv_tb_pkg.sv` | Package: import tất cả UVM components theo đúng thứ tự |
| `riscv_seq_item.sv` | Transaction class: stimulus + observed fields, `decode_instr()` |
| `riscv_driver.sv` | UVM Driver: điều khiển reset, load hex, chờ cycles |
| `riscv_monitor.sv` | UVM Monitor: theo dõi reg-write, mem-access, branch, all-instr, AXI |
| `riscv_scoreboard.sv` | UVM Scoreboard: ISS reference model, so sánh kết quả DUT |
| `riscv_coverage.sv` | UVM Coverage: 11 covergroup (instr, hazard, mem, branch, CSR, Cache, AXI, Issue...) |
| `riscv_sequences.sv` | Thư viện sequences: reset, load, run, alu/mem/branch/hazard/csr/full/random |
| `riscv_agent_env_test.sv` | RiscV Agent + Env + Base Test class |
| `riscv_tests.sv` | Các bài test UVM (alu, mem, branch, hazard, csr, full, random, smode, mmu...) |
| `axi_slave_agent/` | Sub-directory chứa Agent của AXI Slave dùng để test AXI Burst |

**Chi tiết thư mục con `axi_slave_agent/`**:

| File | Mô tả |
|---|---|
| `axi_slave_agent.sv` | Đóng gói Monitor, Driver, Sequencer cho AXI Slave |
| `axi_slave_if.sv` | Interface tín hiệu AXI-Lite & AXI-Full cho AXI Slave |
| `axi_slave_item.sv` | Định nghĩa transaction của AXI (read/write, addr, data, burst...) |
| `axi_slave_monitor.sv` | Monitor giám sát các transaction trên bus AXI |
| `axi_slave_driver.sv` | Driver điều khiển các phản hồi AXI (ready, valid, data, resp...) |
| `axi_slave_sequencer.sv` | Sequencer điều phối các transaction AXI Slave |

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
| `smode_test.hex` | Test Supervisor Mode |
| `mmu_test.hex` | Test Memory Management Unit |
| `mmu_deep_test.hex` | Test Memory Management Unit mở rộng |
| `extra_coverage.hex` | Bổ sung coverage còn thiếu |

---

### Các tệp cấu hình khác

| File | Mô tả |
|---|---|
| `Makefile` | Cấu hình quy trình mô phỏng (make sim_legacy, make sim_uvm, make clean) |
| `docs/spec.md` | Tài liệu đặc tả kỹ thuật chi tiết các khối trong hệ thống |
| `how_to_run.md` | Hướng dẫn chạy các lệnh make để test project |
| `.gitignore` | Bỏ qua các file sinh ra trong quá trình mô phỏng |

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

# Chạy toàn bộ regression
make regression

# Dọn dẹp
make clean
```
