// ============================================================
// File: tb_top.sv
// Description: Top-level testbench module.
//
//  Responsibilities:
//  1. Generate clock
//  2. Instantiate DUT (riscv_pipeline_top)
//  3. Instantiate interface and connect to DUT via
//     hierarchical signal assignment
//  4. Push interface into UVM config_db
//  5. Call run_test() to start UVM phases
// ============================================================

`timescale 1ns / 1ps
`include "riscv_tb_pkg.sv" // includes all UVM components
module tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import riscv_tb_pkg::*;

    // --------------------------------------------------------
    // Clock generation: 100 MHz → 10 ns period
    // --------------------------------------------------------
    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // Interface instantiation
    // --------------------------------------------------------
    riscv_if riscv_if_inst (.clk(clk));

    // --------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------
    riscv_pipeline_top dut (
        .clk(clk),
        .rst(riscv_if_inst.rst)
    );

    // --------------------------------------------------------
    // Connect interface signals to DUT internal signals
    // via hierarchical references (probe points).
    // These are read-only observation wires.
    // --------------------------------------------------------

    // --- Fetch stage ---
    assign riscv_if_inst.pc_f        = dut.pc_f;
    assign riscv_if_inst.pc_plus_4_f = dut.pc_plus_4_f;
    assign riscv_if_inst.instr_f     = dut.instr_f;

    // --- Decode stage ---
    assign riscv_if_inst.instr_d     = dut.instr_d;
    assign riscv_if_inst.pc_d        = dut.pc_d;
    assign riscv_if_inst.rs1_d       = dut.rs1_d;
    assign riscv_if_inst.rs2_d       = dut.rs2_d;
    assign riscv_if_inst.rd_d        = dut.rd_d;
    assign riscv_if_inst.reg_write_d = dut.reg_write_d;
    assign riscv_if_inst.mem_write_d = dut.mem_write_d;
    assign riscv_if_inst.branch_d    = dut.branch_d;
    assign riscv_if_inst.jump_d      = dut.jump_d;

    // --- Execute stage ---
    assign riscv_if_inst.alu_result_e = dut.alu_result_e;
    assign riscv_if_inst.pc_src_e     = dut.pc_src_e;
    assign riscv_if_inst.pc_target_e  = dut.pc_target_e;
    assign riscv_if_inst.pc_e         = dut.pc_e;

    // --- Memory stage ---
    assign riscv_if_inst.alu_result_m  = dut.alu_result_m;
    assign riscv_if_inst.write_data_m  = dut.write_data_m;
    assign riscv_if_inst.mem_write_m   = dut.mem_write_m;
    assign riscv_if_inst.funct3_m      = dut.funct3_m;
    assign riscv_if_inst.result_src_m  = dut.result_src_m;
    assign riscv_if_inst.read_data_m   = dut.read_data_m;

    // --- Writeback stage ---
    assign riscv_if_inst.result_w    = dut.result_w;
    assign riscv_if_inst.rd_w        = dut.rd_w;
    assign riscv_if_inst.reg_write_w = dut.reg_write_w;

    // --- Hazard / stall ---
    assign riscv_if_inst.stall_f      = dut.stall_f;
    assign riscv_if_inst.flush_d      = dut.flush_d;
    assign riscv_if_inst.icache_stall = dut.icache_stall;
    assign riscv_if_inst.dcache_stall = dut.dcache_stall;

    // --- CSR / exception ---
    assign riscv_if_inst.is_ecall_d = dut.is_ecall_d;
    assign riscv_if_inst.is_mret_d  = dut.is_mret_d;
    assign riscv_if_inst.trap_vec   = dut.trap_vec;
    assign riscv_if_inst.epc        = dut.epc;

    // --------------------------------------------------------
    // UVM config_db: push virtual interface to all components
    // --------------------------------------------------------
    initial begin
        uvm_config_db #(virtual riscv_if)::set(
            null,           // from top (null = root)
            "uvm_test_top*", // to all children
            "vif",
            riscv_if_inst
        );
    end

    // --------------------------------------------------------
    // UVM verbosity control via plusarg
    // --------------------------------------------------------
    initial begin
        string verb_str;
        if ($value$plusargs("UVM_VERBOSITY=%s", verb_str)) begin
            case (verb_str)
                "UVM_NONE":   uvm_top.set_report_verbosity_level_hier(UVM_NONE);
                "UVM_LOW":    uvm_top.set_report_verbosity_level_hier(UVM_LOW);
                "UVM_MEDIUM": uvm_top.set_report_verbosity_level_hier(UVM_MEDIUM);
                "UVM_HIGH":   uvm_top.set_report_verbosity_level_hier(UVM_HIGH);
                "UVM_FULL":   uvm_top.set_report_verbosity_level_hier(UVM_FULL);
                default:      uvm_top.set_report_verbosity_level_hier(UVM_MEDIUM);
            endcase
        end
    end

    // --------------------------------------------------------
    // Simulation timeout safety net (backup to UVM watchdog)
    // --------------------------------------------------------
    initial begin
        static int unsigned max_time = 10_000_000; // 10 ms default
        void'($value$plusargs("MAX_TIME=%d", max_time));
        #(max_time * 1ns);
        $display("[TB_TOP] SIMULATION TIMEOUT at %0t", $time);
        $finish;
    end

    // --------------------------------------------------------
    // Start UVM test
    // --------------------------------------------------------
    initial begin
        run_test(); // UVM_TESTNAME plusarg selects which test
    end

    initial begin
        // Dump waveforms for post-simulation analysis (Optional)
        $wlfdumpvars(0, tb_top);
    end

endmodule : tb_top