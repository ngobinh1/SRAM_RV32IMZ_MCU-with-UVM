import re

with open("docs/spec.md", "r") as f:
    content = f.read()

def replace_block(content, header, new_block):
    idx = content.find(header)
    if idx == -1: return content
    start_code = content.find("```", idx)
    if start_code == -1: return content
    end_code = content.find("```", start_code + 3)
    if end_code == -1: return content
    return content[:start_code] + new_block + content[end_code+3:]

d10 = """```mermaid
graph TD
    A[a] --> ALU_MUX
    B[b] --> B_INV{b_inv}
    CTRL0[alu_ctrl 0] --> B_INV
    B_INV --> ADDER
    A --> ADDER
    ADDER --> SUM[sum, cout]
    SUM --> ALU_MUX
    
    ALU_CTRL[alu_control] --> ALU_MUX
    
    ALU_MUX --> RES[result]
    
    RES --> ZERO(zero)
    RES --> NEG(neg)
    SUM --> OVERFLOW(overflow)
    SUM --> CARRY(carry)
```"""
content = replace_block(content, "#### Sơ đồ logic ALU", d10)

d11 = """```mermaid
graph LR
    subgraph WRITE PORT
        WE[write_en_3] --> REG_ARRAY
        A3[addr_3] --> REG_ARRAY
        WD3[write_data_3] --> REG_ARRAY
    end
    
    REG_ARRAY[Register Array] --> MUX1
    REG_ARRAY --> MUX2
    
    subgraph READ PORT 1
        A1[addr_1] --> MUX1
        MUX1 --> RD1[read_data_1]
        A1 -.-> BYPASS1{Bypass?}
        A3 -.-> BYPASS1
        BYPASS1 -.-> MUX1
    end
    
    subgraph READ PORT 2
        A2[addr_2] --> MUX2
        MUX2 --> RD2[read_data_2]
        A2 -.-> BYPASS2{Bypass?}
        A3 -.-> BYPASS2
        BYPASS2 -.-> MUX2
    end
```"""
content = replace_block(content, "#### Sơ đồ logic Register File", d11)

d12 = """```mermaid
graph TD
    INSTR[Instruction] --> IMM_LOGIC{imm_src}
    IMM_LOGIC -->|000| I_TYPE[I-type / U-type]
    IMM_LOGIC -->|001| S_TYPE[S-type]
    IMM_LOGIC -->|010| B_TYPE[B-type]
    IMM_LOGIC -->|011| J_TYPE[J-type]
    IMM_LOGIC -->|100| CSR_TYPE[CSR-type]
    
    I_TYPE --> EXT[imm_ext_d]
    S_TYPE --> EXT
    B_TYPE --> EXT
    J_TYPE --> EXT
    CSR_TYPE --> EXT
```"""
content = replace_block(content, "#### Sơ đồ trích xuất immediate", d12)

d13 = """```mermaid
graph TD
    RST[rst] --> MUX_RST{rst == 0?}
    MUX_RST -->|Yes| ZERO[0x00000000]
    MUX_RST -->|No| EN_CHECK{en == 1?}
    EN_CHECK -->|Yes| NEXT[pc_next]
    EN_CHECK -->|No| CURR[pc]
    
    ZERO --> PC_REG
    NEXT --> PC_REG
    CURR --> PC_REG
    
    PC_REG[PC Register] --> PC_OUT[pc]
```"""
content = replace_block(content, "#### Sơ đồ logic PC", d13)

d14 = """```mermaid
graph TD
    RADDR[csr_raddr] --> READ_LOGIC
    WADDR[csr_waddr] --> WRITE_LOGIC
    WE[csr_we] --> READ_LOGIC
    WE --> WRITE_LOGIC
    
    subgraph CSR_REGISTERS
        MSTATUS[mstatus]
        MTVEC[mtvec]
        MSCRATCH[mscratch]
        MEPC[mepc]
        MCAUSE[mcause]
    end
    
    READ_LOGIC --> CSR_RD[csr_rd]
    
    EXC[is_exception] --> WRITE_LOGIC
    PC[pc] --> WRITE_LOGIC
    CAUSE[cause] --> WRITE_LOGIC
    WD[csr_wd] --> WRITE_LOGIC
    
    WRITE_LOGIC --> CSR_REGISTERS
    
    MEPC --> EPC_OUT[epc]
    MTVEC --> TVEC_OUT[trap_vec]
```"""
content = replace_block(content, "#### Sơ đồ logic CSR File", d14)

