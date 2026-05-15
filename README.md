# RISC-V 5-Stage Pipelined Processor — Specification

## Tổng quan kiến trúc

Thiết kế này là một bộ xử lý RISC-V RV32I 5 tầng pipeline, bao gồm:
- 5 tầng pipeline: **IF → ID → EX → MEM → WB**
- **Hazard Unit**: forwarding (MEM→EX, WB→EX), stall (load-use), flush (branch/jump)
- **L1 I-Cache** và **L1 D-Cache** direct-mapped 16 line, write-back, AXI4-Lite master
- **AXI4-Lite Interconnect** 2M→1S + **AXI SRAM Wrapper** → **EF_SRAM 1024×32**
- **CSR File**: mstatus, mtvec, mscratch, mepc, mcause + ECALL/MRET

---

## 1. Top Module — `riscv_pipeline_top`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock hệ thống |
| `rst` | Input | 1 | Reset tích cực thấp (0 = reset) |

> Module top không có output ra ngoài; tất cả giao tiếp nội bộ qua wire.

### Nguyên lý hoạt động

`riscv_pipeline_top` là module kết nối, không chứa logic. Nó khởi tạo và nối dây:
1. **Fetch Stage** → **Pipeline Reg F/D** → **Decode Stage** → **Pipeline Reg D/E** → **Execute Stage** → **Pipeline Reg E/M** → **Memory Stage** → **Pipeline Reg M/W** → **Writeback Stage**
2. **Hazard Unit** nhận tín hiệu từ tất cả các tầng và xuất `stall_*`, `flush_*`, `forward_*`
3. **L1 I-Cache / D-Cache** → **AXI Interconnect** → **AXI SRAM Wrapper** → **EF_SRAM**
4. **CSR File** đọc từ tầng Decode, ghi từ tầng Writeback

#### Sơ đồ kiến trúc tổng thể

```
  clk, rst
    │
    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                        riscv_pipeline_top                                     │
│                                                                               │
│  ┌─────────┐  F/D  ┌─────────┐  D/E  ┌─────────┐  E/M  ┌─────────┐  M/W  ┌─────────┐│
│  │  FETCH  │──────▶│ DECODE  │──────▶│EXECUTE  │──────▶│ MEMORY  │──────▶│WRITEBK ││
│  │(fetch_  │  reg  │(decode_ │  reg  │(execute_│  reg  │(memory_ │  reg  │(write-  ││
│  │ cycle)  │       │ cycle)  │       │ cycle)  │       │ cycle)  │       │back_cyc)││
│  └────┬────┘       └────┬────┘       └────┬────┘       └────┬────┘       └────┬────┘│
│       │                 │                  │                  │                 │     │
│       └─────────────────┴──────────────────┴──────────────────┴─────────────────┘     │
│                                          │                                            │
│                              ┌───────────┴───────────┐                               │
│                              │     hazard_unit        │                               │
│                              │  stall/flush/forward   │                               │
│                              └───────────────────────┘                               │
│                                                                                       │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌─────────────────────────┐│
│  │l1_icache │    │  l1_dcache   │    │axi_interconn │    │axi_sram_wrap + EF_SRAM  ││
│  │(M0: read)│    │(M1: rd+wr)   │───▶│  (2M → 1S)   │───▶│   1024×32 words         ││
│  └──────────┘    └──────────────┘    └──────────────┘    └─────────────────────────┘│
│                                                                                       │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │  csr_file  (mstatus, mtvec, mscratch, mepc, mcause) ◀── ECALL/MRET/CSRRW...   │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Tầng Fetch — `fetch_cycle`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Reset tích cực thấp |
| `en` | Input | 1 | Enable PC (= `~stall_f` từ Hazard Unit) |
| `pc_src_e` | Input | 1 | 1 = chọn `pc_target_e` thay vì PC+4 |
| `pc_target_e` | Input | 32 | PC đích khi branch/jump |
| `is_ecall` | Input | 1 | 1 = đang có ECALL → nạp `trap_vec` |
| `is_mret` | Input | 1 | 1 = đang có MRET → nạp `epc` |
| `trap_vec` | Input | 32 | Địa chỉ trap handler (từ CSR mtvec) |
| `epc` | Input | 32 | Địa chỉ trở về sau trap (từ CSR mepc) |
| `instr_f_in` | Input | 32 | Lệnh đọc từ I-Cache |
| `instr_f` | Output | 32 | Lệnh cho pipeline reg F/D |
| `pc_f` | Output | 32 | PC hiện tại |
| `pc_plus_4_f` | Output | 32 | PC + 4 |

### Nguyên lý hoạt động

```
pc_next_normal = pc_src_e ? pc_target_e : pc_plus_4_f
pc_next_final  = is_ecall ? trap_vec :
                 is_mret  ? epc      : pc_next_normal
PC            ← pc_next_final  (khi en=1)
```

PC chỉ cập nhật khi `en=1`. Khi `stall_f=1` (từ Hazard Unit), `en=0`, PC đóng băng.

#### Sơ đồ logic tầng Fetch

```
                      is_ecall ──┐
                                 │  ┌──────────────────────────────┐
            trap_vec ────────────┼─▶│                              │
                                 │  │   MUX ưu tiên (Priority MUX) │
               epc ──────────────┼─▶│                              │──▶ pc_next_final
                                 │  │  1. is_ecall → trap_vec      │
     pc_src_e ──┐    is_mret ────┘  │  2. is_mret  → epc           │
                │                   │  3. else     → pc_next_normal │
    pc_plus_4_f─┤                   └──────────────────────────────┘
                │
                ▼
   ┌────────────────────┐
   │   MUX 2:1          │──▶ pc_next_normal
   │  0: pc_plus_4_f    │
   │  1: pc_target_e    │
   └────────────────────┘
         ▲
   pc_target_e

                                           en (= ~stall_f)
                                                │
pc_next_final ──────────────────────────────▶┌─┴──────────┐
                                             │  PC Register│──▶ pc_f
                                             │  (clk, rst) │
                                             └────────────┘
                                                    │
                                             ┌──────┴──────┐
                                             │  ADDER +4   │──▶ pc_plus_4_f
                                             └─────────────┘

instr_f_in (từ I-Cache) ──────────────────────────────────▶ instr_f
```

---

## 3. Tầng Decode — `decode_cycle`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Reset |
| `reg_write_w` | Input | 1 | Enable ghi thanh ghi (từ WB) |
| `rd_w` | Input | 5 | Địa chỉ thanh ghi đích (từ WB) |
| `instr_d` | Input | 32 | Lệnh từ pipeline reg F/D |
| `result_w` | Input | 32 | Dữ liệu ghi vào thanh ghi (từ WB) |
| `pc_in` | Input | 32 | PC (không dùng trực tiếp trong module) |
| `pc_plus_4_in` | Input | 32 | PC+4 (không dùng trực tiếp) |
| `imm_ext_d` | Output | 32 | Immediate mở rộng dấu |
| `read_data_1_d` | Output | 32 | Dữ liệu đọc từ rs1 |
| `read_data_2_d` | Output | 32 | Dữ liệu đọc từ rs2 |
| `rs1_d` | Output | 5 | Địa chỉ rs1 (instr[19:15]) |
| `rs2_d` | Output | 5 | Địa chỉ rs2 (instr[24:20]) |
| `rd_d` | Output | 5 | Địa chỉ rd (instr[11:7]) |
| `reg_write_d` | Output | 1 | Tín hiệu ghi thanh ghi |
| `mem_write_d` | Output | 1 | Tín hiệu ghi bộ nhớ |
| `jump_d` | Output | 1 | Lệnh JAL/JALR |
| `branch_d` | Output | 1 | Lệnh branch |
| `alu_src_d` | Output | 1 | 0=rs2, 1=immediate |
| `jalr_d` | Output | 1 | Lệnh JALR cụ thể |
| `funct3_d` | Output | 3 | funct3 của lệnh |
| `result_src_d` | Output | 3 | Nguồn kết quả WB (00=ALU, 01=Mem, 10=PC+4, 11=CSR) |
| `alu_control_d` | Output | 4 | Mã lệnh ALU |
| `csr_we_d` | Output | 1 | Enable ghi CSR |
| `is_ecall_d` | Output | 1 | Lệnh ECALL |
| `is_mret_d` | Output | 1 | Lệnh MRET |

### Nguyên lý hoạt động

Module này chứa 3 sub-module:
- **`control_unit`**: giải mã opcode → tín hiệu điều khiển
- **`register_file`**: đọc 2 thanh ghi rs1, rs2; ghi rd (từ WB trong cùng chu kỳ với bypassing)
- **`extend`**: mở rộng immediate theo kiểu lệnh (I/S/B/J/U/CSR)

#### Sơ đồ logic tầng Decode

```
  instr_d [31:0]
       │
       ├──[6:0]──────▶ ┌────────────────────────────────────────────────────────┐
       ├──[14:12]────▶ │             control_unit                               │
       ├──[31:25]────▶ │  ┌─────────────────┐   ┌────────────────┐             │
       ├──[31:20]────▶ │  │  main_decoder    │   │  alu_decoder   │             │
       │               │  │  (opcode→ctrl)   │──▶│  (funct3/7→ALU)│             │
       │               │  └─────────────────┘   └────────────────┘             │
       │               └─────────────────────────────────────────────────────────┘
       │                    │            │              │           │
       │               reg_write    mem_write,      alu_control  imm_src,
       │               jump,branch  alu_src,jalr    [3:0]        result_src
       │               csr_we       is_ecall,mret
       │
       ├──[19:15]──▶ rs1_d ──▶ ┌──────────────────────────────────────────────┐
       ├──[24:20]──▶ rs2_d ──▶ │         register_file (32 × 32-bit)          │
       ├──[11:7]───▶ rd_d       │                                              │
       │              ▲         │  Đọc tổ hợp:                                  │──▶ read_data_1_d
       │              │         │  • addr_1 (rs1) → read_data_1                 │──▶ read_data_2_d
       │    rd_w ─────┘         │  • addr_2 (rs2) → read_data_2                 │
       │    result_w ──────────▶│  Bypass: nếu rs==rd_w → trả về result_w ngay  │
       │    reg_write_w ────────▶│  Ghi đồng bộ (posedge): addr_3=rd_w, we=1    │
       │                         └──────────────────────────────────────────────┘
       │
       └──[31:0]──▶ ┌──────────────────────────────────────────────────────────┐
         imm_src ──▶│                  extend                                  │──▶ imm_ext_d
                    │  000→I/U, 001→S, 010→B, 011→J, 100→CSR(zero-ext)         │
                    └──────────────────────────────────────────────────────────┘
