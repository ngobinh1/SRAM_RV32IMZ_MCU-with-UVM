`timescale 1ns/1ps

module tb_riscv_pipeline_full();
    reg clk;
    reg rst;

    // Connect to the Top Module
    riscv_pipeline_top dut (
        .clk(clk),
        .rst(rst)
    );

    // Generate 10ns clock (100MHz)
    always #5 clk = ~clk;

    // Virtual path to the Register File for monitoring
    wire [31:0] reg_x3  = dut.decode_stage.register_file.register_array[3];
    wire [31:0] reg_x7  = dut.decode_stage.register_file.register_array[7];
    wire [31:0] reg_x10 = dut.decode_stage.register_file.register_array[10];
    wire [31:0] reg_x31 = dut.decode_stage.register_file.register_array[31]; // Status flag register

    initial begin
        // 1. Initialize
        clk = 0;
        rst = 0;
        
        // Update the hex file name for the instruction memory (if using a different file name)
        // Note: Ensure the instruction_memory module in your code reads this exact file
        $readmemh("memfile.hex", dut.fetch_stage.instruction_memory.mem);

        // 2. System reset (Hold rst = 0 for a while then release to 1)
        #20 rst = 1;

        $display("\n========================================================");
        $display("   STARTING RISC-V 5-STAGE PIPELINE TESTBENCH");
        $display("========================================================");

        // 3. Wait for the program to execute all instructions (Approx. 200 clock cycles)
        // When PC reaches address 0x4C (Infinite loop), the system has finished.
        // wait(dut.pc_f == 32'h0000004C);
        #1000;
        
        // Wait a few more cycles for the final instructions to pass through the WriteBack stage
        #150;

        $display("\n--- INTERMEDIATE TEST RESULTS ---");
        $display("ALU Add (x3)     : %0d \t(Expected: 30)", reg_x3);
        $display("ALU Shift (x7)   : %0d \t(Expected: 40)", reg_x7);
        $display("Memory Load (x10): %0d \t(Expected: 30)", reg_x10);
        
        $display("\n--- CONTROL FLOW RESULTS ---");
        if (reg_x31 === 32'd1) begin
            $display(">> [PASS] Branching logic (BEQ, JAL, and JALR) works CORRECTLY!");
        end else if (reg_x31 === 32'hFFFFFFFF) begin
            $display(">> [FAIL] Branching logic ERROR! Program entered the restricted zone.");
        end else begin
            $display(">> [FAIL] Unknown error. Register x31 = %0d", reg_x31);
        end

        $display("========================================================\n");
        $finish;
    end

    // Log to monitor the pipeline (Optional)
    /*
    initial begin
        $monitor("Time: %4t | PC_F: %h | x31: %0d", $time, dut.pc_f, reg_x31);
    end
    */
endmodule