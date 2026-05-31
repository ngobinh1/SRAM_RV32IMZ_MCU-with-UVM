import re

with open("docs/spec.md", "r") as f:
    content = f.read()

def replace_block(content, header, new_block):
    # Find the header
    idx = content.find(header)
    if idx == -1: return content
    # Find the next ``` after header
    start_code = content.find("```", idx)
    if start_code == -1: return content
    # Find the end of the ``` block
    end_code = content.find("```", start_code + 3)
    if end_code == -1: return content
    
    return content[:start_code] + new_block + content[end_code+3:]

d1 = """```mermaid
graph TD
    clk[clk, rst] --> TOP[riscv_pipeline_top]
    
    subgraph TOP[Top Module]
        IF[FETCH<br>fetch_cycle] -->|F/D reg| ID[DECODE<br>decode_cycle]
        ID -->|D/E reg| ISS[ISSUE<br>issue_stage]
        ISS -->|D/E reg| EX[EXECUTE<br>execute_cycle]
        EX -->|E/M reg| MEM[MEMORY<br>memory_cycle]
        MEM -->|M/W reg| WB[WRITEBK<br>writeback_cycle]
        
        MULDIV[muldiv_alu] -.-> EX
        
        HZ[hazard_unit<br>stall/flush/forward]
        HZ -.-> IF
        HZ -.-> ID
        HZ -.-> ISS
        HZ -.-> EX
        HZ -.-> MEM
        HZ -.-> WB
        
        BP[branch_predictor<br>BTB+BHT] -.-> IF
    end
    
    IF --> IC[l1_icache<br>M0: read]
    MEM <--> DC[l1_dcache<br>M1: rd+wr]
    
    IC --> AXI[axi_interconn<br>2M to 1S]
    DC --> AXI
    
    AXI --> SRAM_W[axi_sram_wrap]
    SRAM_W --> SRAM[EF_SRAM<br>1024x32 words]
    
    CSR[csr_file<br>mstatus, mtvec...] -.-> ID
    CSR -.-> WB
```"""
content = replace_block(content, "#### Sơ đồ kiến trúc tổng thể", d1)

d2 = """```mermaid
graph TD
    TV[trap_vec] --> MUX1{Priority MUX}
    EPC[epc] --> MUX1
    
    PC4[pc_plus_4_f] --> MUX2{MUX 2:1}
    PCT[predict_target_f_in] --> MUX2
    
    MUX2 -->|predict_taken_f_in| PC_NEXT_PREDICT
    
    PC_NEXT_PREDICT --> MUX3{MUX 2:1}
    PCT_E[pc_target_e] --> MUX3
    MUX3 -->|pc_src_e| PC_NEXT_NORMAL
    
    PC_NEXT_NORMAL --> MUX1
    MUX1 -->|is_ecall / is_mret / else| PC_NEXT_FINAL
    
    PC_NEXT_FINAL -->|en = ~stall_f| PC[PC Register]
    PC --> PC_OUT[pc_f]
    PC_OUT --> ADD[ADDER +4]
    ADD --> PC4
    
    I[instr_f_in] --> IOUT[instr_f]
```"""
content = replace_block(content, "#### Sơ đồ logic tầng Fetch", d2)

d3 = """```mermaid
graph LR
    I[instr_d] -->|6:0| CU[control_unit]
    I -->|14:12| CU
    I -->|31:25| CU
    I -->|31:20| CU
    
    CU -->|opcode| MD[main_decoder]
    CU -->|funct3/7| AD[alu_decoder]
    
    MD --> CTRL[reg_write, mem_write... ]
    AD --> ALU_CTRL[alu_control]
    
    I -->|19:15| RS1[rs1_d]
    I -->|24:20| RS2[rs2_d]
    I -->|11:7| RD[rd_d]
    
    RS1 --> REG[register_file]
    RS2 --> REG
    
    RD_W[rd_w] --> REG
    RES_W[result_w] --> REG
    RW_W[reg_write_w] --> REG
    
    REG --> RD1[read_data_1_d]
    REG --> RD2[read_data_2_d]
    
    I -->|31:0| EXT[extend]
    IMM_SRC[imm_src] --> EXT
    EXT --> IMM[imm_ext_d]
```"""
content = replace_block(content, "#### Sơ đồ logic tầng Decode", d3)

