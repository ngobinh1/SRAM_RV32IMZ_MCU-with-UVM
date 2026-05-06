`timescale 1ns / 1ps

module tb_fetch_cycle();
    // Signal declarations
    reg clk, rst, en;
    reg pc_src_e;
    reg [31:0] pc_target_e;
    reg is_ecall, is_mret;
    reg [31:0] trap_vec, epc;

    wire [31:0] instr_f, pc_f, pc_plus_4_f;

    // Instantiate the module
    fetch_cycle uut (
        .clk(clk), .rst(rst), .en(en),
        .pc_src_e(pc_src_e), .pc_target_e(pc_target_e),
        .is_ecall(is_ecall), .is_mret(is_mret),
        .trap_vec(trap_vec), .epc(epc),
        .instr_f(instr_f), .pc_f(pc_f), .pc_plus_4_f(pc_plus_4_f)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize state
        clk = 0; rst = 0; en = 1; 
        pc_src_e = 0; pc_target_e = 32'h0;
        is_ecall = 0; is_mret = 0;
        trap_vec = 32'h0000_1000; epc = 32'h0000_2000;

        $display("=== START FETCH STAGE TEST ===");
        #10 rst = 1; // De-assert reset

        // CASE 1: Normal PC increment
        #20; 
        
        // CASE 2: Check Stall (Hazard activated)
        $display("- Testing Stall (en = 0)");
        en = 0; 
        #20; // PC should not change
        en = 1;

        // CASE 3: Branch or Jump instruction executed in Execute stage
        $display("- Testing Branch/Jump taken");
        pc_target_e = 32'h0000_00A4; 
        pc_src_e = 1;
        #10;
        pc_src_e = 0;

        // CASE 4: Exception handling (ecall)
        $display("- Testing ecall exception");
        is_ecall = 1;
        #10; // PC must jump to trap_vec
        is_ecall = 0;

        // CASE 5: Return handling (mret)
        $display("- Testing mret");
        is_mret = 1;
        #10; // PC must jump to epc
        is_mret = 0;

        #20 $stop;
    end
endmodule