```

---

## 4. Tầng Execute — `execute_cycle`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `forward_a_e` | Input | 2 | Forwarding cho src_a (00=reg, 01=WB, 10=MEM) |
| `forward_b_e` | Input | 2 | Forwarding cho src_b |
| `jump_e` | Input | 1 | Lệnh jump |
| `branch_e` | Input | 1 | Lệnh branch |
| `alu_src_e` | Input | 1 | 0=rs2, 1=immediate |
| `jalr_e` | Input | 1 | JALR |
| `funct3_e` | Input | 3 | funct3 (chọn điều kiện branch) |
| `alu_control_e` | Input | 4 | Mã lệnh ALU |
| `alu_result_m` | Input | 32 | Forwarding từ MEM stage |
| `read_data_1_e` | Input | 32 | rs1 từ pipeline reg D/E |
| `read_data_2_e` | Input | 32 | rs2 từ pipeline reg D/E |
| `imm_ext_e` | Input | 32 | Immediate |
| `pc_e` | Input | 32 | PC |
| `pc_plus_4_e` | Input | 32 | PC+4 |
| `result_w` | Input | 32 | Forwarding từ WB stage |
| `rd_e` | Input | 5 | Địa chỉ rd |
| `pc_target_e` | Output | 32 | Địa chỉ đích branch/jump |
| `alu_result_e` | Output | 32 | Kết quả ALU |
| `write_data_e` | Output | 32 | Dữ liệu store (rs2 sau forwarding) |
| `pc_src_e` | Output | 1 | 1 = cần thay đổi PC (branch taken hoặc jump) |

### Nguyên lý hoạt động

```
src_a_e    = mux_3_1(read_data_1_e, result_w, alu_result_m, forward_a_e)
src_b_int  = mux_3_1(read_data_2_e, result_w, alu_result_m, forward_b_e)
src_b_e    = mux(src_b_int, imm_ext_e, alu_src_e)
alu_in_a   = (alu_control==AUIPC) ? pc_e : src_a_e
alu_result = ALU(alu_in_a, src_b_e, alu_control)

branch_taken = (BEQ: zero) | (BNE: ~zero) | (BLT: neg≠ov) | ...
pc_target  = jalr_e ? (alu_result & ~1) : (pc_e + imm_ext_e)
pc_src_e   = (branch_taken & branch_e) | jump_e
```

#### Sơ đồ logic tầng Execute

```
 read_data_1_e ──┐
 result_w ───────┼──▶ ┌─────────────┐
 alu_result_m ───┘    │  MUX 3:1    │──▶ src_a_e ──┐
     forward_a_e ────▶│(00/01/10)   │              │
                      └─────────────┘              │
                                                   │         ┌────────────────┐
 read_data_2_e ──┐                                 │         │                │
 result_w ───────┼──▶ ┌─────────────┐              │    ┌───▶│      ALU       │──▶ alu_result_e
 alu_result_m ───┘    │  MUX 3:1    │──▶ src_b_int─┼────┤   │  alu_control_e │    (zero,neg,ov,carry)
     forward_b_e ────▶│(00/01/10)   │    │         │    │   └────────────────┘
                      └─────────────┘    │         │    │
                              ┌──────────┘         │    │
                              ▼                    │    │   AUIPC?
                      ┌─────────────┐              └────┼─▶ if(alu_ctrl==1000): pc_e
                      │  MUX 2:1    │──▶ src_b_e        │   else:              src_a_e
                      │ alu_src_e   │        ▲           │
                      └─────────────┘        │           └─▶ write_data_e
                            ▲         imm_ext_e
                        src_b_int

 Branch Logic:
 funct3_e ──▶ ┌─────────────────────────────────────┐
 zero,neg,ov,─┤  branch_taken = f(funct3, flags)     │
 carry        │  BEQ:zero  BNE:~zero  BLT:neg≠ov     │
              │  BGE:neg==ov  BLTU:~carry  BGEU:carry │
              └────────────────┬────────────────────--┘
                               │
 branch_e ────────────────▶ AND─┐
 jump_e ──────────────────────OR──▶ pc_src_e

 PC Target:
 pc_e + imm_ext_e ──▶ ┌─────────────┐
 alu_result & ~1  ──▶ │  MUX 2:1    │──▶ pc_target_e
     jalr_e ─────────▶│(0:branch    │
                       │ 1:JALR)     │
                       └─────────────┘