d4 = """```mermaid
graph TD
    RD1[read_data_1_e] --> MUXA{MUX 3:1}
    RESW[result_w] --> MUXA
    ALUM[alu_result_m] --> MUXA
    FWDA[forward_a_e] --> MUXA
    MUXA --> SRCA[src_a_e]
    
    RD2[read_data_2_e] --> MUXB1{MUX 3:1}
    RESW --> MUXB1
    ALUM --> MUXB1
    FWDB[forward_b_e] --> MUXB1
    MUXB1 --> SRCB_INT[src_b_int]
    SRCB_INT --> WDATA[write_data_e]
    
    SRCB_INT --> MUXB2{MUX 2:1}
    IMM[imm_ext_e] --> MUXB2
    ALUSRC[alu_src_e] --> MUXB2
    MUXB2 --> SRCB[src_b_e]
    
    SRCA --> MUX_ALU{AUIPC?}
    PCE[pc_e] --> MUX_ALU
    MUX_ALU --> ALUA[alu_in_a]
    
    ALUA --> ALU[ALU]
    SRCB --> ALU
    ALU_CTRL[alu_control_e] --> ALU
    ALU --> ALURES[alu_result_e]
    ALU --> FLAGS[zero, neg, ov, carry]
    
    FLAGS --> BR_LOGIC[Branch Logic]
    F3[funct3_e] --> BR_LOGIC
    BR_LOGIC -->|branch_taken| ACT_TAKEN[actual_taken_e]
    BRE[branch_e] --> ACT_TAKEN
    JMPE[jump_e] --> ACT_TAKEN
    
    PCE --> ADD_TGT[+]
    IMM --> ADD_TGT
    ADD_TGT --> MUX_TGT{MUX 2:1}
    ALURES --> MUX_TGT
    JALRE[jalr_e] --> MUX_TGT
    MUX_TGT --> PCTGT[pc_target_e = actual_target_e]
    
    ACT_TAKEN --> MISP[mispredict_e]
    PCTGT --> MISP
    PRED_T[predict_taken_e] --> MISP
    PRED_TG[predict_target_e] --> MISP
    MISP --> PCSRC[pc_src_e]
```"""
content = replace_block(content, "#### Sơ đồ logic tầng Execute", d4)

d5 = """```mermaid
graph TD
    ALURES[alu_result_m] -->|1:0| OFFSET[byte_offset]
    OFFSET --> SHAMT[shift_amt = offset * 8]
    
    subgraph STORE PATH
        WDATA[write_data_m] --> SLL[data << shift_amt]
        WDATA --> NOP[data]
        F3S[funct3_m: sb/sh/sw] --> MUX_S{MUX}
        SLL --> MUX_S
        NOP --> MUX_S
        MUX_S --> WOUT[write_data_m_out]
    end
    
    subgraph LOAD PATH
        RDATA[read_data_m_in] --> SRL[data >> shift_amt]
        SRL --> EXT8S[sign-extend 8]
        SRL --> EXT16S[sign-extend 16]
        SRL --> EXT8U[zero-extend 8]
        SRL --> EXT16U[zero-extend 16]
        SRL --> EXT32[keep 32]
        
        F3L[funct3_m: lb/lh/lw/lbu/lhu] --> MUX_L{MUX}
        EXT8S --> MUX_L
        EXT16S --> MUX_L
        EXT8U --> MUX_L
        EXT16U --> MUX_L
        EXT32 --> MUX_L
        MUX_L --> ROUT[read_data_m]
    end
```"""
content = replace_block(content, "#### Sơ đồ logic tầng Memory", d5)

d6 = """```mermaid
graph TD
    ALURES[alu_result_w] --> MUX{MUX 4:1}
    RDATA[read_data_w] --> MUX
    PC4[pc_plus_4_w] --> MUX
    CSR[csr_rd_w] --> MUX
    
    RSRC[result_src_w] --> MUX
    MUX --> RES[result_w]
    RES --> REG[Register File rd]
```"""
content = replace_block(content, "#### Sơ đồ logic tầng Writeback", d6)

d7 = """```mermaid
graph TD
    OP[op 6:0, funct3, funct7, imm12] --> SYS{is_system?}
    SYS -->|1110011| ECALL[is_ecall]
    SYS --> MRET[is_mret]
    SYS --> CSRWE[csr_we]
    
    OP --> MOD_F3[funct3_modified]
    
    OP --> MD[main_decoder]
    MD --> RW_RAW[reg_write_raw]
    MD --> MW[mem_write, alu_src, jump, branch, jalr, result_src, imm_src, alu_op]
    
    MD --> AD[alu_decoder]
    MOD_F3 --> AD
    AD --> ACTRL[alu_control]
    
    RW_RAW --> AND1{AND}
    ECALL --> NOT1{~}
    MRET --> NOT1
    NOT1 --> AND1
    AND1 --> RW[reg_write]
```"""
content = replace_block(content, "#### Sơ đồ logic control_unit", d7)

d8 = """```mermaid
graph TD
    OP[op 6:0] --> LOGIC{Combinational Logic}
    LOGIC -->|0110011| R[R-type]
    LOGIC -->|0010011| I[I-ALU]
    LOGIC -->|0000011| L[Load]
    LOGIC -->|0100011| S[Store]
    LOGIC -->|1100011| B[Branch]
    LOGIC -->|1101111| JAL[JAL]
    LOGIC -->|1100111| JALR[JALR]
    LOGIC -->|0110111| LUI[LUI]
    LOGIC -->|0010111| AUIPC[AUIPC]
    LOGIC -->|1110011| CSR[CSR]
    
    R --> OUT[reg_write, mem_write, alu_src, alu_op, imm_src, jump, branch, jalr, result_src]
    I --> OUT
    L --> OUT
    S --> OUT
    B --> OUT
    JAL --> OUT
    JALR --> OUT
    LUI --> OUT
    AUIPC --> OUT
    CSR --> OUT
```"""
content = replace_block(content, "#### Sơ đồ logic main_decoder", d8)

