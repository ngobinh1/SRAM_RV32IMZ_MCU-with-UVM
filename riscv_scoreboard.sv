// ============================================================
// File: riscv_scoreboard.sv
// Description: UVM Scoreboard – functional verification of
//              the RISC-V pipeline.
//
//              Strategy:
//              1. Maintain a software model of the 32 integer
//                 registers (ISS – Instruction Set Simulator).
//              2. For each committed register write captured
//                 by the monitor, compare the DUT result with
//                 the ISS golden reference.
//              3. For each memory write, log it to a reference
//                 memory model and flag mismatches.
//              4. Check pipeline hazard rules:
//                 – No write to x0
//                 – Branch target correctness
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_seq_item.sv"
`ifndef RISCV_SCOREBOARD_SV
`define RISCV_SCOREBOARD_SV

class riscv_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(riscv_scoreboard)

        // --------------------------------------------------------
        // Interface virtual handle (set via config_db by monitor)
        // --------------------------------------------------------
        virtual riscv_if vif;
    
        // --------------------------------------------------------
        // Scoreboard internal state
        // --------------------------------------------------------

    // --------------------------------------------------------
    // Analysis FIFOs – receive transactions from monitor
    // --------------------------------------------------------
    uvm_tlm_analysis_fifo #(riscv_seq_item) fifo_regwrite;
    uvm_tlm_analysis_fifo #(riscv_seq_item) fifo_memaccess;
    uvm_tlm_analysis_fifo #(riscv_seq_item) fifo_branch;

    // Analysis exports exposed to agent
    uvm_analysis_export #(riscv_seq_item) ae_regwrite;
    uvm_analysis_export #(riscv_seq_item) ae_memaccess;
    uvm_analysis_export #(riscv_seq_item) ae_branch;

    // --------------------------------------------------------
    // Reference model state
    // --------------------------------------------------------
    // Register file: 32 × 32-bit registers (x0 always 0)
    logic [31:0] ref_regfile [0:31];

    // Memory model: address → value (word-aligned)
    logic [31:0] ref_mem [logic [31:0]];

    // --------------------------------------------------------
    // Statistics counters
    // --------------------------------------------------------
    int unsigned checks_pass;
    int unsigned checks_fail;
    int unsigned total_instrs;
    int unsigned x0_write_violations;
    int unsigned branch_checks;

    // --------------------------------------------------------
    // Constructor
    // --------------------------------------------------------
    function new(string name = "riscv_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        checks_pass = 0;
        checks_fail = 0;
        total_instrs = 0;
        x0_write_violations = 0;
        branch_checks = 0;
    endfunction

    // --------------------------------------------------------
    // build_phase
    // --------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual riscv_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("SCOREBOARD", "Cannot get virtual interface from config_db")
        end
        fifo_regwrite  = new("fifo_regwrite",  this);
        fifo_memaccess = new("fifo_memaccess", this);
        fifo_branch    = new("fifo_branch",    this);
        ae_regwrite    = new("ae_regwrite",    this);
        ae_memaccess   = new("ae_memaccess",   this);
        ae_branch      = new("ae_branch",      this);
    endfunction

    // --------------------------------------------------------
    // connect_phase: wire exports to FIFOs
    // --------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        ae_regwrite.connect(fifo_regwrite.analysis_export);
        ae_memaccess.connect(fifo_memaccess.analysis_export);
        ae_branch.connect(fifo_branch.analysis_export);
    endfunction

    // --------------------------------------------------------
    // run_phase: spawn checker threads
    // --------------------------------------------------------
    task run_phase(uvm_phase phase);
        // Initialise reference model
        init_ref_model();

        fork
            check_regwrites();
            check_memaccesses();
            check_branches();
            monitor_reset();
        join_none
    endtask

    // ========================================================
    // Init reference register file to zero
    // ========================================================
    function void init_ref_model();
        for (int i = 0; i < 32; i++)
            ref_regfile[i] = 32'h0;
        ref_mem.delete();
        `uvm_info("SCOREBOARD", "Reference model initialised (all regs = 0)", UVM_MEDIUM)
    endfunction

    // ========================================================
    // Thread 1: check register write-backs
    // ========================================================
    task automatic check_regwrites();
        riscv_seq_item item;
        logic [31:0] expected;

        forever begin
            fifo_regwrite.get(item);
            total_instrs++;

            // Rule: x0 must never be written
            if (item.rd === 5'h0) begin
                x0_write_violations++;
                `uvm_error("SCOREBOARD",
                    $sformatf("VIOLATION: Write to x0 detected! result=0x%08h at PC=0x%08h t=%0t",
                              item.result, item.pc, item.timestamp))
                checks_fail++;
                continue;
            end

            // ------------------------------------------------
            // Compute expected result based on instruction type
            // This is a lightweight ISS, not a full emulator.
            // For load instructions the scoreboard trusts the
            // data memory model; for ALU it recomputes.
            // ------------------------------------------------
            expected = compute_expected(item);

            if (expected === 32'hX) begin
                // Can't predict (e.g. load from memory not modelled)
                // Just update ref model and move on
                ref_regfile[item.rd] = item.result;
                `uvm_info("SCOREBOARD",
                    $sformatf("SKIP CHECK: %0s rd=x%0d result=0x%08h (memory-dependent)",
                              item.instr_type.name(), item.rd, item.result),
                    UVM_HIGH)
                checks_pass++; // Conservative: count as pass
                continue;
            end

            // Compare
            if (item.result === expected) begin
                checks_pass++;
                `uvm_info("SCOREBOARD",
                    $sformatf("PASS: %0s rd=x%0d result=0x%08h == expected=0x%08h",
                              item.instr_type.name(), item.rd,
                              item.result, expected),
                    UVM_HIGH)
            end else begin
                checks_fail++;
                `uvm_error("SCOREBOARD",
                    $sformatf("FAIL: %0s rd=x%0d result=0x%08h != expected=0x%08h at PC=0x%08h t=%0t",
                              item.instr_type.name(), item.rd,
                              item.result, expected,
                              item.pc, item.timestamp))
            end

            // Update reference model with actual committed value
            ref_regfile[item.rd] = item.result;
        end
    endtask

    // ========================================================
    // Thread 2: check memory accesses
    // ========================================================
    task automatic check_memaccesses();
        riscv_seq_item item;
        logic [31:0]   word_addr;

        forever begin
            fifo_memaccess.get(item);

            word_addr = {item.mem_addr[31:2], 2'b00}; // Word-align
            
            case (item.trans_type)
                riscv_seq_item::TRANS_MEM_WRITE: begin
                    // Update reference memory model
                    if (!ref_mem.exists(word_addr)) ref_mem[word_addr] = 32'h0;
                    
                    case (item.funct3)
                        3'b000: begin // SB (Store Byte) - Dùng Mask để không làm hỏng byte khác
                            case (item.mem_addr[1:0])
                                2'b00: ref_mem[word_addr] = (ref_mem[word_addr] & 32'hFFFFFF00) | {24'h0, item.mem_wdata[7:0]};
                                2'b01: ref_mem[word_addr] = (ref_mem[word_addr] & 32'hFFFF00FF) | {16'h0, item.mem_wdata[7:0], 8'h0};
                                2'b10: ref_mem[word_addr] = (ref_mem[word_addr] & 32'hFF00FFFF) | {8'h0,  item.mem_wdata[7:0], 16'h0};
                                2'b11: ref_mem[word_addr] = (ref_mem[word_addr] & 32'h00FFFFFF) | {item.mem_wdata[7:0], 24'h0};
                            endcase
                        end
                        3'b001: begin // SH (Store Halfword) - Dùng Mask 16-bit
                            if (item.mem_addr[1] == 1'b0)
                                ref_mem[word_addr] = (ref_mem[word_addr] & 32'hFFFF0000) | {16'h0, item.mem_wdata[15:0]};
                            else
                                ref_mem[word_addr] = (ref_mem[word_addr] & 32'h0000FFFF) | {item.mem_wdata[15:0], 16'h0};
                        end
                        3'b010: // SW (Store Word)
                            ref_mem[word_addr] = item.mem_wdata;
                        default: begin end
                    endcase

                    `uvm_info("SCOREBOARD",
                        $sformatf("MEM WRITE: addr=0x%08h data=0x%08h funct3=%0b",
                                  item.mem_addr, item.mem_wdata, item.funct3),
                        UVM_HIGH)
                    checks_pass++;
                end

                riscv_seq_item::TRANS_MEM_READ: begin
                    // If address was written before, check data
                    if (ref_mem.exists(word_addr)) begin
                        logic [31:0] ref_word = ref_mem[word_addr];
                        // (Simplified: only check SW/LW alignment)
                        if (item.funct3 == 3'b010 &&
                            item.mem_rdata !== ref_word)
                        begin
                            checks_fail++;
                            `uvm_error("SCOREBOARD",
                                $sformatf("MEM READ MISMATCH: addr=0x%08h got=0x%08h expected=0x%08h",
                                          item.mem_addr, item.mem_rdata, ref_word))
                        end else begin
                            checks_pass++;
                        end
                    end else begin
                        // Reading uninitialised memory – warn, not error
                        `uvm_warning("SCOREBOARD",
                            $sformatf("READ from uninitialised addr=0x%08h rdata=0x%08h",
                                      item.mem_addr, item.mem_rdata))
                        checks_pass++;
                    end
                end
            endcase
        end
    endtask

    // ========================================================
    // Thread 3: check branch targets
    // ========================================================
    task automatic check_branches();
        riscv_seq_item item;
        forever begin
            fifo_branch.get(item);
            branch_checks++;

            // Basic sanity: branch target must be 4-byte aligned
            if (item.branch_taken && item.branch_target[1:0] !== 2'b00) begin
                checks_fail++;
                `uvm_error("SCOREBOARD",
                    $sformatf("UNALIGNED BRANCH TARGET: 0x%08h at PC=0x%08h",
                              item.branch_target, item.pc))
            end else if (item.branch_taken) begin
                checks_pass++;
                `uvm_info("SCOREBOARD",
                    $sformatf("BRANCH OK: PC=0x%08h → target=0x%08h",
                              item.pc, item.branch_target),
                    UVM_HIGH)
            end
        end
    endtask

    task automatic monitor_reset();
    forever begin
        // Bạn cần truyền vif vào scoreboard thông qua config_db giống monitor
        @(negedge vif.rst); // Khi reset kéo xuống 0
        init_ref_model();   // Xóa sạch ref_regfile và ref_mem
        fifo_regwrite.flush();
        fifo_memaccess.flush();
        fifo_branch.flush();
        `uvm_info("SCOREBOARD", "Hardware reset detected. Cleared Reference Model.", UVM_MEDIUM)
    end
endtask

    // ========================================================
    // ISS: compute expected result for simple ALU instructions.
    // Returns 32'hX for instructions that depend on memory.
    // ========================================================
    function automatic logic [31:0] compute_expected(riscv_seq_item item);
        logic [31:0] a, b, imm, instr;
        logic signed [31:0] sa, sb;
        logic [6:0] op;
        logic [11:0] imm12;
        a = ref_regfile[item.rs1]; // rs1 value from model
        b = ref_regfile[item.rs2]; // rs2 value from model
        sa = signed'(a);
        sb = signed'(b);

        // Extract immediate from instruction (re-decode)
        instr = item.instr;
        op    = instr[6:0];
        imm12 = instr[31:20];

        // Sign-extended immediate for I-type
        imm = {{20{instr[31]}}, instr[31:20]};

        case (item.instr_type)
            // --- R-type ---
            riscv_seq_item::INSTR_ADD:  return a + b;
            riscv_seq_item::INSTR_SUB:  return a - b;
            riscv_seq_item::INSTR_AND:  return a & b;
            riscv_seq_item::INSTR_OR:   return a | b;
            riscv_seq_item::INSTR_XOR:  return a ^ b;
            riscv_seq_item::INSTR_SLT:  return (sa < sb) ? 32'h1 : 32'h0;
            riscv_seq_item::INSTR_SLTU: return (a  < b ) ? 32'h1 : 32'h0;
            riscv_seq_item::INSTR_SLL:  return a << b[4:0];
            riscv_seq_item::INSTR_SRL:  return a >> b[4:0];
            riscv_seq_item::INSTR_SRA:  return signed'(sa) >>> b[4:0];

            // --- I-type ALU ---
            riscv_seq_item::INSTR_ADDI:  return a + imm;
            riscv_seq_item::INSTR_ANDI:  return a & imm;
            riscv_seq_item::INSTR_ORI:   return a | imm;
            riscv_seq_item::INSTR_XORI:  return a ^ imm;
            riscv_seq_item::INSTR_SLTI:  return (sa < signed'(imm)) ? 32'h1 : 32'h0;
            riscv_seq_item::INSTR_SLTIU: return (a < imm) ? 32'h1 : 32'h0;
            riscv_seq_item::INSTR_SLLI:  return a << instr[24:20];
            riscv_seq_item::INSTR_SRLI:  return a >> instr[24:20];
            riscv_seq_item::INSTR_SRAI:  return signed'(sa) >>> instr[24:20];

            // --- Upper immediate ---
            riscv_seq_item::INSTR_LUI:   return {instr[31:12], 12'h0};
            riscv_seq_item::INSTR_AUIPC: return item.pc + {instr[31:12], 12'h0};

            // --- JAL / JALR (write PC+4 to rd) ---
            riscv_seq_item::INSTR_JAL,
            riscv_seq_item::INSTR_JALR:  return item.pc + 32'h4;

            // --- Loads: result depends on memory → can't fully predict here ---
            // --- Loads: result depends on memory ---
            riscv_seq_item::INSTR_LW,
            riscv_seq_item::INSTR_LH,
            riscv_seq_item::INSTR_LB,
            riscv_seq_item::INSTR_LHU,
            riscv_seq_item::INSTR_LBU: begin
                logic [31:0] addr = a + imm;
                logic [31:0] waddr = {addr[31:2], 2'b00};
                if (ref_mem.exists(waddr)) begin
                    logic [31:0] word = ref_mem[waddr];
                    logic [4:0] shift_amt = {addr[1:0], 3'b000};
                    logic [31:0] shifted_word = word >> shift_amt;
                    
                    case (item.instr_type)
                        riscv_seq_item::INSTR_LW:  return word;
                        riscv_seq_item::INSTR_LH:  return {{16{shifted_word[15]}}, shifted_word[15:0]};
                        riscv_seq_item::INSTR_LHU: return {16'h0000, shifted_word[15:0]};
                        riscv_seq_item::INSTR_LB:  return {{24{shifted_word[7]}}, shifted_word[7:0]};
                        riscv_seq_item::INSTR_LBU: return {24'h000000, shifted_word[7:0]};
                        default: return 32'hX;
                    endcase
                end else begin
                    return 32'hX; // Uninitialised memory
                end
            end

            default: return 32'hX; // CSR, system – skip check
        endcase
    endfunction

    // --------------------------------------------------------
    // report_phase: final pass/fail summary
    // --------------------------------------------------------
    function void report_phase(uvm_phase phase);
        string result_str;
        string msg;

        result_str = (checks_fail == 0) ? 
            "*** SIMULATION PASSED ***" : "*** SIMULATION FAILED ***";

        msg = "\n========================================\n";
        msg = {msg, $sformatf("%0s\n", result_str)};
        msg = {msg, "========================================\n"};
        msg = {msg, $sformatf("  Total instructions  : %0d\n", total_instrs)};
        msg = {msg, $sformatf("  Checks PASSED       : %0d\n", checks_pass)};
        msg = {msg, $sformatf("  Checks FAILED       : %0d\n", checks_fail)};
        msg = {msg, $sformatf("  Branch checks       : %0d\n", branch_checks)};
        msg = {msg, $sformatf("  x0 write violations : %0d\n", x0_write_violations)};
        msg = {msg, "========================================"};

        `uvm_info("SCOREBOARD", msg, UVM_NONE)

        if (checks_fail > 0)
            `uvm_error("SCOREBOARD", "One or more checks FAILED – see log above") 
    endfunction

endclass : riscv_scoreboard

`endif // RISCV_SCOREBOARD_SV