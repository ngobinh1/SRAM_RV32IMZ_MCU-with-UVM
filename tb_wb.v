`timescale 1ns / 1ps

module tb_writeback_cycle();
    // Signal declarations
    reg [2:0] result_src_w;
    reg [31:0] alu_result_w, read_data_w, pc_plus_4_w, csr_rd_w;
    wire [31:0] result_w;

    // Instantiate the module
    writeback_cycle uut (
        .result_src_w(result_src_w),
        .alu_result_w(alu_result_w),
        .read_data_w(read_data_w),
        .pc_plus_4_w(pc_plus_4_w),
        .csr_rd_w(csr_rd_w),
        .result_w(result_w)
    );

    initial begin
        $display("=== START WRITEBACK STAGE TEST ===");
        
        // Initialize distinct dummy values for each source
        alu_result_w = 32'hAAAA_AAAA;
        read_data_w  = 32'hBBBB_BBBB;
        pc_plus_4_w  = 32'hCCCC_CCCC;
        csr_rd_w     = 32'hDDDD_DDDD;

        // CASE 1: result_src = 00 (ALU Result)
        $display("- Testing ALU Result Source (00)");
        result_src_w = 3'b000;
        #5;
        if (result_w !== alu_result_w) $display("  [ERROR] MUX failed for ALU Result");

        // CASE 2: result_src = 01 (Memory Read Data)
        $display("- Testing Memory Data Source (01)");
        result_src_w = 3'b001;
        #5;
        if (result_w !== read_data_w) $display("  [ERROR] MUX failed for Memory Data");

        // CASE 3: result_src = 10 (PC + 4 for JAL/JALR)
        $display("- Testing PC+4 Source (10)");
        result_src_w = 3'b010;
        #5;
        if (result_w !== pc_plus_4_w) $display("  [ERROR] MUX failed for PC+4");

        // CASE 4: result_src = 11 (CSR Read Data)
        $display("- Testing CSR Data Source (11)");
        result_src_w = 3'b011;
        #5;
        if (result_w !== csr_rd_w) $display("  [ERROR] MUX failed for CSR Data");

        $display("=== WRITEBACK TEST COMPLETE ===");
        $stop;
    end
endmodule