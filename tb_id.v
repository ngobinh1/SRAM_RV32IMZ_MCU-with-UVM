`timescale 1ns / 1ps

module tb_decode_cycle();
    // Signal declarations
    reg clk, rst, reg_write_w;
    reg [4:0] rd_w;
    reg [31:0] instr_d, result_w, pc_in, pc_plus_4_in;
    
    wire [31:0] imm_ext_d, read_data_1_d, read_data_2_d;
    wire [4:0] rs1_d, rs2_d, rd_d;
    wire reg_write_d, mem_write_d, jump_d, branch_d, alu_src_d, jalr_d;
    wire [2:0] funct3_d, result_src_d;
    wire [3:0] alu_control_d;
    wire csr_we_d, is_ecall_d, is_mret_d;

    // Instantiate the module
    decode_cycle uut (
        .clk(clk), .rst(rst), .reg_write_w(reg_write_w),
        .rd_w(rd_w), .instr_d(instr_d), .result_w(result_w), 
        .pc_in(pc_in), .pc_plus_4_in(pc_plus_4_in),
        .imm_ext_d(imm_ext_d), .read_data_1_d(read_data_1_d), .read_data_2_d(read_data_2_d),
        .rs1_d(rs1_d), .rs2_d(rs2_d), .rd_d(rd_d),
        .reg_write_d(reg_write_d), .mem_write_d(mem_write_d), 
        .jump_d(jump_d), .branch_d(branch_d), .alu_src_d(alu_src_d), .jalr_d(jalr_d),
        .funct3_d(funct3_d), .result_src_d(result_src_d),
        .alu_control_d(alu_control_d),
        .csr_we_d(csr_we_d), .is_ecall_d(is_ecall_d), .is_mret_d(is_mret_d)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Task to decode an instruction and wait
    task decode_instruction;
        input [31:0] test_instr;
        input [255:0] msg; // String message
        begin
            $display("- Testing Instruction: %s (0x%h)", msg, test_instr);
            instr_d = test_instr;
            #10;
        end
    endtask

    initial begin
        // Initialization
        clk = 0; rst = 0; 
        reg_write_w = 0; rd_w = 0; result_w = 0;
        instr_d = 32'h0; pc_in = 32'h0; pc_plus_4_in = 32'h4;
        
        $display("=== START DECODE STAGE TEST ===");
        #10 rst = 1;

        // CASE 1: Write to Register File (Simulate Writeback stage input)
        $display("- Testing Register File Write");
        reg_write_w = 1;
        rd_w = 5'd10;          // Write to x10
        result_w = 32'hAAAA_BBBB;
        #10;
        reg_write_w = 0;

        // CASE 2: Test R-Type (e.g., ADD x11, x10, x10) -> rs1=10, rs2=10
        // Expected: read_data_1_d and read_data_2_d should be 0xAAAABBBB
        decode_instruction(32'h00a505b3, "ADD x11, x10, x10");

        // CASE 3: Test I-Type (e.g., ADDI x12, x0, 100) -> imm=100
        // Expected: alu_src_d = 1, imm_ext_d = 100
        decode_instruction(32'h06400613, "ADDI x12, x0, 100");

        // CASE 4: Test S-Type (e.g., SW x10, 4(x12))
        // Expected: mem_write_d = 1, imm_ext_d = 4
        decode_instruction(32'h00a62223, "SW x10, 4(x12)");

        // CASE 5: Test B-Type (e.g., BEQ x10, x11, offset)
        // Expected: branch_d = 1
        decode_instruction(32'h00b50463, "BEQ x10, x11, offset");

        // CASE 6: Test Exception (ECALL)
        decode_instruction(32'h00000073, "ECALL");

        #20 $stop;
    end
endmodule