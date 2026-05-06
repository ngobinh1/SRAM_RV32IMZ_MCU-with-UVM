`timescale 1ns / 1ps

module tb_execute_cycle();
    // Signal declarations
    reg [1:0] forward_a_e, forward_b_e;
    reg jump_e, branch_e, alu_src_e, jalr_e;
    reg [2:0] funct3_e;
    reg [3:0] alu_control_e;
    reg [31:0] alu_result_m, read_data_1_e, read_data_2_e, imm_ext_e, pc_e, pc_plus_4_e, result_w;
    reg [4:0] rd_e;
    
    wire [31:0] pc_target_e, alu_result_e, write_data_e;
    wire pc_src_e;

    // Instantiate the module
    execute_cycle uut (
        .forward_a_e(forward_a_e), .forward_b_e(forward_b_e),
        .jump_e(jump_e), .branch_e(branch_e), .alu_src_e(alu_src_e), .jalr_e(jalr_e),
        .funct3_e(funct3_e), .alu_control_e(alu_control_e),
        .alu_result_m(alu_result_m), .read_data_1_e(read_data_1_e), .read_data_2_e(read_data_2_e),
        .imm_ext_e(imm_ext_e), .pc_e(pc_e), .pc_plus_4_e(pc_plus_4_e), .result_w(result_w),
        .rd_e(rd_e),
        .pc_target_e(pc_target_e), .alu_result_e(alu_result_e), .write_data_e(write_data_e),
        .pc_src_e(pc_src_e)
    );

    // Task for Branch Testing
    task test_branch;
        input [2:0] funct3;
        input [31:0] val_rs1, val_rs2;
        input [3:0] sub_ctrl; // SUB instruction code for ALU
        begin
            read_data_1_e = val_rs1;
            read_data_2_e = val_rs2;
            funct3_e = funct3;
            alu_control_e = sub_ctrl; // Branch uses subtraction to set flags
            branch_e = 1; alu_src_e = 0; jump_e = 0; jalr_e = 0;
            forward_a_e = 0; forward_b_e = 0;
            #10;
        end
    endtask

    initial begin
        // Initialization
        forward_a_e = 0; forward_b_e = 0; jump_e = 0; branch_e = 0; alu_src_e = 0; jalr_e = 0;
        funct3_e = 0; alu_control_e = 0;
        alu_result_m = 32'h0; read_data_1_e = 32'h0; read_data_2_e = 32'h0;
        imm_ext_e = 32'h0; pc_e = 32'h100; pc_plus_4_e = 32'h104; result_w = 32'h0; rd_e = 5'd1;
        
        $display("=== START EXECUTE STAGE TEST ===");

        // CASE 1: Test Forwarding (Data Hazards)
        $display("- Testing Forwarding from MEM and WB stages");
        read_data_1_e = 32'd10;  alu_result_m = 32'd50;  result_w = 32'd100;
        alu_control_e = 4'b0000; // Assuming 0000 is ADD
        alu_src_e = 0;
        
        forward_a_e = 2'b10; // Forward from MEM to input A (expecting A = 50)
        forward_b_e = 2'b01; // Forward from WB to input B (expecting B = 100)
        #10; // Expected ALU result: 150
        
        // CASE 2: Test I-Type ALU Src (Register vs Immediate)
        $display("- Testing Immediate input (alu_src_e = 1)");
        forward_a_e = 2'b00; forward_b_e = 2'b00;
        imm_ext_e = 32'd25;
        alu_src_e = 1; // Use imm_ext_e as ALU input B
        #10; // Expected ALU result: 10 + 25 = 35

        // CASE 3: Branch conditions
        $display("- Testing Branch Conditions");
        imm_ext_e = 32'd8; // Branch target will be PC + 8
        // Assuming alu_control for subtract (to set zero, neg flags) is 4'b0001
        
        test_branch(3'b000, 32'd15, 32'd15, 4'b0001); // BEQ (15 == 15) -> pc_src_e = 1
        test_branch(3'b001, 32'd15, 32'd20, 4'b0001); // BNE (15 != 20) -> pc_src_e = 1
        test_branch(3'b100, -32'd5, 32'd2,  4'b0001); // BLT (-5 < 2)   -> pc_src_e = 1

        // CASE 4: JALR
        $display("- Testing JALR");
        branch_e = 0; jump_e = 1; jalr_e = 1;
        read_data_1_e = 32'h0000_4000;
        imm_ext_e = 32'h0000_0004;
        alu_src_e = 1;
        // JALR clears LSB: (4000 + 4) & ~1
        #10; 

        $stop;
    end
endmodule