d15 = """```mermaid
graph TD
    F3[funct3 2] --> MUX_OP
    SRCA[src_a] --> MUX_OP
    IMM[imm_ext] --> MUX_OP
    MUX_OP --> OP[csr_operand]
    
    RD[csr_rd] --> ALU
    OP --> ALU
    
    F3_10[funct3 1:0] --> ALU
    ALU -->|01| RW[CSRRW]
    ALU -->|10| RS[CSRRS]
    ALU -->|11| RC[CSRRC]
    
    RW --> WD[csr_wd]
    RS --> WD
    RC --> WD
```"""
content = replace_block(content, "#### Sơ đồ logic CSR ALU", d15)

d16 = """```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> IDLE : Hit
    IDLE --> AR_WAIT : Miss
    
    AR_WAIT --> AR_WAIT : m_axi_arready == 0
    AR_WAIT --> R_WAIT : m_axi_arready == 1
    
    R_WAIT --> R_WAIT : m_axi_rvalid == 0
    R_WAIT --> IDLE : m_axi_rvalid == 1 (Update Cache)
```"""
content = replace_block(content, "#### Sơ đồ cấu trúc và FSM I-Cache", d16)

d17 = """```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> IDLE : Hit
    IDLE --> AW_WAIT : Miss & Dirty (Evict)
    IDLE --> AR_WAIT : Miss & !Dirty (Fetch)
    
    AW_WAIT --> W_WAIT : m_axi_awready == 1
    W_WAIT --> B_WAIT : m_axi_wready == 1
    B_WAIT --> AR_WAIT : m_axi_bvalid == 1
    
    AR_WAIT --> R_WAIT : m_axi_arready == 1
    R_WAIT --> IDLE : m_axi_rvalid == 1 (Update Cache)
```"""
content = replace_block(content, "#### Sơ đồ cấu trúc và FSM D-Cache", d17)

d18 = """```mermaid
graph TD
    subgraph I-Cache M0
        AR0[ar / r]
    end
    
    subgraph D-Cache M1
        AW1[aw / w / b]
        AR1[ar / r]
    end
    
    subgraph AXI Interconnect
        AW1 -->|Passthrough| S0_AW
        
        AR1 --> PRIO{Priority}
        AR0 --> PRIO
        PRIO -->|M1 wins| S0_AR
        
        S0_R[SRAM rdata] --> ROUT{Routing}
        ROUT -->|owner==1| AR1
        ROUT -->|owner==0| AR0
    end
```"""
content = replace_block(content, "#### Sơ đồ logic AXI Interconnect", d18)

d19 = """```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> WRITE : awvalid & wvalid
    IDLE --> READ_WAIT : arvalid
    
    WRITE --> IDLE : bvalid & bready
    READ_WAIT --> IDLE : rvalid & rready
```"""
content = replace_block(content, "#### Sơ đồ FSM AXI SRAM Wrapper", d19)

d20 = """```mermaid
graph TD
    RD_E[rd_e] --> HAZARD[Load-Use Hazard Check]
    RSRC_E[result_src_e] --> HAZARD
    
    HAZARD --> LU[load_use_hazard]
    
    RDY[execute_ready] --> AND_GATE
    LU -->|NOT| AND_GATE
    VAL[decode_valid] --> AND_GATE
    
    AND_GATE --> IVAL[issue_valid]
    AND_GATE -->|NOT| ISTALL[issue_stall]
```"""
content = replace_block(content, "#### Sơ đồ logic Tầng Issue", d20)

d21 = """```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> MUL : req & is_mul
    IDLE --> DIV : req & (is_div | is_rem)
    
    MUL --> DONE : 1 cycle
    DIV --> DONE : 32 cycles
    
    DONE --> IDLE : ack
```"""
content = replace_block(content, "#### Sơ đồ logic FSM Mul/Div", d21)

d22 = """```mermaid
graph TD
    ID_E[ECALL tại ID] --> |is_ecall=1, reg_write=0| CSR_UPD[CSR: mepc=pc, mcause=11]
    CSR_UPD --> IF_TRAP[IF: pc_next = trap_vec]
    IF_TRAP --> HANDLER[Trap Handler]
    HANDLER --> ID_M[MRET tại ID]
    ID_M --> |is_mret=1, reg_write=0| IF_RET[IF: pc_next = mepc]
```"""
content = replace_block(content, "#### Sơ đồ luồng ECALL / MRET", d22)

d23 = """```mermaid
gantt
    title Load-Use Hazard Flow
    dateFormat  X
    axisFormat %s
    section Cycle N
    EX: LW       :a1, 0, 1
    ID: prev     :a2, 0, 1
    section Cycle N+1
    MEM: LW      :b1, 1, 2
    ID: ADD (stall) :b2, 1, 2
    EX: BUBBLE   :b3, 1, 2
    section Cycle N+2
    WB: LW       :c1, 2, 3
    EX: ADD      :c2, 2, 3
```"""
content = replace_block(content, "#### Sơ đồ Load-Use Hazard", d23)

with open("docs/spec.md", "w") as f:
    f.write(content)

print("Done")