```

---

## 5. Tầng Memory — `memory_cycle`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock (không dùng trong logic tổ hợp) |
| `rst` | Input | 1 | Reset |
| `mem_write_m` | Input | 1 | Enable store |
| `alu_result_m` | Input | 32 | Địa chỉ bộ nhớ |
| `write_data_m` | Input | 32 | Dữ liệu cần ghi (từ pipeline reg) |
| `funct3_m` | Input | 3 | Kiểu load/store (lb/lh/lw/lbu/lhu/sb/sh/sw) |
| `read_data_m_in` | Input | 32 | Dữ liệu đọc thô từ D-Cache |
| `read_data_m` | Output | 32 | Dữ liệu sau khi sign/zero-extend |
| `write_data_m_out` | Output | 32 | Dữ liệu store sau khi căn chỉnh byte |

### Nguyên lý hoạt động

Module thực hiện **căn chỉnh dữ liệu** cho sub-word access:

**Store alignment** (`write_data_m_out`):
```
byte_offset = alu_result_m[1:0]
shift_amt   = {byte_offset, 3'b000}   // 0, 8, 16, 24 bit
sb/sh: write_data << shift_amt
sw:    write_data (không dịch)
```

**Load sign/zero-extend** (`read_data_m`):
```
shifted = read_data_m_in >> shift_amt
lb:  sign-extend 8 bit
lh:  sign-extend 16 bit
lw:  giữ nguyên 32 bit
lbu: zero-extend 8 bit
lhu: zero-extend 16 bit
```

#### Sơ đồ logic tầng Memory

```
 STORE PATH (write alignment):
 ─────────────────────────────
 alu_result_m[1:0] ──▶ byte_offset
                              │
                              ▼
                    shift_amt = {byte_offset, 3'b000}
                         (0 / 8 / 16 / 24)
                              │
 write_data_m ──▶ ┌───────────┴───────────┐
                  │  funct3_m:             │──▶ write_data_m_out
                  │  sb/sh: data<<shift_amt│    (gửi tới D-Cache)
                  │  sw:    data (giữ nguyên)│
                  └───────────────────────┘

 LOAD PATH (sign/zero extension):
 ─────────────────────────────────
 alu_result_m[1:0] ──▶ byte_offset ──▶ shift_amt
                                               │
 read_data_m_in ──▶ ┌──────────────────────────┘
                    │  >> shift_amt ──▶ shifted_word
                    │                         │
                    │  funct3_m:               │
                    │  lb:  {{24{bit7}}, [7:0]}│──▶ read_data_m
                    │  lh:  {{16{bit15}},[15:0]}│    (gửi tới WB)
                    │  lw:  read_data_m_in     │
                    │  lbu: {24'b0, [7:0]}      │
                    │  lhu: {16'b0, [15:0]}     │
                    └──────────────────────────┘

 Ví dụ LB tại byte_offset=1:
 ┌──────┬──────┬──────┬──────┐
 │ B3   │ B2   │ B1   │ B0   │  ← word từ memory
 └──────┴──────┴──────┴──────┘
    ▶ shift right 8 bit ▶ lấy [7:0] ▶ sign-extend 24 bit
```

---

## 6. Tầng Writeback — `writeback_cycle`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `result_src_w` | Input | 3 | Chọn nguồn kết quả |
| `alu_result_w` | Input | 32 | Kết quả ALU |
| `read_data_w` | Input | 32 | Dữ liệu từ bộ nhớ (load) |
| `pc_plus_4_w` | Input | 32 | PC+4 (dùng cho JAL/JALR) |
| `csr_rd_w` | Input | 32 | Dữ liệu đọc từ CSR |
| `result_w` | Output | 32 | Dữ liệu ghi vào thanh ghi |

### Nguyên lý hoạt động

```
result_w = mux_4to1(alu_result_w, read_data_w, pc_plus_4_w, csr_rd_w, result_src_w)
  00 → ALU result (R-type, I-type ALU, LUI, AUIPC)
  01 → Memory (load)
  10 → PC+4 (JAL/JALR)
  11 → CSR (csrrw/csrrs/csrrc)
```

#### Sơ đồ logic tầng Writeback

```
 alu_result_w ──▶ D0 ─┐
 read_data_w  ──▶ D1 ─┤
 pc_plus_4_w  ──▶ D2 ─┤─▶ ┌──────────────────┐
 csr_rd_w     ──▶ D3 ─┘   │    MUX 4:1        │──▶ result_w ──▶ Register File (rd)
                           │                  │
 result_src_w[2:0] ───────▶│  00: ALU result  │
                           │  01: Memory read │
                           │  10: PC+4        │
                           │  11: CSR read    │
                           └──────────────────┘

 Lệnh ánh xạ tới result_src_w:
 ┌────────────────┬──────────────┐
 │ Nhóm lệnh      │ result_src_w │
 ├────────────────┼──────────────┤
 │ ADD/SUB/AND/.. │     000      │
 │ LUI/AUIPC      │     000      │
 │ LW/LH/LB/..    │     001      │
 │ JAL/JALR       │     010      │
 │ CSRRW/CSRRS/.. │     011      │
 └────────────────┴──────────────┘
```

---

## 7. Các thanh ghi Pipeline

### `pipeline_1_2` (Fetch → Decode)

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk, rst` | Input | 1 | Clock, reset |
| `clr` | Input | 1 | Flush (= `flush_d`) |
| `en` | Input | 1 | Enable (= `~stall_d`) |
| `instr_f, pc_f, pc_plus_4_f` | Input | 32 | Dữ liệu từ tầng IF |
| `instr_d, pc_d, pc_plus_4_d` | Output | 32 | Dữ liệu sang tầng ID |

Khi `clr=1`: ghi `NOP (0x00000000)`. Khi `en=0`: giữ nguyên (stall).

### `pipeline_2_3` (Decode → Execute)

Truyền toàn bộ tín hiệu điều khiển + dữ liệu từ Decode sang Execute, bao gồm thêm: `csr_we`, `csr_addr`, `csr_rd`. Flush khi `flush_e=1`.

### `pipeline_3_4` (Execute → Memory)

Truyền: `reg_write`, `mem_write`, `result_src`, `alu_result`, `write_data`, `pc_plus_4`, `rd`, `funct3`, `csr_we/addr/rd/wd`.

### `pipeline_4_5` (Memory → Writeback)

Truyền: `reg_write`, `result_src`, `alu_result`, `read_data`, `pc_plus_4`, `rd`, `csr_we/addr/rd/wd`.

#### Sơ đồ hoạt động Pipeline Register (chung)

```
         clr (flush)    en (stall)
              │               │
              ▼               ▼
    ┌─────────────────────────────────────────┐
    │         PIPELINE REGISTER               │
    │                                         │
    │   posedge clk:                          │
    │   ┌─ if (!rst || clr)                   │
    │   │   reg ← 0 (NOP / bubble)            │
    │   └─ else if (en)                       │
    │       reg ← input_data                  │
    │       (khi stall: giữ nguyên)           │
    └─────────────────────────────────────────┘

 clr=1  → Flush:  chèn NOP vào tầng tiếp theo
 en=0   → Stall:  giữ nguyên giá trị (đóng băng tầng)
 en=1, clr=0 → Normal: cập nhật giá trị mới
```

---

## 8. Đơn vị điều khiển — `control_unit`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `op` | Input | 7 | Opcode (instr[6:0]) |
| `funct7` | Input | 7 | funct7 (instr[31:25]) |
| `funct3` | Input | 3 | funct3 (instr[14:12]) |
| `imm12` | Input | 12 | instr[31:20] (dùng phân biệt ECALL/MRET) |
| `reg_write` | Output | 1 | Enable ghi thanh ghi |
| `mem_write` | Output | 1 | Enable ghi bộ nhớ |
| `alu_src` | Output | 1 | 0=rs2, 1=immediate |
| `jump` | Output | 1 | JAL/JALR |
| `branch` | Output | 1 | Branch |
| `jalr` | Output | 1 | JALR |
| `result_src` | Output | 3 | Nguồn WB |
| `imm_src` | Output | 3 | Kiểu immediate |
| `alu_control` | Output | 4 | Mã ALU |
| `csr_we` | Output | 1 | Ghi CSR |
| `is_ecall` | Output | 1 | ECALL |
| `is_mret` | Output | 1 | MRET |

### Nguyên lý hoạt động

- Phát hiện **ECALL**: `opcode=1110011`, `funct3=000`, `imm12=0x000`
- Phát hiện **MRET**: `opcode=1110011`, `funct3=000`, `imm12=0x302`
- **CSR write enable**: `opcode=1110011` và `funct3≠000`
- Khi ECALL/MRET: `reg_write=0` (ngăn ghi thanh ghi)
- Dùng `funct3_modified` để phân biệt LUI (`001`) và AUIPC (`000`) cho ALU decoder

#### Sơ đồ logic control_unit

```
 op[6:0], funct3, funct7, imm12
          │
          ▼
 ┌────────────────────────────────────────────────────────┐
 │                   control_unit                         │
 │                                                        │
 │  ┌─ is_system = (op == 1110011)                        │
 │  │                                                     │
 │  ├─ is_ecall  = is_system & (funct3==000) & (imm12==0) │──▶ is_ecall
 │  │                                                     │
 │  ├─ is_mret   = is_system & (funct3==000) & (imm12=302)│──▶ is_mret
 │  │                                                     │
 │  ├─ csr_we    = is_system & (funct3 != 000)            │──▶ csr_we
 │  │                                                     │
 │  ├─ funct3_modified:                                   │
 │  │   LUI(0110111) → 001                                │
 │  │   AUIPC(0010111) → 000                              │
 │  │   else → funct3                                     │
 │  │                                                     │
 │  ├──▶ main_decoder(op) ──────────────────────────────▶ reg_write_raw,
 │  │                                                    mem_write, alu_src,
 │  │                                                    jump, branch, jalr,
 │  │                                                    result_src, imm_src, alu_op
 │  │
 │  ├──▶ alu_decoder(alu_op, funct3_modified, funct7, op)──▶ alu_control[3:0]
 │  │
 │  └─ reg_write = reg_write_raw & !(is_ecall | is_mret)  ──▶ reg_write
 │
 └────────────────────────────────────────────────────────┘
```

---

## 9. Main Decoder — `main_decoder`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `op` | Input | 7 | Opcode |
| `reg_write` | Output | 1 | Ghi thanh ghi |
| `alu_op` | Output | 2 | `00`=ADD, `01`=SUB(branch), `10`=funct3/7, `11`=upper-imm |
| `imm_src` | Output | 3 | `000`=I, `001`=S, `010`=B, `011`=J, `100`=CSR |
| `mem_write` | Output | 1 | Store |
| `alu_src` | Output | 1 | Nguồn ALU B |
| `result_src` | Output | 3 | Nguồn WB |
| `branch` | Output | 1 | Branch |
| `jump` | Output | 1 | Jump |
| `jalr` | Output | 1 | JALR |

### Bảng giải mã Opcode → Tín hiệu

| Lệnh | Opcode | reg_write | alu_src | mem_write | result_src | alu_op | imm_src |
|---|---|---|---|---|---|---|---|
| R-type | 0110011 | 1 | 0 | 0 | 00 | 10 | - |
| I-ALU | 0010011 | 1 | 1 | 0 | 00 | 10 | 000 |
| Load | 0000011 | 1 | 1 | 0 | 01 | 00 | 000 |
| Store | 0100011 | 0 | 1 | 1 | - | 00 | 001 |
| Branch | 1100011 | 0 | 0 | 0 | - | 01 | 010 |
| JAL | 1101111 | 1 | - | 0 | 10 | 00 | 011 |
| JALR | 1100111 | 1 | 1 | 0 | 10 | 00 | 000 |
| LUI | 0110111 | 1 | 1 | 0 | 00 | 11 | 000 |
| AUIPC | 0010111 | 1 | 1 | 0 | 00 | 11 | 000 |
| CSR | 1110011 | 1* | - | 0 | 11 | - | 100 |

*`reg_write` cho CSR bị override bởi `control_unit` khi ECALL/MRET.

#### Sơ đồ logic main_decoder

```
  op[6:0]
     │
     ▼
 ┌───────────────────────────────────────────────────┐
 │               main_decoder                        │
 │                                                   │
 │  7-bit opcode ──▶ combinational logic:             │
 │                                                   │
 │  0110011 (R)   → reg_write=1, alu_src=0, alu_op=10│
 │  0010011 (I)   → reg_write=1, alu_src=1, alu_op=10│
 │  0000011 (Load)→ reg_write=1, result_src=01       │
 │  0100011 (Store)→ mem_write=1, imm_src=001        │
 │  1100011 (Branch)→ branch=1, alu_op=01, imm_src=010│
 │  1101111 (JAL) → jump=1, result_src=10, imm_src=011│
 │  1100111 (JALR)→ jalr=1, jump=1, alu_src=1        │
 │  0110111 (LUI) → alu_op=11                        │
 │  0010111 (AUIPC)→ alu_op=11                       │
 │  1110011 (CSR) → result_src=11, imm_src=100       │
 └────────────────────────────────────────────────────┘
     │         │         │         │         │
  reg_write mem_write alu_src   alu_op   imm_src
  jump,branch,jalr  result_src
```

---

## 10. ALU Decoder — `alu_decoder`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `alu_op` | Input | 2 | Từ main_decoder |
| `funct3` | Input | 3 | funct3 (có thể bị modify cho LUI/AUIPC) |
| `funct7` | Input | 7 | funct7 |
| `op` | Input | 7 | Opcode (phân biệt R/I-type ADD vs SUB) |
| `alu_control` | Output | 4 | Mã điều khiển ALU |

### Bảng mã `alu_control`

| Mã | Phép tính | Lệnh |
|---|---|---|
| 0000 | ADD | add, addi, lw, sw, jal, jalr |
| 0001 | SUB | sub, branch comparison |
| 0010 | AND | and, andi |
| 0011 | OR | or, ori |
| 0100 | XOR | xor, xori |
| 0101 | SLT | slt, slti |
| 0110 | SLTU | sltu, sltiu |
| 1000 | AUIPC | PC + (imm<<12) |
| 1001 | LUI | pass immediate |
| 1010 | SLL | sll, slli |
| 1011 | SRA | sra, srai |
| 1100 | SRL | srl, srli |

#### Sơ đồ logic alu_decoder

```
  alu_op[1:0]
       │
       ├── 00 ──────────────────────────────────────▶ 0000 (ADD)  [Load/Store]
       │
       ├── 01 ──────────────────────────────────────▶ 0001 (SUB)  [Branch compare]
       │
       ├── 10 ──▶ funct3[2:0]
       │               │
       │         ├─ 000 ──▶ {op[5], funct7[5]}
       │         │               ├─ 11 → 0001 (SUB)   [R-type SUB]
       │         │               └─ else→ 0000 (ADD)  [ADD/ADDI]
       │         ├─ 001 ──────────────────────────────▶ 1010 (SLL)
       │         ├─ 010 ──────────────────────────────▶ 0101 (SLT)
       │         ├─ 011 ──────────────────────────────▶ 0110 (SLTU)
       │         ├─ 100 ──────────────────────────────▶ 0100 (XOR)
       │         ├─ 101 ──▶ funct7[5]
       │         │               ├─ 1 → 1011 (SRA)
       │         │               └─ 0 → 1100 (SRL)
       │         ├─ 110 ──────────────────────────────▶ 0011 (OR)
       │         └─ 111 ──────────────────────────────▶ 0010 (AND)
       │
       └── 11 ──▶ funct3[2:0] (LUI/AUIPC modified)
                      ├─ 000 (AUIPC) ──────────────────▶ 1000
                      └─ 001 (LUI)   ──────────────────▶ 1001
```

---

## 11. ALU — `alu`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `a` | Input | 32 | Toán hạng A |
| `b` | Input | 32 | Toán hạng B |
| `alu_control` | Input | 4 | Mã lệnh |
| `overflow` | Output | 1 | Tràn số (ADD/SUB có dấu) |
| `carry` | Output | 1 | Carry out (ADD/SUB) |
| `neg` | Output | 1 | Bit dấu của kết quả |
| `zero` | Output | 1 | Kết quả = 0 (dùng cho BEQ) |
| `result` | Output | 32 | Kết quả phép tính |

### Nguyên lý hoạt động

Dùng shared adder: `b_inv = (alu_control[0]) ? ~b : b`, `sum = a + b_inv + alu_control[0]`. Phép SUB là ADD với bù hai. Các cờ `zero`, `neg`, `overflow` dùng cho branch condition:

| Branch | Điều kiện |
|---|---|
| BEQ | `zero` |
| BNE | `~zero` |
| BLT | `neg ≠ overflow` |
| BGE | `neg == overflow` |
| BLTU | `~carry` |
| BGEU | `carry` |

#### Sơ đồ logic ALU

```
  a[31:0] ─────────────────────────────────────────┐
                                                    │
  b[31:0] ──▶ ┌──────────────────────┐              │
              │  b_inv               │              ▼
  alu_ctrl[0]▶│  ctrl[0]=1 → ~b      │──▶ b_inv ──▶ ADDER ──▶ {cout, sum[31:0]}
              │  ctrl[0]=0 →  b      │              ▲
              └──────────────────────┘              │ alu_ctrl[0] (SUB=1 → +1)

                    alu_control[3:0]
                          │
                          ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                     ALU MUX / Logic                          │
   │                                                              │
   │  0000 → result = sum           (ADD)                         │
   │  0001 → result = sum           (SUB = a + ~b + 1)            │
   │  0010 → result = a & b         (AND)                         │
   │  0011 → result = a | b         (OR)                          │
   │  0100 → result = a ^ b         (XOR)                         │
   │  0101 → result = signed(a<b)   (SLT)                         │
   │  0110 → result = unsigned(a<b) (SLTU)                        │
   │  1000 → result = a + b         (AUIPC: PC + imm)             │
   │  1001 → result = b             (LUI: pass imm)               │
   │  1010 → result = a << b[4:0]   (SLL)                         │
   │  1011 → result = a >>> b[4:0]  (SRA arithmetic)              │
   │  1100 → result = a >> b[4:0]   (SRL logical)                 │
   └──────────────────────────────────────────────────────────────┘
          │
          ▼
      result[31:0]

  FLAGS (tổ hợp từ sum và result):
  ┌────────────────────────────────────────────────────┐
  │  zero     = (result == 0)                          │
  │  neg      = result[31]                             │
  │  carry    = cout & ~alu_ctrl[1]                    │
  │  overflow = (sum[31]^a[31]) & ~(ctrl[0]^b[31]^a[31]) & ~ctrl[1]│
  └────────────────────────────────────────────────────┘
```

---

## 12. Register File — `register_file`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Reset |
| `write_en_3` | Input | 1 | Enable ghi |
| `addr_1` | Input | 5 | Địa chỉ đọc rs1 |
| `addr_2` | Input | 5 | Địa chỉ đọc rs2 |
| `addr_3` | Input | 5 | Địa chỉ ghi rd |
| `write_data_3` | Input | 32 | Dữ liệu ghi |
| `read_data_1` | Output | 32 | Dữ liệu rs1 |
| `read_data_2` | Output | 32 | Dữ liệu rs2 |

### Nguyên lý hoạt động

- **Ghi đồng bộ** (posedge clk): ghi khi `write_en_3=1` và `addr_3≠0`
- **Đọc tổ hợp + bypassing nội bộ**: nếu đang đọc cùng địa chỉ đang ghi → trả về `write_data_3` ngay lập tức (tránh hazard 1 cycle trong WB/ID)
- `x0` luôn trả về `32'h0` dù có ghi

#### Sơ đồ logic Register File

```
         WRITE PORT (đồng bộ)
         write_en_3, addr_3[4:0], write_data_3[31:0]
               │           │              │
               ▼           ▼              ▼
         ┌─────────────────────────────────────────────┐
         │         register_array [0:31][31:0]          │
         │                                             │
         │   posedge clk:                              │
         │   if (!rst) → reset tất cả về 0             │
         │   else if (write_en_3 && addr_3 != 0)       │
         │       register_array[addr_3] ← write_data_3 │
         └─────────────────────────────────────────────┘
               │                         │
               ▼ READ PORT 1             ▼ READ PORT 2
         addr_1[4:0]                 addr_2[4:0]
               │                         │
               ▼                         ▼
   ┌───────────────────────┐   ┌───────────────────────┐
   │  Combinational + Bypass│   │  Combinational + Bypass│
   │                        │   │                        │
   │  addr_1==0 → 0         │   │  addr_2==0 → 0         │
   │  addr_1==addr_3 & we   │   │  addr_2==addr_3 & we   │
   │    → write_data_3      │   │    → write_data_3      │
   │  else → reg_arr[addr_1]│   │  else → reg_arr[addr_2]│
   └───────────────────────┘   └───────────────────────┘
               │                         │
         read_data_1               read_data_2
```

---

## 13. Extend — `extend`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `instr` | Input | 32 | Lệnh 32-bit |
| `imm_src` | Input | 3 | Kiểu mở rộng |
| `imm_ext` | Output | 32 | Immediate mở rộng |

### Bảng kiểu mở rộng

| `imm_src` | Kiểu | Bits lấy | Ghi chú |
|---|---|---|---|
| 000 | I-type / U-type | instr[31:20] (I), instr[31:12]<<12 (LUI/AUIPC) | Tự phát hiện qua opcode |
| 001 | S-type | {instr[31:25], instr[11:7]} | Store |
| 010 | B-type | {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0} | Branch |
| 011 | J-type | {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0} | JAL |
| 100 | CSR | {27'b0, instr[19:15]} | Zero-extend rs1/zimm |

#### Sơ đồ trích xuất immediate

```
Instruction [31:0]:
┌──────────────────────────────────────────────────────────────────┐
│31    25│24  20│19  15│14 12│11    7│6       0│  ← vị trí bit     │
│ funct7 │ rs2  │ rs1  │fn3  │  rd   │ opcode  │                   │
└──────────────────────────────────────────────────────────────────┘

imm_src=000 (I-type):
  imm_ext = { {20{instr[31]}}, instr[31:20] }
  Bits lấy: ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔

  (nếu LUI/AUIPC): imm_ext = { instr[31:12], 12'b0 }

imm_src=001 (S-type):
  imm_ext = { {20{instr[31]}}, instr[31:25], instr[11:7] }
                               ▔▔▔▔▔▔▔▔▔▔▔▔▔  ▔▔▔▔▔▔▔▔▔▔

imm_src=010 (B-type):
  imm_ext = { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 }
  Bit12=instr[31], Bit11=instr[7], Bit10:5=instr[30:25], Bit4:1=instr[11:8], Bit0=0

imm_src=011 (J-type):
  imm_ext = { {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 }
  Bit20=instr[31], Bit19:12=instr[19:12], Bit11=instr[20], Bit10:1=instr[30:21]

imm_src=100 (CSR):
  imm_ext = { 27'b0, instr[19:15] }   ← zero-extend rs1/zimm field
```

---

## 14. Program Counter — `pc`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Reset tích cực thấp |
| `en` | Input | 1 | Enable cập nhật |
| `pc_next` | Input | 32 | Giá trị PC tiếp theo |
| `pc` | Output | 32 | PC hiện tại |

Khi `rst=0`: `pc ← 0`. Khi `en=1`: `pc ← pc_next`. Khi `en=0`: giữ nguyên.

#### Sơ đồ logic PC

```
  rst=0 ──────────────────────▶ pc ← 0x00000000
                                      ▲
  pc_next ─────────┐                  │
                   │  posedge clk:    │
                   ▼                  │
             ┌───────────┐            │
  en=1 ─────▶│ MUX 2:1  │────────────┘
             │  1: pc_next│
  en=0 ─────▶│  0: pc     │ (giữ nguyên)
             └───────────┘

  Chuỗi thời gian:
  Cycle:     │  0  │  1  │  2  │  3  │
  en:        │  1  │  0  │  1  │  1  │
  pc_next:   │  4  │ 8   │  8  │ 12  │
  pc:        │  0  │  4  │  4  │  8  │
               ▲rst=1 released
```

---

## 15. Hazard Unit — `hazard_unit`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `rst` | Input | 1 | Reset |
| `reg_write_m` | Input | 1 | MEM stage có ghi thanh ghi |
| `reg_write_w` | Input | 1 | WB stage có ghi thanh ghi |
| `pc_src_e` | Input | 1 | Branch/jump taken |
| `rd_m` | Input | 5 | Rd của lệnh ở MEM |
| `rd_w` | Input | 5 | Rd của lệnh ở WB |
| `rs1_e, rs2_e` | Input | 5 | Rs của lệnh ở EX |
| `rd_e` | Input | 5 | Rd của lệnh ở EX |
| `rs1_d, rs2_d` | Input | 5 | Rs của lệnh ở ID |
| `result_src_e` | Input | 3 | Kiểu lệnh ở EX (bit[0]=1: load) |
| `icache_stall` | Input | 1 | I-Cache đang fetch |
| `dcache_stall` | Input | 1 | D-Cache đang fetch/evict |
| `forward_a_e` | Output | 2 | Forwarding MUX cho src_a |
| `forward_b_e` | Output | 2 | Forwarding MUX cho src_b |
| `stall_f/d/e/m/w` | Output | 1×5 | Stall từng tầng |
| `flush_e` | Output | 1 | Flush tầng Execute |
| `flush_d` | Output | 1 | Flush tầng Decode |

### Nguyên lý hoạt động

**Forwarding** (ưu tiên MEM > WB):
```
forward_a_e = 10 nếu (rs1_e==rd_m) && reg_write_m && rs1_e≠0  ← từ MEM
            = 01 nếu (rs1_e==rd_w) && reg_write_w && rs1_e≠0  ← từ WB
            = 00  ← không forward
```

**Load-Use Stall**:
```
stall = result_src_e[0] && rd_e≠0 && (rs1_d==rd_e || rs2_d==rd_e)
→ stall_f=1, stall_d=1 (đóng băng IF và ID)
→ flush_e=1 (chèn bubble vào EX)
```

**Stall ưu tiên**:
```
dcache_stall → stall tất cả 5 tầng (hệ thống đóng băng hoàn toàn)
icache_stall → stall IF và ID (EX/MEM/WB tiếp tục chạy)
load-use     → stall IF và ID, flush EX
branch/jump  → flush_d=1, flush_e=1 (loại bỏ 2 lệnh sai)
```

#### Sơ đồ logic Hazard Unit

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │                       hazard_unit                                   │
 │                                                                     │
 │  FORWARDING LOGIC:                                                  │
 │  ┌──────────────────────────────────────────────────────────────┐   │
 │  │  rs1_e, rd_m, reg_write_m → forward_a_e:                     │   │
 │  │    IF (rs1_e==rd_m) & reg_write_m & rs1_e≠0 → 10 (MEM fwd)  │   │
 │  │    ELIF (rs1_e==rd_w) & reg_write_w & rs1_e≠0 → 01 (WB fwd) │   │
 │  │    ELSE → 00 (no forward)                                    │──▶ forward_a_e
 │  │  (tương tự cho rs2_e → forward_b_e)                          │──▶ forward_b_e
 │  └──────────────────────────────────────────────────────────────┘   │
 │                                                                     │
 │  STALL/FLUSH PRIORITY:                                              │
 │  ┌──────────────────────────────────────────────────────────────┐   │
 │  │                                                              │   │
 │  │  dcache_stall=1:                                             │   │
 │  │    stall_f=stall_d=stall_e=stall_m=stall_w = 1              │   │
 │  │                                                              │   │
 │  │  ELSE IF icache_stall=1:                                     │   │
 │  │    stall_f=1, stall_d=1  (stall_e/m/w=0)                    │   │
 │  │                                                              │   │
 │  │  ELSE IF load_use_stall:                                     │   │
 │  │    (result_src_e[0] && rd_e≠0 &&                            │   │
 │  │     (rs1_d==rd_e || rs2_d==rd_e))                           │   │
 │  │    stall_f=1, stall_d=1                                      │   │
 │  │                                                              │   │
 │  └──────────────────────────────────────────────────────────────┘   │
 │                                                                     │
 │  FLUSH:                                                             │
 │    flush_d = pc_src_e & ~dcache_stall                          ──▶ flush_d
 │    flush_e = (stall | pc_src_e | icache_stall) & ~dcache_stall ──▶ flush_e
 │                                                                     │
 └─────────────────────────────────────────────────────────────────────┘

 Forwarding path trong pipeline:
 ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐
 │ IF │→ │ ID │→ │ EX │→ │ MEM│→ │ WB │
 └────┘  └────┘  └─┬──┘  └──┬─┘  └──┬─┘
                   ▲ MUX    │        │
                   │◀────────┘(10)   │
                   │◀────────────────┘(01)
               forward_a/b_e
```

---

## 16. CSR File — `csr_file`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Reset |
| `csr_raddr` | Input | 12 | Địa chỉ đọc CSR (từ Decode) |
| `csr_waddr` | Input | 12 | Địa chỉ ghi CSR (từ WB) |
| `csr_we` | Input | 1 | Enable ghi CSR |
| `csr_wd` | Input | 32 | Dữ liệu ghi CSR |
| `csr_rd` | Output | 32 | Dữ liệu đọc CSR |
| `is_exception` | Input | 1 | ECALL xảy ra |
| `pc` | Input | 32 | PC của lệnh gây exception |
| `cause` | Input | 32 | Mã nguyên nhân exception (=11 cho ecall M-mode) |
| `epc` | Output | 32 | mepc → PC mux (dùng cho MRET) |
| `trap_vec` | Output | 32 | mtvec → PC mux (dùng cho ECALL) |

### CSR được hỗ trợ

| Địa chỉ | Tên | Ý nghĩa |
|---|---|---|
| 0x300 | mstatus | Machine status register |
| 0x305 | mtvec | Trap handler base address |
| 0x340 | mscratch | Scratch register |
| 0x341 | mepc | Machine exception PC |
| 0x342 | mcause | Exception cause code |

**Internal bypassing**: Nếu `csr_raddr == csr_waddr` và `csr_we=1`, trả về `csr_wd` ngay (tránh hazard đọc-ghi CSR).

**Hardware auto-update** (ưu tiên cao hơn CSR instruction): Khi `is_exception=1`:
```
mepc   ← pc      // lưu PC lệnh ECALL
mcause ← cause   // lưu mã lỗi (= 11)
```

#### Sơ đồ logic CSR File

```
  csr_raddr[11:0] ──┐
  csr_waddr[11:0] ──┤
  csr_we ───────────┤
                    ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                    READ LOGIC (tổ hợp + bypass)              │
  │                                                              │
  │  IF (csr_we && raddr==waddr) → csr_rd = csr_wd (bypass)     │
  │  ELSE CASE raddr:                                            │
  │    0x300 → mstatus                                           │──▶ csr_rd[31:0]
  │    0x305 → mtvec                                             │
  │    0x340 → mscratch                                          │
  │    0x341 → mepc                                              │
  │    0x342 → mcause                                            │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │                    WRITE LOGIC (đồng bộ)                     │
  │                                                              │
  │  posedge clk:                                                │
  │  if (!rst): mstatus=mtvec=mscratch=mepc=mcause = 0           │
  │  else:                                                       │
  │    1. Nếu csr_we:                    2. Nếu is_exception:   │
  │       CASE waddr:                       mepc   ← pc         │
  │         0x300: mstatus ← csr_wd         mcause ← cause      │
  │         0x305: mtvec   ← csr_wd         (ưu tiên cao hơn 1) │
  │         0x340: mscratch← csr_wd                              │
  │         0x341: mepc    ← csr_wd                              │
  │         0x342: mcause  ← csr_wd                              │
  └──────────────────────────────────────────────────────────────┘
         │                   │
      mepc ──────────────▶ epc (output)
      mtvec ─────────────▶ trap_vec (output)
```

---

## 17. CSR ALU — `csr_alu`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `funct3` | Input | 3 | Kiểu lệnh CSR |
| `src_a` | Input | 32 | Giá trị rs1 (sau forwarding) |
| `imm_ext` | Input | 32 | Zero-extended zimm (rs1 field) |
| `csr_rd` | Input | 32 | Giá trị hiện tại của CSR |
| `csr_wd` | Output | 32 | Giá trị mới ghi vào CSR |

| funct3[1:0] | Kiểu | Công thức |
|---|---|---|
| 01 | CSRRW / CSRRWI | `csr_wd = operand` (ghi đè) |
| 10 | CSRRS / CSRRSI | `csr_wd = csr_rd | operand` (set bit) |
| 11 | CSRRC / CSRRCI | `csr_wd = csr_rd & ~operand` (clear bit) |

`funct3[2]=1` → dùng `imm_ext` (zimm). `funct3[2]=0` → dùng `src_a` (rs1).

#### Sơ đồ logic CSR ALU

```
 funct3[2]
    │
    ▼
 ┌──────────┐
 │  MUX 2:1 │──▶ csr_operand
 │ 0: src_a  │
 │ 1: imm_ext│
 └──────────┘

 csr_rd ──────────────────────────┐
 csr_operand ─────────────────────┤
                                  ▼
 funct3[1:0] ──▶ ┌───────────────────────────────────┐
                 │  01: csr_wd = csr_operand          │
                 │       (CSRRW: ghi đè hoàn toàn)    │──▶ csr_wd
                 │  10: csr_wd = csr_rd | csr_operand │
                 │       (CSRRS: set các bit 1)        │
                 │  11: csr_wd = csr_rd & ~csr_operand │
                 │       (CSRRC: clear các bit 1)      │
                 └───────────────────────────────────┘

 Ví dụ CSRRS: csr_rd=0b1010, operand=0b0110
   → csr_wd = 0b1010 | 0b0110 = 0b1110
```

---

## 18. L1 I-Cache — `l1_icache`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk, rst_n` | Input | 1 | Clock, reset tích cực thấp |
| `cpu_addr` | Input | 32 | Địa chỉ PC cần nạp |
| `cpu_rdata` | Output | 32 | Lệnh trả về cho CPU |
| `icache_stall` | Output | 1 | 1 = đang miss, stall pipeline |
| `m_axi_ar*` | Output | - | AXI4-Lite AR channel (gửi địa chỉ đọc) |
| `m_axi_r*` | Input | - | AXI4-Lite R channel (nhận dữ liệu) |

### Cấu trúc cache

- **16 line, direct-mapped** (index = addr[5:2], tag = addr[31:6])
- **Read-only** (không có dirty bit)
- **3 trạng thái FSM**: IDLE → AR_WAIT → R_WAIT → IDLE

### Nguyên lý hoạt động

- **Hit**: `hit = cache_valid[index] && (cache_tag[index] == tag)` → trả về `cache_data[index]`, không stall
- **Miss**: `icache_stall=1`, chuyển sang AR_WAIT (gửi địa chỉ qua AXI), rồi R_WAIT (chờ dữ liệu), cập nhật cache, về IDLE
- Khi stall, Hazard Unit giữ nguyên IF và ID, EX/MEM/WB tiếp tục chạy

#### Sơ đồ cấu trúc và FSM I-Cache

```
 cpu_addr[31:0]:
 ┌───────────────────────────────┬────────┬──┐
 │         TAG [31:6]            │IDX[5:2]│xx│
 └───────────────────────────────┴────────┴──┘
           26 bit                  4 bit    2 bit (word-aligned)

 Cache Array (16 lines):
 ┌─────┬────────┬──────────────────┐
 │Valid│ Tag    │     Data[31:0]   │  ← Line 0
 ├─────┼────────┼──────────────────┤
 │  1  │ tag_hi │  instr_word      │  ← Line index (addr[5:2])
 ├─────┼────────┼──────────────────┤
 │ ... │  ...   │       ...        │
 └─────┴────────┴──────────────────┘  ← Line 15

 hit = valid[index] && (tag[index] == addr[31:6])

 ┌────────────────────────────────────────────────────────────┐
 │                    FSM I-Cache                             │
 │                                                            │
 │    ┌────────────────────────────────────────────────────┐  │
 │    │                   IDLE                             │  │
 │    │  hit → cpu_rdata=cache[idx], icache_stall=0        │  │
 │    │  miss → icache_stall=1, arvalid=1                  │  │
 │    └───────────────────────┬────────────────────────────┘  │
 │                            │ !hit                          │
 │                            ▼                               │
 │    ┌───────────────────────────────────────────────────┐   │
 │    │                  AR_WAIT                          │   │
 │    │  m_axi_arvalid=1, m_axi_araddr={tag,idx,00}       │   │
 │    │  Chờ m_axi_arready=1                              │   │
 │    └───────────────────────┬───────────────────────────┘   │
 │                            │ arready=1                     │
 │                            ▼                               │
 │    ┌───────────────────────────────────────────────────┐   │
 │    │                  R_WAIT                           │   │
 │    │  m_axi_rready=1                                   │   │
 │    │  Chờ m_axi_rvalid=1                               │   │
 │    │  → cập nhật cache: valid=1, tag, data=rdata       │   │
 │    └───────────────────────┬───────────────────────────┘   │
 │                            │ rvalid=1                      │
 │                            ▼                               │
 │                          IDLE ◀───────────────────────────┘ │
 └────────────────────────────────────────────────────────────┘

 icache_stall = (state==IDLE && !hit) || (state != IDLE)
```

---

## 19. L1 D-Cache — `l1_dcache`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk, rst_n` | Input | 1 | Clock, reset tích cực thấp |
| `cpu_addr` | Input | 32 | Địa chỉ dữ liệu |
| `cpu_wdata` | Input | 32 | Dữ liệu ghi (đã căn chỉnh) |
| `cpu_we` | Input | 1 | Write enable |
| `cpu_re` | Input | 1 | Read enable |
| `cpu_funct3` | Input | 3 | Kiểu store (sb/sh/sw) |
| `cpu_rdata` | Output | 32 | Dữ liệu đọc |
| `dcache_stall` | Output | 1 | 1 = stall toàn bộ pipeline |
| `m_axi_aw*, m_axi_w*, m_axi_b*` | Out/In | - | AXI4-Lite write channels |
| `m_axi_ar*, m_axi_r*` | Out/In | - | AXI4-Lite read channels |

### Cấu trúc cache

- **16 line, direct-mapped, write-back**
- Mỗi line: `data[31:0]`, `tag[25:0]`, `valid`, `dirty`
- index = addr[5:2], tag = addr[31:6]
- **6 trạng thái FSM**: IDLE → AW_WAIT → W_WAIT → B_WAIT → AR_WAIT → R_WAIT

### Nguyên lý hoạt động

- **Hit + Read**: trả về `cache_data[index]` ngay, không stall
- **Hit + Write**: cập nhật cache với write_mask, `dirty=1`, không stall
- **Miss + line sạch**: fetch từ SRAM (AR_WAIT → R_WAIT)
- **Miss + line bẩn**: evict về SRAM trước (AW_WAIT → B_WAIT), rồi fetch mới (AR_WAIT → R_WAIT)
- Khi stall: Hazard Unit đóng băng **tất cả 5 tầng**

#### Sơ đồ cấu trúc và FSM D-Cache

```
 Cache Array (16 lines):
 ┌─────┬───────┬────────┬──────────────────┐
 │Valid│ Dirty │ Tag    │     Data[31:0]   │
 └─────┴───────┴────────┴──────────────────┘
   1b     1b    26b           32b

 hit = valid[idx] && (tag[idx] == addr[31:6])

 ┌────────────────────────────────────────────────────────────────────┐
 │                       FSM D-Cache                                  │
 │                                                                    │
 │  ┌───────────────────────────────────────────────────────────┐    │
 │  │                       IDLE                                │    │
 │  │  hit && cpu_we → write cache (mask), dirty=1, stall=0     │    │
 │  │  hit && cpu_re → read cache, stall=0                      │    │
 │  │  miss && dirty && valid → next: AW_WAIT (evict)           │    │
 │  │  miss && !dirty → next: AR_WAIT (fetch)                   │    │
 │  └────────┬─────────────────────────────────────────────┬────┘    │
 │           │ miss & dirty                 miss & !dirty  │         │
 │           ▼                                             ▼         │
 │  ┌─────────────────┐                        ┌────────────────────┐│
 │  │    AW_WAIT       │                        │      AR_WAIT       ││
 │  │ awvalid=1        │                        │ arvalid=1          ││
 │  │ awaddr=dirty_tag │                        │ araddr={tag,idx,0} ││
 │  │ wvalid=1         │                        │ Chờ arready        ││
 │  │ wdata=cache_data │                        └────────┬───────────┘│
 │  │ Chờ awready&&wready│                               │ arready    │
 │  └─────────┬─────────┘                               ▼           │
 │            │ awready                      ┌────────────────────┐  │
 │            ▼  (wready pending)            │      R_WAIT        │  │
 │  ┌─────────────────┐                      │ rready=1           │  │
 │  │    W_WAIT        │                      │ Chờ rvalid         │  │
 │  │ wvalid=1         │                      │ → cache update:    │  │
 │  │ Chờ wready       │                      │   valid=1,dirty=0  │  │
 │  └─────────┬────────┘                      │   tag,data=rdata   │  │
 │            │ wready                        └────────┬───────────┘  │
 │            ▼                                        │ rvalid       │
 │  ┌─────────────────┐                               │              │
 │  │    B_WAIT        │                               ▼             │
 │  │ bready=1         │──────────────────────────▶  IDLE            │
 │  │ Chờ bvalid       │ bvalid                                       │
 │  └─────────────────┘                                              │
 └────────────────────────────────────────────────────────────────────┘

 dcache_stall = (state==IDLE && cache_miss) || (state != IDLE)
```

---

## 20. AXI Interconnect — `axi_interconnect`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `m0_ar*, m0_r*` | In/Out | - | I-Cache (Master 0) — read only |
| `m1_aw*, m1_w*, m1_b*` | In/Out | - | D-Cache (Master 1) — write |
| `m1_ar*, m1_r*` | In/Out | - | D-Cache (Master 1) — read |
| `s0_*` | Out/In | - | SRAM Wrapper (Slave 0) |

### Nguyên lý hoạt động

- **Write**: D-Cache (M1) trực tiếp nối tới Slave 0. I-Cache không có write.
- **Read arbitration**: D-Cache (M1) được ưu tiên. M0 chỉ được phép nếu `m1_arvalid=0`.
- `current_r_owner` lưu master nào đang chờ read response, để routing đúng `rdata/rvalid` khi SRAM trả về.

#### Sơ đồ logic AXI Interconnect

```
                ┌─────────────────────────────────────────────────────┐
                │               axi_interconnect                      │
                │                                                     │
 Master 0       │   WRITE channels:                                   │
 (I-Cache)      │   ─────────────────────────────────────────────     │
 ar/r ──────────┼─▶  M1 (D-Cache) ──── passthrough ────▶ S0 (SRAM)   │
                │   (AW, W, B channels: direct connection M1→S0)      │
                │                                                     │
 Master 1       │   READ arbitration:                                 │
 (D-Cache)      │   ──────────────────                                │
 aw/w/b ────────┼──▶ [priority logic]                                 │
 ar/r ──────────┼──▶  m1_req = m1_arvalid           ┌──────────┐      │
                │    m0_req = m0_arvalid & ~m1_arvalid│          │      │
                │                                    │  S0 SRAM │      │
                │    s0_araddr  = m1_req ? m1_araddr : m0_araddr│      │
                │    s0_arvalid = m1_req ? m1_arvalid:m0_arvalid│      │
                │                                    └──────────┘      │
                │   READ RESPONSE routing:                             │
                │    current_r_owner: reg lưu owner khi AR fire        │
                │    m1_rvalid = s0_rvalid & (owner==1)                │
                │    m0_rvalid = s0_rvalid & (owner==0)                │
                │    s0_rready = owner ? m1_rready : m0_rready         │
                └─────────────────────────────────────────────────────┘

 Thứ tự ưu tiên READ:
 ┌────────────────────────────────────────┐
 │  m1_arvalid=1 (D-Cache) ──▶ WINS      │
 │  m0_arvalid=1 only if !m1_arvalid     │
 └────────────────────────────────────────┘
```

---

## 21. AXI SRAM Wrapper — `axi_sram_wrapper`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `s_axi_*` | In/Out | - | AXI4-Lite slave port |
| `sram_ad` | Output | 10 | Địa chỉ word cho SRAM (addr[11:2]) |
| `sram_di` | Output | 32 | Dữ liệu ghi vào SRAM |
| `sram_ben` | Output | 32 | Byte enable (32-bit, expand từ WSTRB 4-bit) |
| `sram_en` | Output | 1 | SRAM enable |
| `sram_r_wb` | Output | 1 | 1=Read, 0=Write |
| `sram_do` | Input | 32 | Dữ liệu đọc từ SRAM |

### Nguyên lý hoạt động

**3 trạng thái FSM**: IDLE → WRITE → IDLE (hoặc) IDLE → READ_WAIT → IDLE

- **Write**: IDLE nhận `awvalid && wvalid` → kích hoạt SRAM write → WRITE (gửi bresp) → IDLE
- **Read**: IDLE nhận `arvalid` → kích hoạt SRAM read → READ_WAIT (gửi rdata = sram_do) → IDLE
- SRAM trả dữ liệu sau 1 cycle (do SRAM đồng bộ với negedge clock: `CLKin = ~clk`)

#### Sơ đồ FSM AXI SRAM Wrapper

```
 WSTRB[3:0] → sram_ben[31:0]:
 ┌──────────────────────────────────────────────────────┐
 │  WSTRB[3] → sram_ben[31:24] (8 bits)                 │
 │  WSTRB[2] → sram_ben[23:16] (8 bits)                 │
 │  WSTRB[1] → sram_ben[15:8]  (8 bits)                 │
 │  WSTRB[0] → sram_ben[7:0]   (8 bits)                 │
 └──────────────────────────────────────────────────────┘
   assign sram_ben = {{8{wstrb[3]}},{8{wstrb[2]}},{8{wstrb[1]}},{8{wstrb[0]}}}

 ┌───────────────────────────────────────────────────────────┐
 │                    FSM (3 states)                         │
 │                                                           │
 │    ┌─────────────────────────────────────────────────┐    │
 │    │                     IDLE                        │    │
 │    │  Default: sram_en=0, awready=0, arready=0       │    │
 │    │                                                 │    │
 │    │  awvalid && wvalid:         arvalid:            │    │
 │    │  → awready=wready=1         → arready=1         │    │
 │    │  → sram_en=1, r_wb=0        → sram_en=1,r_wb=1  │    │
 │    │  → sram_ad=awaddr[11:2]     → sram_ad=araddr[11:2]│  │
 │    │  → sram_di=wdata            → next: READ_WAIT   │    │
 │    │  → next: WRITE              │                   │    │
 │    └──────┬────────────────────────────────┬─────────┘    │
 │           │ awvalid&&wvalid                │ arvalid      │
 │           ▼                               ▼              │
 │    ┌─────────────┐               ┌─────────────────┐      │
 │    │    WRITE    │               │   READ_WAIT     │      │
 │    │  bvalid=1   │               │  rvalid=1       │      │
 │    │  Chờ bready │               │  rdata=sram_do  │      │
 │    │  → IDLE     │               │  Chờ rready=1   │      │
 │    └─────────────┘               │  → IDLE         │      │
 │                                  └─────────────────┘      │
 │                                                           │
 │  Timing:  SRAM CLKin = ~clk (negedge driven)             │
 │  Cycle N: IDLE→READ_WAIT, kích hoạt SRAM                  │
 │  Cycle N+1: sram_do valid, rvalid=1                       │
 └───────────────────────────────────────────────────────────┘
```

---

## 22. Mối quan hệ giữa các module

### Trong tầng Decode (ID)

```
                    ┌───────────────────────────────────────────────────┐
  instr_d ──────────┤  control_unit                                     │
                    │  ├─ main_decoder → reg_write, imm_src, alu_op, ...│
                    │  └─ alu_decoder → alu_control                     │
                    │                                                   │
  instr_d[19:15] ───┤  register_file (rs1, rs2)                         │
  result_w ─────────┤  register_file (write port WB)                    │
                    │                                                   │
  instr_d[31:0] ────┤  extend (imm_ext)                                 │
                    └───────────────────────────────────────────────────┘
```

### Trong tầng Execute (EX)

```
forward_a/b ───┐
               ├─→ mux_3_1 → src_a, src_b
read_data_1/2 ─┘
result_w ──────┘
alu_result_m ──┘

alu_src ───────→ mux(src_b_int, imm_ext) → src_b_final
alu_control ───→ ALU(src_a, src_b)
pc_e ──────────→ ALU input A (khi AUIPC)

funct3 ────────→ branch condition logic
branch_e ──────┤
jump_e ────────┼→ pc_src_e (flush signal)
jalr_e ────────┤
```

### Luồng dữ liệu xử lý Exception (ECALL)

```
1. ECALL ở tầng ID:  is_ecall_d = 1
2. fetch_cycle:       pc_next_final ← trap_vec (nhảy vào trap handler)
3. csr_file:          mepc ← pc_d, mcause ← 11 (hardware auto-update)
4. control_unit:      reg_write = 0 (ECALL không ghi thanh ghi)
```

#### Sơ đồ luồng ECALL / MRET

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      ECALL Flow                                        │
 │                                                                        │
 │  Cycle N:  ECALL tại ID   Cycle N+1: Handler    Cycle K: MRET tại ID  │
 │  ──────────────────────   ─────────────────      ─────────────────────│
 │  is_ecall_d = 1            PC = mtvec            is_mret_d = 1        │
 │        │                   (đang thực thi         PC = mepc           │
 │        ▼                    trap handler)         (trở về chương      │
 │  csr_file:                                         trình gốc)         │
 │    mepc   ← pc_d                                                       │
 │    mcause ← 11                                                         │
 │        │                                                              │
 │        ▼                                                              │
 │  fetch_cycle:                                                          │
 │    pc_next_final ← trap_vec ◀── csr_file.mtvec                         │
 │                                                                        │
 │  Thanh ghi: reg_write=0 (ECALL không thay đổi xN)                      │
 └────────────────────────────────────────────────────────────────────────┘
```

### Luồng xử lý Load-Use Hazard

```
Cycle N:   LW x1, 0(x2)  ← tầng EX, result_src_e[0]=1
Cycle N+1: ADD x3, x1, x4 ← tầng ID, rs1_d=x1=rd_e
           hazard_unit:   stall_f=1, stall_d=1, flush_e=1
Cycle N+1: bubble chèn vào EX
Cycle N+2: LW kết thúc MEM, forward x1 vào EX (ADD)
```

#### Sơ đồ Load-Use Hazard

```
          IF      ID       EX      MEM      WB
 Cycle N: LW    (prev)  (prev)  (prev)  (prev)
 Cycle N+1: ADD   LW    BUBBLE   (prev)  (prev)   ← stall + flush
                  ▲ stall        ↑ flush_e=1
                  │ stall_f,d=1
 Cycle N+2: ADD   LW     ADD     LW      (prev)
                               ▲ forward: alu_result_m → src_a
 Cycle N+3:       ADD    ...    ADD      LW
```

### Luồng xử lý D-Cache Miss

```
MEM stage cần đọc/ghi nhưng D-Cache miss:
dcache_stall = 1
→ hazard_unit: stall_f=stall_d=stall_e=stall_m=stall_w = 1
→ Toàn bộ pipeline đóng băng
→ D-Cache FSM: (nếu dirty) evict → (rồi) fetch mới từ SRAM
→ dcache_stall = 0 sau khi hoàn thành
→ Pipeline tiếp tục
```

### Luồng ghi CSR (CSRRW)

```
1. Tầng ID:   csr_we_d=1, csr_addr_d=instr_d[31:20]
              csr_file đọc: csr_rd → qua pipeline → csr_rd_e
2. Tầng EX:   csr_alu tính csr_wd_e = src_a (hoặc zimm)
3. Tầng EX→M: csr_wd_e, csr_we_e, csr_addr_e → pipeline_3_4
4. Tầng M→W:  → pipeline_4_5
5. Tầng WB:   csr_file.csr_we=1, ghi csr_wd_w vào csr_addr_w
              result_src_w=11 → result_w = csr_rd_w (ghi vào rd)
```

#### Sơ đồ đường đi dữ liệu CSR

```
  ID           D/E         EX          E/M        MEM        M/W       WB
  ──           ───         ──          ───        ───        ───       ──
  csr_raddr ──▶csr_file
    (read)      │csr_rd ──▶ pipeline ──▶ csr_rd_e
                │              │               │
                │         src_a_fwd ──▶ csr_alu ──▶ csr_wd_e
                │                           │
                │                     pipeline_3_4 ──▶ csr_wd_m
                │                                          │
                │                                    pipeline_4_5 ──▶ csr_wd_w
                │                                                          │
                │                                              csr_file ◀──┘
                │                                              (write port)
                │                                              csr_we_w=1
                │
                └──▶ result_src_w=11 ──▶ result_w = csr_rd_w (ghi vào rd)
```