d9 = """```mermaid
graph TD
    HU[hazard_unit]
    
    subgraph FORWARDING
        RS1E[rs1_e] --> FWDLogic
        RDM[rd_m] --> FWDLogic
        RWM[reg_write_m] --> FWDLogic
        RDW[rd_w] --> FWDLogic
        RWW[reg_write_w] --> FWDLogic
        FWDLogic --> FWDA[forward_a_e]
        FWDLogic --> FWDB[forward_b_e]
    end
    
    subgraph STALL_FLUSH_PRIORITY
        DC[dcache_stall] --> PRIO{Priority}
        IC[icache_stall] --> PRIO
        LU[load_use_stall] --> PRIO
        PCSRC[pc_src_e] --> PRIO
        
        PRIO --> STALL_ALL[stall_f/d/e/m/w = 1]
        PRIO --> STALL_FD[stall_f=d=1]
        PRIO --> FLUSHD[flush_d=1]
        PRIO --> FLUSHE[flush_e=1]
    end
```"""
content = replace_block(content, "#### Sơ đồ logic Hazard Unit", d9)

# Now, add Branch Predictor section at the end.
bp_section = """
## 25. Branch Predictor — `branch_predictor`

### Bảng tín hiệu

| Tên | Hướng | Rộng | Ý nghĩa |
|---|---|---|---|
| `clk`, `rst` | Input | 1 | Clock, Reset |
| `pc_f` | Input | 32 | PC hiện tại ở tầng Fetch (dùng để tra cứu) |
| `predict_taken_f` | Output| 1 | Dự đoán có nhảy không |
| `predict_target_f` | Output| 32 | Địa chỉ đích dự đoán |
| `update_valid_e` | Input | 1 | Tín hiệu báo lệnh rẽ nhánh ở EX hợp lệ |
| `pc_e` | Input | 32 | PC của lệnh rẽ nhánh ở EX |
| `actual_taken_e` | Input | 1 | Thực tế có nhảy không |
| `actual_target_e` | Input | 32 | Địa chỉ đích thực tế |

### Nguyên lý hoạt động

Bộ Branch Predictor kết hợp Branch Target Buffer (BTB) và Branch History Table (BHT).
- **BTB (16 entries)**: Lưu trữ địa chỉ đích của nhánh. Index bằng `PC[5:2]`, Tag bằng `PC[31:6]`.
- **BHT (16 entries)**: Sử dụng bộ đếm bão hòa 2-bit (00=Strongly Not Taken, 01=Weakly Not Taken, 10=Weakly Taken, 11=Strongly Taken) để dự đoán nhánh.
- Tại tầng IF, dùng `pc_f` để tra cứu. Nếu hit BTB và BHT >= 10, dự đoán là Taken và lấy Target từ BTB.
- Tại tầng EX, dùng `pc_e`, `actual_taken_e`, `actual_target_e` để cập nhật BTB (nếu Taken) và cập nhật bộ đếm BHT (+1 nếu Taken, -1 nếu Not Taken).

#### Sơ đồ cấu trúc Branch Predictor

```mermaid
graph TD
    PC_F[pc_f] -->|Index 5:2| BTB_READ
    PC_F -->|Tag 31:6| BTB_READ
    
    subgraph BTB [Branch Target Buffer 16-entry]
        BTB_READ{Tag Match & Valid?}
        BTB_READ -->|Yes| BTB_TGT[Target]
    end
    
    PC_F -->|Index 5:2| BHT_READ
    
    subgraph BHT [Branch History Table 16-entry 2-bit]
        BHT_READ{Counter >= 2?}
    end
    
    BTB_READ --> AND_PRED{AND}
    BHT_READ --> AND_PRED
    
    AND_PRED -->|predict_taken_f| PRED_TAKEN
    BTB_TGT -->|predict_target_f| PRED_TGT
    
    PC_E[pc_e] -->|Index 5:2, Tag 31:6| UPDATE_LOGIC
    ACT_TAKEN[actual_taken_e] --> UPDATE_LOGIC
    ACT_TGT[actual_target_e] --> UPDATE_LOGIC
    UP_VALID[update_valid_e] --> UPDATE_LOGIC
    
    UPDATE_LOGIC -->|Write| BTB
    UPDATE_LOGIC -->|State Machine +1/-1| BHT
```
"""
content += bp_section

with open("docs/spec.md", "w") as f:
    f.write(content)

print("Done")
