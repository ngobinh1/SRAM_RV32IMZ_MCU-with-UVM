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
    assign riscv_if_inst.predict_taken_e  = dut.predict_taken_e;
    assign riscv_if_inst.predict_target_e = dut.predict_target_e;
    assign riscv_if_inst.actual_taken_e   = dut.actual_taken_e;
    assign riscv_if_inst.actual_target_e  = dut.actual_target_e;

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
    assign riscv_if_inst.stall_d      = dut.stall_d;
    assign riscv_if_inst.flush_d      = dut.flush_d;
    assign riscv_if_inst.icache_stall = dut.icache_stall;
    assign riscv_if_inst.dcache_stall = dut.dcache_stall;

    // --- CSR / exception ---
    assign riscv_if_inst.is_ecall_d = dut.is_ecall_d;
    assign riscv_if_inst.is_mret_d  = dut.is_mret_d;
    assign riscv_if_inst.is_sret_d  = dut.is_sret_d;
    assign riscv_if_inst.trap_vec   = dut.trap_vec;
    assign riscv_if_inst.epc        = dut.epc;

    // --- AXI4-Lite signals (Master 0 - I-Cache) ---
    assign riscv_if_inst.i_axi_araddr  = dut.i_araddr;
    assign riscv_if_inst.i_axi_arvalid = dut.i_arvalid;
    assign riscv_if_inst.i_axi_arready = dut.i_arready;
    assign riscv_if_inst.i_axi_rdata   = dut.i_rdata;
    assign riscv_if_inst.i_axi_rresp   = dut.i_rresp;
    assign riscv_if_inst.i_axi_rvalid  = dut.i_rvalid;
    assign riscv_if_inst.i_axi_rready  = dut.i_rready;
    // Note: I-Cache only reads, so no aw/w/b channels mapped.

    // --- AXI4-Lite signals (Master 1 - D-Cache) ---
    assign riscv_if_inst.d_axi_awaddr  = dut.d_awaddr;
    assign riscv_if_inst.d_axi_awvalid = dut.d_awvalid;
    assign riscv_if_inst.d_axi_awready = dut.d_awready;
    assign riscv_if_inst.d_axi_wdata   = dut.d_wdata;
    assign riscv_if_inst.d_axi_wstrb   = dut.d_wstrb;
    assign riscv_if_inst.d_axi_wvalid  = dut.d_wvalid;
    assign riscv_if_inst.d_axi_wready  = dut.d_wready;
    assign riscv_if_inst.d_axi_bresp   = dut.d_bresp;
    assign riscv_if_inst.d_axi_bvalid  = dut.d_bvalid;
    assign riscv_if_inst.d_axi_bready  = dut.d_bready;
    assign riscv_if_inst.d_axi_araddr  = dut.d_araddr;
    assign riscv_if_inst.d_axi_arvalid = dut.d_arvalid;
    assign riscv_if_inst.d_axi_arready = dut.d_arready;
    assign riscv_if_inst.d_axi_rdata   = dut.d_rdata;
    assign riscv_if_inst.d_axi_rresp   = dut.d_rresp;
    assign riscv_if_inst.d_axi_rvalid  = dut.d_rvalid;
    assign riscv_if_inst.d_axi_rready  = dut.d_rready;

    // --- Issue Stage Probes ---
    assign riscv_if_inst.issue_stall     = dut.issue_stall;
    assign riscv_if_inst.issue_valid     = dut.issue_valid;
    assign riscv_if_inst.execute_ready   = dut.issue_stage.execute_ready;
    assign riscv_if_inst.load_use_hazard = dut.issue_stage.load_use_hazard;

    wire [31:0] reg_x0  = dut.decode_stage.register_file.register_array[0];
    wire [31:0] reg_x1  = dut.decode_stage.register_file.register_array[1];
    wire [31:0] reg_x2  = dut.decode_stage.register_file.register_array[2];
    wire [31:0] reg_x3  = dut.decode_stage.register_file.register_array[3];
    wire [31:0] reg_x4  = dut.decode_stage.register_file.register_array[4];
    wire [31:0] reg_x5  = dut.decode_stage.register_file.register_array[5];
    wire [31:0] reg_x6  = dut.decode_stage.register_file.register_array[6];
    wire [31:0] reg_x7  = dut.decode_stage.register_file.register_array[7];
    wire [31:0] reg_x8  = dut.decode_stage.register_file.register_array[8];
    wire [31:0] reg_x9  = dut.decode_stage.register_file.register_array[9];
    wire [31:0] reg_x10 = dut.decode_stage.register_file.register_array[10];
    wire [31:0] reg_x11 = dut.decode_stage.register_file.register_array[11];
    wire [31:0] reg_x12 = dut.decode_stage.register_file.register_array[12];
    wire [31:0] reg_x13 = dut.decode_stage.register_file.register_array[13];
    wire [31:0] reg_x14 = dut.decode_stage.register_file.register_array[14];
    wire [31:0] reg_x15 = dut.decode_stage.register_file.register_array[15];
    wire [31:0] reg_x16 = dut.decode_stage.register_file.register_array[16];
    wire [31:0] reg_x17 = dut.decode_stage.register_file.register_array[17];
    wire [31:0] reg_x18 = dut.decode_stage.register_file.register_array[18];
    wire [31:0] reg_x19 = dut.decode_stage.register_file.register_array[19];
    wire [31:0] reg_x20 = dut.decode_stage.register_file.register_array[20];
    wire [31:0] reg_x21 = dut.decode_stage.register_file.register_array[21];
    wire [31:0] reg_x22 = dut.decode_stage.register_file.register_array[22];
    wire [31:0] reg_x23 = dut.decode_stage.register_file.register_array[23];
    wire [31:0] reg_x24 = dut.decode_stage.register_file.register_array[24];
    wire [31:0] reg_x25 = dut.decode_stage.register_file.register_array[25];
    wire [31:0] reg_x26 = dut.decode_stage.register_file.register_array[26];
    wire [31:0] reg_x27 = dut.decode_stage.register_file.register_array[27];
    wire [31:0] reg_x28 = dut.decode_stage.register_file.register_array[28];
    wire [31:0] reg_x29 = dut.decode_stage.register_file.register_array[29];
    wire [31:0] reg_x30 = dut.decode_stage.register_file.register_array[30];
    wire [31:0] reg_x31 = dut.decode_stage.register_file.register_array[31];

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
    // RVFI Tracer — simulation-only instruction trace logger
    // --------------------------------------------------------
    rvfi_tracer u_rvfi_tracer (
        .clk           (clk),
        .rst_n         (riscv_if_inst.rst),

        // Decode stage
        .instr_d       (dut.instr_d),
        .pc_d          (dut.pc_d),
        .reg_write_d   (dut.reg_write_d),
        .mem_write_d   (dut.mem_write_d),
        .rd_d          (dut.rd_d),
        .funct3_d      (dut.funct3_d),

        // Pipeline flow control
        .stall_f       (dut.stall_f),
        .flush_d       (dut.flush_d),
        .flush_e       (dut.flush_e),
        .stall_e       (dut.stall_e),
        .stall_m       (dut.stall_m),
        .stall_w       (dut.stall_w),
        .issue_valid   (dut.issue_valid),

        // Writeback stage (actual committed values)
        .reg_write_w   (dut.reg_write_w),
        .rd_w          (dut.rd_w),
        .result_w      (dut.result_w),

        // Memory stage
        .mem_write_m   (dut.mem_write_m),
        .alu_result_m  (dut.alu_result_m),
        .write_data_m  (dut.write_data_m),
        .funct3_m      (dut.funct3_m),
        .result_src_m  (dut.result_src_m),
        .read_data_m   (dut.read_data_m),

        // CSR
        .csr_we_w      (dut.csr_we_w),
        .csr_addr_w    (dut.csr_addr_w),
        .csr_wd_w      (dut.csr_wd_w)
    );

    // Expose RVFI outputs to interface for UVM monitor
    assign riscv_if_inst.rvfi_valid    = u_rvfi_tracer.rvfi_valid;
    assign riscv_if_inst.rvfi_insn     = u_rvfi_tracer.rvfi_insn;
    assign riscv_if_inst.rvfi_pc       = u_rvfi_tracer.rvfi_pc_rdata;
    assign riscv_if_inst.rvfi_rd_addr  = u_rvfi_tracer.rvfi_rd_addr;
    assign riscv_if_inst.rvfi_rd_wdata = u_rvfi_tracer.rvfi_rd_wdata;
    assign riscv_if_inst.rvfi_mem_wmask_nz = u_rvfi_tracer.rvfi_mem_wmask_nz;
    assign riscv_if_inst.rvfi_mem_addr  = u_rvfi_tracer.rvfi_mem_addr;
    assign riscv_if_inst.rvfi_mem_wdata = u_rvfi_tracer.rvfi_mem_wdata;
    assign riscv_if_inst.rvfi_mem_rdata = u_rvfi_tracer.rvfi_mem_rdata;

    // --------------------------------------------------------
    // Start UVM test
    // --------------------------------------------------------
    initial begin
        run_test(); // UVM_TESTNAME plusarg selects which test
    end

    initial begin
        // Dump waveforms for post-simulation analysis (Optional)
        $wlfdumpvars(0, tb_top);
        $dumpfile("dump_uvm.vcd");
        $dumpvars(0, tb_top);
    end

endmodule : tb_top