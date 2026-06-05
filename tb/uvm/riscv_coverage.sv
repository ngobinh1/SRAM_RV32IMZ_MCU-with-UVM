// ============================================================
// File: riscv_coverage.sv
// Description: UVM Functional Coverage Collector for the
//              RISC-V pipeline.
//
//              Coverage groups:
//              1. cg_instr_type    – every RISC-V instruction
//              2. cg_hazards       – data/control hazards
//              3. cg_mem_access    – load/store widths & alignment
//              4. cg_branch        – branch types taken/not taken
//              4. cg_branch        – branch types taken/not taken
//              5. cg_pipeline_flow – stall, flush, cache miss
//              6. cg_regfile       – register file access patterns
//              7. cg_csr           – CSR instruction coverage
//              8. cg_axi           – AXI Bus Transactions
//              9. cg_issue         – Issue Stage Coverage
//             10. cg_branch_prediction - Branch Prediction Hits/Misses
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_seq_item.sv"
`ifndef RISCV_COVERAGE_SV
`define RISCV_COVERAGE_SV

class riscv_coverage extends uvm_subscriber #(riscv_seq_item);
    `uvm_component_utils(riscv_coverage)

    // Transaction handle updated before sampling
    riscv_seq_item trans;

    // ============================================================
    // Coverage Group 1: Instruction Type Coverage
    //   – Every RISC-V instruction must be exercised
    // ============================================================
    covergroup cg_instr_type;
        cp_instr: coverpoint trans.instr_type {
            bins alu_r[]     = {riscv_seq_item::INSTR_ADD,
                                riscv_seq_item::INSTR_SUB,
                                riscv_seq_item::INSTR_AND,
                                riscv_seq_item::INSTR_OR,
                                riscv_seq_item::INSTR_XOR,
                                riscv_seq_item::INSTR_SLT,
                                riscv_seq_item::INSTR_SLTU,
                                riscv_seq_item::INSTR_SLL,
                                riscv_seq_item::INSTR_SRL,
                                riscv_seq_item::INSTR_SRA};
            bins alu_i[]     = {riscv_seq_item::INSTR_ADDI,
                                riscv_seq_item::INSTR_ANDI,
                                riscv_seq_item::INSTR_ORI,
                                riscv_seq_item::INSTR_XORI,
                                riscv_seq_item::INSTR_SLTI,
                                riscv_seq_item::INSTR_SLTIU,
                                riscv_seq_item::INSTR_SLLI,
                                riscv_seq_item::INSTR_SRLI,
                                riscv_seq_item::INSTR_SRAI};
            bins load[]      = {riscv_seq_item::INSTR_LW,
                                riscv_seq_item::INSTR_LH,
                                riscv_seq_item::INSTR_LB,
                                riscv_seq_item::INSTR_LHU,
                                riscv_seq_item::INSTR_LBU};
            bins store[]     = {riscv_seq_item::INSTR_SW,
                                riscv_seq_item::INSTR_SH,
                                riscv_seq_item::INSTR_SB};
            bins branch[]    = {riscv_seq_item::INSTR_BEQ,
                                riscv_seq_item::INSTR_BNE,
                                riscv_seq_item::INSTR_BLT,
                                riscv_seq_item::INSTR_BGE,
                                riscv_seq_item::INSTR_BLTU,
                                riscv_seq_item::INSTR_BGEU};
            bins jump[]      = {riscv_seq_item::INSTR_JAL,
                                riscv_seq_item::INSTR_JALR};
            bins upper[]     = {riscv_seq_item::INSTR_LUI,
                                riscv_seq_item::INSTR_AUIPC};
            bins system[]    = {riscv_seq_item::INSTR_ECALL,
                                riscv_seq_item::INSTR_CSRRW,
                                riscv_seq_item::INSTR_CSRRS,
                                riscv_seq_item::INSTR_CSRRC,
                                riscv_seq_item::INSTR_MRET,
                                riscv_seq_item::INSTR_SRET,
                                riscv_seq_item::INSTR_SFENCE_VMA};
            bins muldiv[]    = {riscv_seq_item::INSTR_MUL,
                                riscv_seq_item::INSTR_MULH,
                                riscv_seq_item::INSTR_MULHSU,
                                riscv_seq_item::INSTR_MULHU,
                                riscv_seq_item::INSTR_DIV,
                                riscv_seq_item::INSTR_DIVU,
                                riscv_seq_item::INSTR_REM,
                                riscv_seq_item::INSTR_REMU};
        }
    endgroup

    // ============================================================
    // Coverage Group 2: Hazard Coverage
    //   – Was a stall seen alongside specific instruction types?
    // ============================================================
    covergroup cg_hazards;
        cp_stall: coverpoint trans.stall_seen {
            bins no_stall = {0};
            bins stalled  = {1};
        }
        cp_instr_at_stall: coverpoint trans.instr_type iff (trans.stall_seen) {
            bins load_use  = {riscv_seq_item::INSTR_LW,
                              riscv_seq_item::INSTR_LH,
                              riscv_seq_item::INSTR_LB};
            bins branch_haz = {riscv_seq_item::INSTR_BEQ,
                               riscv_seq_item::INSTR_BNE,
                               riscv_seq_item::INSTR_BLT,
                               riscv_seq_item::INSTR_BGE};
            bins other      = default;
        }
        // Cross: stall condition with instruction type
    cx_stall_instr: cross cp_stall, cp_instr_at_stall {
    ignore_bins no_stall_cross = binsof(cp_stall.no_stall);
}
    endgroup

    // ============================================================
    // Coverage Group 3: Memory Access Width & Alignment
    // ============================================================
    covergroup cg_mem_access;
        // Load widths
        cp_load_type: coverpoint trans.instr_type
            iff (trans.trans_type == riscv_seq_item::TRANS_MEM_READ &&
                 (trans.instr_type inside {
                     riscv_seq_item::INSTR_LW,
                     riscv_seq_item::INSTR_LH, riscv_seq_item::INSTR_LHU,
                     riscv_seq_item::INSTR_LB, riscv_seq_item::INSTR_LBU}))
        {
            bins load_word     = {riscv_seq_item::INSTR_LW};
            bins load_half     = {riscv_seq_item::INSTR_LH};
            bins load_half_u   = {riscv_seq_item::INSTR_LHU};
            bins load_byte     = {riscv_seq_item::INSTR_LB};
            bins load_byte_u   = {riscv_seq_item::INSTR_LBU};
        }
        // Store widths
        cp_store_type: coverpoint trans.instr_type
            iff (trans.trans_type == riscv_seq_item::TRANS_MEM_WRITE)
        {
            bins store_word  = {riscv_seq_item::INSTR_SW};
            bins store_half  = {riscv_seq_item::INSTR_SH};
            bins store_byte  = {riscv_seq_item::INSTR_SB};
        }
        // Byte offset within word
        cp_byte_offset: coverpoint trans.mem_addr[1:0]
            iff (trans.trans_type inside {
                 riscv_seq_item::TRANS_MEM_WRITE,
                 riscv_seq_item::TRANS_MEM_READ})
        {
            bins offset_0 = {2'b00};
            bins offset_1 = {2'b01};
            bins offset_2 = {2'b10};
            bins offset_3 = {2'b11};
        }
        // Cross: store type × byte offset
        cx_store_offset: cross cp_store_type, cp_byte_offset;
    endgroup

    // ============================================================
    // Coverage Group 4: Branch Coverage
    //   – Each branch type: taken AND not-taken
    // ============================================================
    covergroup cg_branch;
        cp_branch_type: coverpoint trans.instr_type
            iff (trans.trans_type == riscv_seq_item::TRANS_BRANCH_TAKEN)
        {
            bins beq  = {riscv_seq_item::INSTR_BEQ};
            bins bne  = {riscv_seq_item::INSTR_BNE};
            bins blt  = {riscv_seq_item::INSTR_BLT};
            bins bge  = {riscv_seq_item::INSTR_BGE};
            bins bltu = {riscv_seq_item::INSTR_BLTU};
            bins bgeu = {riscv_seq_item::INSTR_BGEU};
            bins jal  = {riscv_seq_item::INSTR_JAL};
            bins jalr = {riscv_seq_item::INSTR_JALR};
        }
        cp_taken: coverpoint trans.branch_taken
            iff (trans.trans_type == riscv_seq_item::TRANS_BRANCH_TAKEN)
        {
            bins taken     = {1'b1};
            bins not_taken = {1'b0};
        }
    // Must see each branch type both taken AND not-taken
        cx_branch_taken: cross cp_branch_type, cp_taken {
            ignore_bins jal_not_taken  = binsof(cp_branch_type.jal)  && binsof(cp_taken.not_taken);
            ignore_bins jalr_not_taken = binsof(cp_branch_type.jalr) && binsof(cp_taken.not_taken);
        }
    endgroup

    // ============================================================
    // Coverage Group 10: Branch Prediction Coverage
    // ============================================================
    covergroup cg_branch_prediction;
        cp_mispredict: coverpoint trans.mispredict
            iff (trans.trans_type == riscv_seq_item::TRANS_BRANCH_TAKEN)
        {
            bins correct = {0};
            bins mispredicted = {1};
        }
        
        cp_branch_type: coverpoint trans.instr_type
            iff (trans.trans_type == riscv_seq_item::TRANS_BRANCH_TAKEN)
        {
            bins beq  = {riscv_seq_item::INSTR_BEQ};
            bins bne  = {riscv_seq_item::INSTR_BNE};
            bins blt  = {riscv_seq_item::INSTR_BLT};
            bins bge  = {riscv_seq_item::INSTR_BGE};
            bins bltu = {riscv_seq_item::INSTR_BLTU};
            bins bgeu = {riscv_seq_item::INSTR_BGEU};
            bins jal  = {riscv_seq_item::INSTR_JAL};
            bins jalr = {riscv_seq_item::INSTR_JALR};
        }

        cx_prediction: cross cp_branch_type, cp_mispredict {
            ignore_bins jal_correct = binsof(cp_branch_type.jal) && binsof(cp_mispredict.correct);
            ignore_bins jalr_correct = binsof(cp_branch_type.jalr) && binsof(cp_mispredict.correct);
        }
    endgroup

    // ============================================================
    // Coverage Group 5: Pipeline Flow Events
    // ============================================================
    covergroup cg_pipeline_flow;
        cp_stall: coverpoint trans.stall_seen {
            bins yes = {1};
            bins no  = {0};
        }
        // Result value ranges (corner cases for ALU)
        cp_result_range: coverpoint trans.result
            iff (trans.trans_type == riscv_seq_item::TRANS_REG_WRITE)
        {
            bins zero         = {32'h0};
            bins all_ones     = {32'hFFFFFFFF};
            bins msb_set      = {[32'h80000000 : 32'hFFFFFFFF]};
            bins msb_clear    = {[32'h00000001 : 32'h7FFFFFFF]};
        }
    endgroup

    // ============================================================
    // Coverage Group 6: Register File Access Patterns
    // ============================================================
    covergroup cg_regfile;
        // Every destination register should be written
        cp_rd: coverpoint trans.rd
            iff (trans.trans_type == riscv_seq_item::TRANS_REG_WRITE)
        {
            // x0 excluded (never written)
            bins gpr[] = {[1:31]};
        }
        // Every source register should be read
        cp_rs1: coverpoint trans.rs1
            iff (trans.trans_type == riscv_seq_item::TRANS_REG_WRITE)
        {
            bins x0_src = {0};
            bins gpr[]  = {[1:31]};
        }
        cp_rs2: coverpoint trans.rs2
            iff (trans.trans_type == riscv_seq_item::TRANS_REG_WRITE)
        {
            bins x0_src = {0};
            bins gpr[]  = {[1:31]};
        }
        // RAW hazard: rs1 == rd of previous instruction (detected by stall)
        cp_raw_rs1: coverpoint (trans.rs1 == trans.rd) && trans.stall_seen;
        cp_raw_rs2: coverpoint (trans.rs2 == trans.rd) && trans.stall_seen;
    endgroup

    // ============================================================
    // Coverage Group 7: CSR Instructions
    // ============================================================
    covergroup cg_csr;
        cp_csr_instr: coverpoint trans.instr_type
            iff (trans.instr_type inside {
                 riscv_seq_item::INSTR_CSRRW,
                 riscv_seq_item::INSTR_CSRRS,
                 riscv_seq_item::INSTR_CSRRC,
                 riscv_seq_item::INSTR_ECALL,
                 riscv_seq_item::INSTR_MRET,
                 riscv_seq_item::INSTR_SRET})
        {
            bins csrrw  = {riscv_seq_item::INSTR_CSRRW};
            bins csrrs  = {riscv_seq_item::INSTR_CSRRS};
            bins csrrc  = {riscv_seq_item::INSTR_CSRRC};
            bins ecall  = {riscv_seq_item::INSTR_ECALL};
            bins mret   = {riscv_seq_item::INSTR_MRET};
            bins sret   = {riscv_seq_item::INSTR_SRET};
        }
        // CSR address bins (machine-mode and supervisor-mode CSRs)
        cp_csr_addr: coverpoint trans.instr[31:20]
            iff (trans.instr_type inside {
                 riscv_seq_item::INSTR_CSRRW,
                 riscv_seq_item::INSTR_CSRRS,
                 riscv_seq_item::INSTR_CSRRC})
        {
            bins mstatus  = {12'h300};
            bins mtvec    = {12'h305};
            bins mscratch = {12'h340};
            bins mepc     = {12'h341};
            bins mcause   = {12'h342};
            bins sstatus  = {12'h100};
            bins stvec    = {12'h105};
            bins sscratch = {12'h140};
            bins sepc     = {12'h141};
            bins scause   = {12'h142};
            bins satp     = {12'h180};
            bins other    = default;
        }
    endgroup

    // ============================================================
    // Coverage Group 8: AXI Bus Transactions
    // ============================================================
    covergroup cg_axi;
        cp_axi_trans: coverpoint trans.trans_type {
            bins axi_reads = {riscv_seq_item::TRANS_AXI_READ};
            bins axi_writes = {riscv_seq_item::TRANS_AXI_WRITE};
        }
    endgroup

    // ============================================================
    // Coverage Group 9: Issue Stage Coverage
    // ============================================================
    covergroup cg_issue;
        cp_issue_stall: coverpoint trans.issue_stall {
            bins no_stall = {0};
            bins stalled  = {1};
        }
        cp_issue_valid: coverpoint trans.issue_valid {
            bins invalid = {0};
            bins valid   = {1};
        }
        cp_execute_ready: coverpoint trans.execute_ready {
            bins not_ready = {0};
            bins ready     = {1};
        }
        cp_load_use_hazard: coverpoint trans.load_use_hazard {
            bins no_hazard = {0};
            bins hazard    = {1};
        }
    endgroup

    // ============================================================
    // Coverage Group 11: Cache Events
    // ============================================================
    covergroup cg_cache;
        cp_icache_stall: coverpoint trans.icache_stall {
            bins hit_or_idle = {0};
            bins miss_stall  = {1};
        }
        cp_dcache_stall: coverpoint trans.dcache_stall {
            bins hit_or_idle = {0};
            bins miss_stall  = {1};
        }
    endgroup

    // --------------------------------------------------------
    // Constructor: instantiate all coverage groups
    // --------------------------------------------------------
    function new(string name = "riscv_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_instr_type    = new();
        cg_hazards       = new();
        cg_mem_access    = new();
        cg_branch        = new();
        cg_pipeline_flow = new();
        cg_regfile       = new();
        cg_csr           = new();
        cg_axi           = new();
        cg_issue         = new();
        cg_branch_prediction = new();
        cg_cache         = new();
    endfunction

    // --------------------------------------------------------
    // write(): called by analysis port with each transaction
    // --------------------------------------------------------
    function void write(riscv_seq_item t);
        trans = t;
        // Sample all applicable coverage groups
        cg_instr_type.sample();
        cg_hazards.sample();
        cg_pipeline_flow.sample();
        cg_regfile.sample();
        cg_issue.sample();
        cg_cache.sample();

        if (trans.trans_type == riscv_seq_item::TRANS_MEM_WRITE ||
            trans.trans_type == riscv_seq_item::TRANS_MEM_READ  ||
            (trans.trans_type == riscv_seq_item::TRANS_REG_WRITE &&
            trans.instr_type inside {
                     riscv_seq_item::INSTR_LW,
                     riscv_seq_item::INSTR_LH, riscv_seq_item::INSTR_LHU,
                     riscv_seq_item::INSTR_LB, riscv_seq_item::INSTR_LBU}))
            cg_mem_access.sample();

        if (t.trans_type == riscv_seq_item::TRANS_BRANCH_TAKEN) begin
            cg_branch.sample();
            cg_branch_prediction.sample();
        end

        if (t.instr_type inside {
            riscv_seq_item::INSTR_CSRRW,
            riscv_seq_item::INSTR_CSRRS,
            riscv_seq_item::INSTR_CSRRC,
            riscv_seq_item::INSTR_ECALL,
            riscv_seq_item::INSTR_MRET,
            riscv_seq_item::INSTR_SRET})
            cg_csr.sample();

        if (t.trans_type inside {
            riscv_seq_item::TRANS_AXI_WRITE,
            riscv_seq_item::TRANS_AXI_READ})
            cg_axi.sample();
    endfunction

    // --------------------------------------------------------
    // report_phase: print coverage summary
    // --------------------------------------------------------
    function void report_phase(uvm_phase phase);
        string msg; 
        msg = "\n=== Functional Coverage Summary ===\n";
        msg = {msg, $sformatf("  Instruction Type : %0.1f%%\n", cg_instr_type.get_coverage())}; 
        msg = {msg, $sformatf("  Hazard Detection : %0.1f%%\n", cg_hazards.get_coverage())}; 
        msg = {msg, $sformatf("  Memory Access    : %0.1f%%\n", cg_mem_access.get_coverage())}; 
        msg = {msg, $sformatf("  Branch/Jump      : %0.1f%%\n", cg_branch.get_coverage())}; 
        msg = {msg, $sformatf("  Pipeline Flow    : %0.1f%%\n", cg_pipeline_flow.get_coverage())};
        msg = {msg, $sformatf("  Register File    : %0.1f%%\n", cg_regfile.get_coverage())};
        msg = {msg, $sformatf("  CSR/Exceptions   : %0.1f%%\n",   cg_csr.get_coverage())};
        msg = {msg, $sformatf("  AXI Transactions : %0.1f%%\n",   cg_axi.get_coverage())};
        msg = {msg, $sformatf("  Issue Stage      : %0.1f%%\n",   cg_issue.get_coverage())};
        msg = {msg, $sformatf("  Branch Predictor : %0.1f%%\n",   cg_branch_prediction.get_coverage())};
        msg = {msg, $sformatf("  Cache Stalls     : %0.1f%%",     cg_cache.get_coverage())};

        `uvm_info("COVERAGE", msg, UVM_NONE)
    endfunction

endclass : riscv_coverage

`endif // RISCV_COVERAGE_SV