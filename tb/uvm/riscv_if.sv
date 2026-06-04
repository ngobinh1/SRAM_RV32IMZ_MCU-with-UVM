// ============================================================
// File: riscv_if.sv
// Description: SystemVerilog Interface for RISC-V Pipeline DUT
//              Exposes clk/rst + internal pipeline signals
//              via hierarchical references for monitoring.
// ============================================================
`include "uvm_macros.svh"
`timescale 1ns / 1ps

import uvm_pkg::*;
interface riscv_if (input logic clk);

    // ------------------------------------------------------------
    // Primary control signals
    // ------------------------------------------------------------
    logic        rst;          // Active-low reset (matches DUT)

    // ------------------------------------------------------------
    // Fetch stage probes
    // ------------------------------------------------------------
    logic [31:0] pc_f;         // Current Program Counter
    logic [31:0] pc_plus_4_f;  // PC + 4
    logic [31:0] instr_f;      // Instruction fetched

    // ------------------------------------------------------------
    // Decode stage probes
    // ------------------------------------------------------------
    logic [31:0] instr_d;      // Instruction in decode
    logic [31:0] pc_d;
    logic [4:0]  rs1_d, rs2_d, rd_d;
    logic        reg_write_d;
    logic        mem_write_d;
    logic        branch_d, jump_d;

    // ------------------------------------------------------------
    // Execute stage probes
    // ------------------------------------------------------------
    logic [31:0] alu_result_e;
    logic        pc_src_e;     // Branch/jump taken
    logic [31:0] pc_target_e;  // Branch/jump target address
    logic [31:0] pc_e;         // PC in execute stage (for ecall/mret handling)
    logic        predict_taken_e;
    logic [31:0] predict_target_e;
    logic        actual_taken_e;
    logic [31:0] actual_target_e;

    // ------------------------------------------------------------
    // Memory stage probes
    // ------------------------------------------------------------
    logic [31:0] pc_m;         // PC in memory stage (for monitoring store instructions)
    logic [31:0] alu_result_m;
    logic [31:0] write_data_m;
    logic        mem_write_m;
    logic [2:0]  funct3_m;
    logic [2:0]  result_src_m;    
    logic [31:0] read_data_m;     // Data read from memory (for load instructions)

    // ------------------------------------------------------------
    // Writeback stage probes
    // ------------------------------------------------------------
    logic [31:0] result_w;     // Data written to register file
    logic [4:0]  rd_w;         // Destination register
    logic        reg_write_w;  // Register write enable

    // ------------------------------------------------------------
    // Hazard / stall / flush signals
    // ------------------------------------------------------------
    logic        stall_f;
    logic        flush_d;
    logic        icache_stall;
    logic        dcache_stall;
    // Issue stage probes
    logic        issue_stall;
    logic        issue_valid;
    logic        execute_ready;
    logic        load_use_hazard;

    // ------------------------------------------------------------
    // CSR / exception signals
    // ------------------------------------------------------------
    logic        is_ecall_d;
    logic        is_mret_d;
    logic [31:0] trap_vec;
    logic [31:0] epc;

    // ------------------------------------------------------------
    // AXI4-Lite signals (for monitoring bus transactions)
    // ------------------------------------------------------------
    // Write Address Channel
    logic [31:0] i_axi_awaddr;
    logic        i_axi_awvalid;
    logic        i_axi_awready;
    // Write Data Channel
    logic [31:0] i_axi_wdata;
    logic [3:0]  i_axi_wstrb;
    logic        i_axi_wvalid;
    logic        i_axi_wready;
    // Write Response Channel
    logic [1:0]  i_axi_bresp;
    logic        i_axi_bvalid;
    logic        i_axi_bready;
    // Read Address Channel
    logic [31:0] i_axi_araddr;
    logic        i_axi_arvalid;
    logic        i_axi_arready;
    // Read Data Channel
    logic [31:0] i_axi_rdata;
    logic [1:0]  i_axi_rresp;
    logic        i_axi_rvalid;
    logic        i_axi_rready;
    // ========================
    //  AXI4-Lite Master Interface (Data Access)
    // ========================
    // Write Address Channel
    logic [31:0] d_axi_awaddr;
    logic        d_axi_awvalid;
    logic        d_axi_awready;
    // Write Data Channel
    logic [31:0] d_axi_wdata;
    logic [3:0]  d_axi_wstrb;
    logic        d_axi_wvalid;
    logic        d_axi_wready;
    // Write Response Channel
    logic [1:0]  d_axi_bresp;
    logic        d_axi_bvalid;
    logic        d_axi_bready;
    // Read Address Channel
    logic [31:0] d_axi_araddr;
    logic        d_axi_arvalid;
    logic        d_axi_arready;
    // Read Data Channel
    logic [31:0] d_axi_rdata;
    logic [1:0]  d_axi_rresp;
    logic        d_axi_rvalid;
    logic        d_axi_rready;
    // ========================
    //  Memory Interface
    // ========================
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_we;

    // ============================================================
    // Clocking Blocks
    // ============================================================

    // Driver clocking block: drive signals 1 step before posedge
    clocking driver_cb @(posedge clk);
        default input #1step output #1;
        output rst;
    endclocking

    // Monitor clocking block: sample signals 1 step after posedge
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst;
        input pc_f;
        input pc_plus_4_f;
        input instr_f;
        input instr_d;
        input pc_d;
        input rs1_d;
        input rs2_d;
        input rd_d;
        input reg_write_d;
        input mem_write_d;
        input branch_d;
        input jump_d;
        input alu_result_e;
        input pc_src_e;
        input pc_target_e;
        input pc_e;
        input predict_taken_e;
        input predict_target_e;
        input actual_taken_e;
        input actual_target_e;
        input pc_m;
        input alu_result_m;
        input write_data_m;
        input mem_write_m;
        input funct3_m;
        input result_src_m;
        input read_data_m;
        input result_w;
        input rd_w;
        input reg_write_w;
        input stall_f;
        input flush_d;
        input icache_stall;
        input dcache_stall;
        input is_ecall_d;
        input is_mret_d;
        input issue_stall;
        input issue_valid;
        input execute_ready;
        input load_use_hazard;
        // AXI signals
        input i_axi_awaddr, i_axi_awvalid, i_axi_awready;
        input i_axi_wdata, i_axi_wstrb, i_axi_wvalid, i_axi_wready;
        input i_axi_bresp, i_axi_bvalid, i_axi_bready;
        input i_axi_araddr, i_axi_arvalid, i_axi_arready;
        input i_axi_rdata, i_axi_rresp, i_axi_rvalid, i_axi_rready;
        input d_axi_awaddr, d_axi_awvalid, d_axi_awready;
        input d_axi_wdata, d_axi_wstrb, d_axi_wvalid, d_axi_wready;
        input d_axi_bresp, d_axi_bvalid, d_axi_bready;
        input d_axi_araddr, d_axi_arvalid, d_axi_arready;
        input d_axi_rdata, d_axi_rresp, d_axi_rvalid, d_axi_rready;
        input mem_addr, mem_wdata, mem_rdata, mem_we;
    endclocking

    // ============================================================
    // Modports
    // ============================================================
    modport driver_mp  (
        clocking driver_cb,  
        input clk,
        import load_imem,
        import clear_dmem
        );
    modport monitor_mp (clocking monitor_cb, input clk);

    // ============================================================
    // Utility Tasks / Functions
    // ============================================================

    // Wait for n rising clock edges
    task automatic wait_clks(int n = 1);
        repeat (n) @(posedge clk);
    endtask

    // Wait until rst is deasserted (pipeline out of reset)
    task automatic wait_reset_done();
        @(posedge clk iff (rst === 1'b1));
        @(posedge clk); // one extra cycle margin
    endtask

    // Check if the pipeline is currently stalled
    function automatic logic is_stalled();
        return (stall_f | icache_stall | dcache_stall);
    endfunction

    // ============================================================
    // Assertions (Simulation-time checks)
    // ============================================================

    // PC must never be X/Z after reset
    property pc_valid_after_reset;
        @(posedge clk) disable iff (!rst)
        !$isunknown(pc_f);
    endproperty

    // Register x0 must never be written
    // property x0_never_written;
    //     @(posedge clk) disable iff (!rst)
    //     (reg_write_w |-> rd_w != 5'b00000);
    // endproperty

    // PC must advance by 4 when not stalled / branching
    property pc_increment;
        @(posedge clk) disable iff (!rst)
        (!stall_f && !pc_src_e && !is_ecall_d && !is_mret_d)
        |=> (pc_f == $past(pc_f) + 32'h4);
    endproperty

    assert property (pc_valid_after_reset)
        else begin 
            $error("[ASSERT] pc_f is X/Z after reset at time %0t", $time);
            $display("DEBUG_ASSERT_X: time=%0t pc_f=%h instr_d=%h pc_d=%h is_ecall_d=%b is_mret_d=%b pc_src_e=%b actual_target_e=%h stall_f=%b pc_plus_4_f=%h", $time, pc_f, instr_d, pc_d, is_ecall_d, is_mret_d, pc_src_e, actual_target_e, stall_f, pc_plus_4_f);
        end

    // assert property (x0_never_written)
    //     else $error("[ASSERT] Attempted write to x0 (rd_w=%0d) at time %0t", rd_w, $time);

    assert property (pc_increment)
        else $warning("[ASSERT] Unexpected PC value after increment at time %0t", $time);

    task automatic load_imem(string hex_file);
        string full_path = {"sim/hex/", hex_file};
        $readmemh(full_path, tb_top.dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory);
        $display("[VIF] Program loaded into memory from %s", hex_file);
        $display("[VIF] memory[0] = %h", tb_top.dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory[0]);
    endtask

    task automatic clear_dmem();
        for (int i = 0; i < 1024; i++) begin
            tb_top.dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory[i] = 32'h0;
        end
        $display("[VIF] Memory cleared.");
    endtask
endinterface : riscv_if