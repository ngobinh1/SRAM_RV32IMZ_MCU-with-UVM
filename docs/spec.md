# RISC-V 5-Stage Pipelined Processor — Specification

---


## Tổng quan kiến trúc

Thiết kế này là một bộ xử lý RISC-V RV32I 5 tầng pipeline, bao gồm:
- 5 tầng pipeline: **IF → ID → EX → MEM → WB** (và Issue Stage kiểm soát)
- **Hazard Unit**: forwarding (MEM→EX, WB→EX), stall (load-use), flush (branch/jump)
- **L1 I-Cache** và **L1 D-Cache** nâng cao: 2-Way Set Associative, write-back, AXI4-Lite master
- **AXI4-Lite Interconnect** 2M→1S + **AXI SRAM Wrapper** → **EF_SRAM 1024×32**
- **AXI4 Full Master**: Hỗ trợ giao tiếp Burst tốc độ cao.
- **CSR File**: mstatus, mtvec, mscratch, mepc, mcause, satp + ECALL/MRET
- **MMU**: Đơn vị quản lý bộ nhớ dịch địa chỉ ảo Sv32 sang vật lý, hỗ trợ Supervisor Mode (S-Mode).
- **M-Extension**: Đơn vị tính toán nhân chia (muldiv_alu).

Tài liệu này được trình bày theo trình tự từ các khối chức năng nhỏ nhất (Datapath, Control) đến các tầng Pipeline, bộ nhớ, và cuối cùng là Top Module.


---

## 1. MUX — `mux` / `mux_3_1` / `mux_4to1`

---

## 2. Adder — `adder`

---

## 3. Extend — `extend`

---

## 4. Program Counter — `pc`

---

## 5. ALU — `alu`

---

## 6. Register File — `register_file`

---

## 7. ALU Decoder — `alu_decoder`

---

## 8. Main Decoder — `main_decoder`

---

## 9. Đơn vị điều khiển — `control_unit`

---

## 10. Hazard Unit — `hazard_unit`

---

## 11. CSR ALU — `csr_alu`

---

## 12. CSR File — `csr_file`

---

## 13. Khối Nhân/Chia (Mul/Div) — `muldiv_alu`

---

## 14. Branch Predictor — `branch_predictor`

---

## 15. RISC-V MMU — `riscv_mmu`

---

## 16. AXI SRAM Wrapper — `axi_sram_wrapper`

---

## 17. EF SRAM — `EF_SRAM_1024x32`

---

## 18. AXI Interconnect — `axi_interconnect`

---

## 19. L1 I-Cache — `l1_icache`

---

## 20. L1 D-Cache — `l1_dcache`

---

## 21. AXI4 Full Master — `axi4_full_master`

---

## 22. Tầng Fetch — `fetch_cycle`

---

## 23. Tầng Decode — `decode_cycle`

---

## 24. Tầng Issue — `issue`

---

## 25. Tầng Execute — `execute_cycle`

---

## 26. Tầng Memory — `memory_cycle`

---

## 27. Tầng Writeback — `writeback_cycle`

---

## 28. Các thanh ghi Pipeline

---

## 29. RVFI Tracer — `rvfi_tracer`

---

## 30. Top Module — `riscv_pipeline_top`