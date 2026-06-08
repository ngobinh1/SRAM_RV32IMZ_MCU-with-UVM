// ============================================================
// File: riscv_seq_item.sv
// Description: UVM Transaction class – carries stimulus
//              (program load commands, reset control) and
//              observed pipeline events (reg writes, memory
//              accesses, branches) captured by the monitor.
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`ifndef RISCV_SEQ_ITEM_SV
`define RISCV_SEQ_ITEM_SV

class riscv_seq_item extends uvm_sequence_item;

    // ============================================================
    // Transaction type enum
    // ============================================================
    typedef enum logic [3:0] {
        TRANS_RESET        = 4'h0,  // Assert/deassert reset
        TRANS_LOAD_PROGRAM = 4'h1,  // Load hex program into IMEM
        TRANS_WAIT_CYCLES  = 4'h2,  // Wait N clock cycles
        TRANS_REG_WRITE    = 4'h3,  // Observed: register file write
        TRANS_MEM_WRITE    = 4'h4,  // Observed: data memory write
        TRANS_MEM_READ     = 4'h5,  // Observed: data memory read
        TRANS_BRANCH_TAKEN = 4'h6,  // Observed: branch/jump taken
        TRANS_ECALL        = 4'h7,  // Observed: ecall exception
        TRANS_AXI_WRITE    = 4'h8,  // Observed: AXI Write transaction
        TRANS_AXI_READ     = 4'h9   // Observed: AXI Read transaction
    } trans_type_e;

    // ============================================================
    // RISC-V instruction type enum (for coverage)
    // ============================================================
    typedef enum logic [5:0] {
        INSTR_ADD    = 6'h00, INSTR_SUB   = 6'h01,
        INSTR_AND    = 6'h02, INSTR_OR    = 6'h03,
        INSTR_XOR    = 6'h04, INSTR_SLT   = 6'h05,
        INSTR_SLTU   = 6'h06, INSTR_SLL   = 6'h07,
        INSTR_SRL    = 6'h08, INSTR_SRA   = 6'h09,
        INSTR_ADDI   = 6'h0A, INSTR_ANDI  = 6'h0B,
        INSTR_ORI    = 6'h0C, INSTR_XORI  = 6'h0D,
        INSTR_SLTI   = 6'h0E, INSTR_SLTIU = 6'h0F,
        INSTR_SLLI   = 6'h10, INSTR_SRLI  = 6'h11,
        INSTR_SRAI   = 6'h12, INSTR_LW    = 6'h13,
        INSTR_LH     = 6'h14, INSTR_LB    = 6'h15,
        INSTR_LHU    = 6'h16, INSTR_LBU   = 6'h17,
        INSTR_SW     = 6'h18, INSTR_SH    = 6'h19,
        INSTR_SB     = 6'h1A, INSTR_BEQ   = 6'h1B,
        INSTR_BNE    = 6'h1C, INSTR_BLT   = 6'h1D,
        INSTR_BGE    = 6'h1E, INSTR_BLTU  = 6'h1F,
        INSTR_BGEU   = 6'h20, INSTR_JAL   = 6'h21,
        INSTR_JALR   = 6'h22, INSTR_LUI   = 6'h23,
        INSTR_AUIPC  = 6'h24, INSTR_ECALL = 6'h25,
        INSTR_CSRRW  = 6'h26, INSTR_CSRRS = 6'h27,
        INSTR_CSRRC  = 6'h28, INSTR_NOP   = 6'h3F,
        INSTR_MUL    = 6'h29, INSTR_MULH  = 6'h2A, 
        INSTR_MULHSU = 6'h2B, INSTR_MULHU = 6'h2C,
        INSTR_DIV    = 6'h2D, INSTR_DIVU  = 6'h2E, 
        INSTR_REM    = 6'h2F, INSTR_REMU  = 6'h30,
        INSTR_MRET   = 6'h31, INSTR_SRET  = 6'h32,
        INSTR_SFENCE_VMA = 6'h33
    } instr_type_e;

    // ============================================================
    // Stimulus fields (driven by sequences / driver)
    // ============================================================
    rand trans_type_e  trans_type;
    rand int unsigned  wait_cycles;     // Used with TRANS_WAIT_CYCLES
    rand bit           rst_val;         // 0=assert reset, 1=deassert
    string             program_hex_file;// Path to .hex file to load

    // ============================================================
    // Observed fields (captured by monitor)
    // ============================================================
    logic [31:0]  pc;            // PC at time of transaction
    logic [31:0]  instr;         // Raw instruction word
    instr_type_e  instr_type;    // Decoded instruction type
    logic [4:0]   rs1, rs2, rd;  // Register addresses
    logic [31:0]  rs1_val;       // Forwarded src A value
    logic [31:0]  rs2_val;       // Forwarded src B value
    logic [31:0]  result;        // ALU result / write-back value
    logic [31:0]  mem_addr;      // Memory access address
    logic [31:0]  mem_wdata;     // Memory write data
    logic [31:0]  mem_rdata;     // Memory read data
    logic [2:0]   funct3;        // funct3 for load/store width
    logic         branch_taken;  // Was branch actually taken?
    logic [31:0]  branch_target; // Target PC for branch/jump
    logic         stall_seen;    // Pipeline was stalled this cycle
    logic         icache_stall;  // I-Cache stall seen
    logic         dcache_stall;  // D-Cache stall seen
    logic         issue_stall;   // Issue stage was stalled
    logic         issue_valid;   // Issue dispatched
    logic         execute_ready; // EX stage was ready
    logic         load_use_hazard; // Detected load-use hazard
    logic         predict_taken;   // Did branch predictor predict taken?
    logic [31:0]  predict_target;  // What was the predicted target?
    logic         actual_taken;    // Was it actually taken?
    logic [31:0]  actual_target;   // What was the actual target?
    logic         mispredict;      // Was it a misprediction?
    longint       timestamp;     // $time when captured

    // ============================================================
    // Constraints
    // ============================================================
    constraint c_wait_range {
        wait_cycles inside {[1:500]};
    }

    constraint c_trans_type_dist {
        trans_type dist {
            TRANS_RESET        := 1,
            TRANS_LOAD_PROGRAM := 1,
            TRANS_WAIT_CYCLES  := 5
        };
    }

    // ============================================================
    // Constructor
    // ============================================================
    function new(string name = "riscv_seq_item");
        super.new(name);
        program_hex_file = "full_test.hex";
    endfunction

    // ============================================================
    // UVM field automation (for copy, compare, print, pack)
    // ============================================================
    `uvm_object_utils_begin(riscv_seq_item)
        `uvm_field_enum(trans_type_e, trans_type, UVM_ALL_ON)
        `uvm_field_int(wait_cycles,     UVM_ALL_ON)
        `uvm_field_int(rst_val,         UVM_ALL_ON)
        `uvm_field_string(program_hex_file, UVM_ALL_ON)
        `uvm_field_int(pc,              UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(instr,           UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rs1,             UVM_ALL_ON)
        `uvm_field_int(rs2,             UVM_ALL_ON)
        `uvm_field_int(rd,              UVM_ALL_ON)
        `uvm_field_int(result,          UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(mem_addr,        UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(mem_wdata,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(mem_rdata,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(branch_taken,    UVM_ALL_ON)
        `uvm_field_int(branch_target,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(stall_seen,      UVM_ALL_ON)
        `uvm_field_int(issue_stall,     UVM_ALL_ON)
        `uvm_field_int(issue_valid,     UVM_ALL_ON)
        `uvm_field_int(execute_ready,   UVM_ALL_ON)
        `uvm_field_int(load_use_hazard, UVM_ALL_ON)
        `uvm_field_int(predict_taken,   UVM_ALL_ON)
        `uvm_field_int(predict_target,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(actual_taken,    UVM_ALL_ON)
        `uvm_field_int(actual_target,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(mispredict,      UVM_ALL_ON)
        `uvm_field_int(timestamp,       UVM_ALL_ON)
    `uvm_object_utils_end

    // ============================================================
    // Decode raw instruction to instr_type_e
    // ============================================================
    function void decode_instr(logic [31:0] raw_instr);
        logic [6:0] opcode = raw_instr[6:0];
        logic [2:0] fn3    = raw_instr[14:12];
        logic [6:0] fn7    = raw_instr[31:25];

        this.instr  = raw_instr;
        this.rs1    = raw_instr[19:15];
        this.rs2    = raw_instr[24:20];
        this.rd     = raw_instr[11:7];
        this.funct3 = fn3;

        case (opcode)
            7'b0110011: begin // R-type
                if (fn7 == 7'b0000001) begin // RV32M
                    case (fn3)
                        3'b000: instr_type = INSTR_MUL;
                        3'b001: instr_type = INSTR_MULH;
                        3'b010: instr_type = INSTR_MULHSU;
                        3'b011: instr_type = INSTR_MULHU;
                        3'b100: instr_type = INSTR_DIV;
                        3'b101: instr_type = INSTR_DIVU;
                        3'b110: instr_type = INSTR_REM;
                        3'b111: instr_type = INSTR_REMU;
                        default: instr_type = INSTR_NOP;
                    endcase
                end else begin
                    case ({fn7[5], fn3})
                        4'b0000: instr_type = INSTR_ADD;
                        4'b1000: instr_type = INSTR_SUB;
                        4'b0001: instr_type = INSTR_SLL;
                        4'b0010: instr_type = INSTR_SLT;
                        4'b0011: instr_type = INSTR_SLTU;
                        4'b0100: instr_type = INSTR_XOR;
                        4'b0101: instr_type = INSTR_SRL;
                        4'b1101: instr_type = INSTR_SRA;
                        4'b0110: instr_type = INSTR_OR;
                        4'b0111: instr_type = INSTR_AND;
                        default: instr_type = INSTR_NOP;
                    endcase
                end
            end
            7'b0010011: begin // I-type ALU
                case (fn3)
                    3'b000: instr_type = INSTR_ADDI;
                    3'b001: instr_type = INSTR_SLLI;
                    3'b010: instr_type = INSTR_SLTI;
                    3'b011: instr_type = INSTR_SLTIU;
                    3'b100: instr_type = INSTR_XORI;
                    3'b101: instr_type = (fn7[5]) ? INSTR_SRAI : INSTR_SRLI;
                    3'b110: instr_type = INSTR_ORI;
                    3'b111: instr_type = INSTR_ANDI;
                    default: instr_type = INSTR_NOP;
                endcase
            end
            7'b0000011: begin // Load
                case (fn3)
                    3'b000: instr_type = INSTR_LB;
                    3'b001: instr_type = INSTR_LH;
                    3'b010: instr_type = INSTR_LW;
                    3'b100: instr_type = INSTR_LBU;
                    3'b101: instr_type = INSTR_LHU;
                    default: instr_type = INSTR_NOP;
                endcase
            end
            7'b0100011: begin // Store
                case (fn3)
                    3'b000: instr_type = INSTR_SB;
                    3'b001: instr_type = INSTR_SH;
                    3'b010: instr_type = INSTR_SW;
                    default: instr_type = INSTR_NOP;
                endcase
            end
            7'b1100011: begin // Branch
                case (fn3)
                    3'b000: instr_type = INSTR_BEQ;
                    3'b001: instr_type = INSTR_BNE;
                    3'b100: instr_type = INSTR_BLT;
                    3'b101: instr_type = INSTR_BGE;
                    3'b110: instr_type = INSTR_BLTU;
                    3'b111: instr_type = INSTR_BGEU;
                    default: instr_type = INSTR_NOP;
                endcase
            end
            7'b1101111: instr_type = INSTR_JAL;
            7'b1100111: instr_type = INSTR_JALR;
            7'b0110111: instr_type = INSTR_LUI;
            7'b0010111: instr_type = INSTR_AUIPC;
            7'b1110011: begin
                if (fn3 == 3'b000)
                    instr_type = INSTR_ECALL;
                else begin
                    case (fn3)
                        3'b001: instr_type = INSTR_CSRRW;
                        3'b010: instr_type = INSTR_CSRRS;
                        3'b011: instr_type = INSTR_CSRRC;
                        default: instr_type = INSTR_NOP;
                    endcase
                end
            end
            default: instr_type = INSTR_NOP;
        endcase
    endfunction

    // ============================================================
    // convert2string – human-readable transaction summary
    // ============================================================
    function string convert2string();
        string s;
        s = $sformatf("[%0t] TRANS=%0s ", timestamp, trans_type.name());
        case (trans_type)
            TRANS_REG_WRITE:
                s = {s, $sformatf("PC=0x%08h INSTR=%0s rd=x%0d result=0x%08h",
                    pc, instr_type.name(), rd, result)};
            TRANS_MEM_WRITE:
                s = {s, $sformatf("PC=0x%08h addr=0x%08h wdata=0x%08h funct3=%0b",
                    pc, mem_addr, mem_wdata, funct3)};
            TRANS_MEM_READ:
                s = {s, $sformatf("PC=0x%08h addr=0x%08h rdata=0x%08h funct3=%0b",
                    pc, mem_addr, mem_rdata, funct3)};
            TRANS_BRANCH_TAKEN:
                s = {s, $sformatf("PC=0x%08h target=0x%08h taken=%0b",
                    pc, branch_target, branch_taken)};
            TRANS_ECALL:
                s = {s, $sformatf("PC=0x%08h trap_vec=0x%08h", pc, branch_target)};
            TRANS_RESET:
                s = {s, $sformatf("rst=%0b", rst_val)};
            TRANS_WAIT_CYCLES:
                s = {s, $sformatf("cycles=%0d", wait_cycles)};
            TRANS_LOAD_PROGRAM:
                s = {s, $sformatf("file=%0s", program_hex_file)};
            TRANS_AXI_WRITE:
                s = {s, "AXI_WRITE completed"};
            TRANS_AXI_READ:
                s = {s, "AXI_READ completed"};
        endcase
        if (stall_seen) s = {s, " [STALL]"};
        return s;
    endfunction

endclass : riscv_seq_item

`endif // RISCV_SEQ_ITEM_SV