`timescale 1ns / 1ps

module tb_memory_cycle();
    // Signal declarations
    reg clk, rst, mem_write_m;
    reg [31:0] alu_result_m, write_data_m;
    reg [2:0] funct3_m;
    wire [31:0] read_data_m;

    // Instantiate the module
    memory_cycle uut (
        .clk(clk), .rst(rst),
        .mem_write_m(mem_write_m),
        .alu_result_m(alu_result_m),
        .write_data_m(write_data_m),
        .funct3_m(funct3_m),
        .read_data_m(read_data_m)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialization
        clk = 0; rst = 0; mem_write_m = 0;
        alu_result_m = 0; write_data_m = 0; funct3_m = 0;
        
        $display("=== START MEMORY STAGE TEST ===");
        #10 rst = 1;

        // CASE 1: Write Word (SW)
        $display("- Testing Store Word (SW)");
        mem_write_m = 1;
        funct3_m = 3'b010; // Word
        alu_result_m = 32'h0000_1000; // Address
        write_data_m = 32'hDEAD_BEEF; // Data
        #10;
        
        // CASE 2: Read Word (LW) from the same address
        $display("- Testing Load Word (LW)");
        mem_write_m = 0;
        #10; // Allow read delay
        if (read_data_m !== 32'hDEAD_BEEF) 
            $display("  [ERROR] Read Data Mismatch! Expected DEAD_BEEF, got %h", read_data_m);
        else 
            $display("  [PASS] Read Data Match.");

        // CASE 3: Write to a different address
        $display("- Testing Store Word at different address");
        mem_write_m = 1;
        alu_result_m = 32'h0000_1004;
        write_data_m = 32'h1234_5678;
        #10;
        mem_write_m = 0;

        #20 $stop;
    end
endmodule