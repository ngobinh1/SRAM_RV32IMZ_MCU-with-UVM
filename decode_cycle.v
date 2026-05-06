module decode_cycle (
    input wire clk, rst, reg_write_w,
    input wire [4:0] rd_w,
    input wire [31:0] instr_d, result_w, pc_in, pc_plus_4_in,
    output  [31:0] imm_ext_d, read_data_1_d, read_data_2_d,
    output  [4:0] rs1_d, rs2_d, rd_d,
    output  reg_write_d, mem_write_d, jump_d, branch_d, alu_src_d, jalr_d,
    output  [2:0] funct3_d,
    output  [2:0] result_src_d,
    output  [3:0] alu_control_d,
    output  csr_we_d, is_ecall_d, is_mret_d
);

    wire [2:0] imm_src_d;
    wire [11:0] imm12;

    assign funct3_d = instr_d[14:12];

    
    control_unit control_unit(
        .op(instr_d[6:0]),
        .funct3(instr_d[14:12]),
        .funct7(instr_d[31:25]),
        .imm12(instr_d[31:20]),
        .reg_write(reg_write_d),
        .result_src(result_src_d),
        .mem_write(mem_write_d),
        .jump(jump_d),
        .branch(branch_d),
        .jalr(jalr_d),
        .alu_control(alu_control_d),
        .alu_src(alu_src_d),
        .imm_src(imm_src_d),
        .csr_we(csr_we_d),
        .is_ecall(is_ecall_d),
        .is_mret(is_mret_d)
    );

    // Extract register addresses
    assign rs1_d = instr_d[19:15];
    assign rs2_d = instr_d[24:20];
    assign rd_d = instr_d[11:7];
    
    // // DEBUG: Print when specific instructions are decoded
    // always @(*) begin
    //     if (instr_d == 32'h00216533) begin
    //         $display("DEBUG decode_cycle: OR instruction detected!");
    //         $display("  instr_d = 0x%h", instr_d);
    //         $display("  instr_d binary = %b", instr_d);
    //         $display("  instr_d[19:15] = %b = %d", instr_d[19:15], instr_d[19:15]);
    //         $display("  instr_d[24:20] = %b = %d", instr_d[24:20], instr_d[24:20]);
    //         $display("  rs1_d (wire) = %d", rs1_d);
    //         $display("  rs2_d (wire) = %d", rs2_d);
    //         $display("  rd_d (wire) = %d", rd_d);
    //     end
        
    //     if (instr_d == 32'h00112633) begin
    //         $display("DEBUG decode_cycle: SLT x13 instruction detected!");
    //         $display("  instr_d = 0x%h", instr_d);
    //         $display("  instr_d[11:7] = %b = %d", instr_d[11:7], instr_d[11:7]);
    //         $display("  rd_d (wire) = %d", rd_d);
    //     end
    // end

    register_file register_file(
        .clk(clk),
        .rst(rst),
        .write_en_3(reg_write_w),
        .addr_1(rs1_d),
        .addr_2(rs2_d),
        .addr_3(rd_w),
        .write_data_3(result_w),
        .read_data_1(read_data_1_d),
        .read_data_2(read_data_2_d)
    );

    extend enxtend (
        .instr(instr_d[31:0]),
        .imm_src(imm_src_d),
        .imm_ext(imm_ext_d)
    );

endmodule