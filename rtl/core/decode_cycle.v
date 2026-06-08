module decode_cycle (
    input wire clk, rst, reg_write_w,
    input wire [4:0] rd_w,
    input wire [31:0] instr_d, result_w, pc_in, pc_plus_4_in,
    input wire [4:0] exc_tag_in_d,
    input wire [1:0] current_prv,
    output wire [4:0] exc_tag_out_d,
    output  [31:0] imm_ext_d, read_data_1_d, read_data_2_d,
    output  [4:0] rs1_d, rs2_d, rd_d,
    output  reg_write_d, mem_write_d, jump_d, branch_d, alu_src_d, jalr_d,
    output  [2:0] funct3_d,
    output  [2:0] result_src_d,
    output  [3:0] alu_control_d,
    output  csr_we_d, is_ecall_d, is_mret_d, is_sret_d,
    output wire       md_req_d,
    output wire [2:0] md_op_d,
    output wire       is_illegal_d
);

    wire [2:0] imm_src_d;
    wire [11:0] imm12;

    assign funct3_d = instr_d[14:12];
    assign md_op_d = instr_d[14:12];

    wire reg_write_raw, mem_write_raw, jump_raw, branch_raw, alu_src_raw, jalr_raw;
    wire csr_we_raw, is_ecall_raw, is_mret_raw, is_sret_raw, md_req_raw, is_illegal_raw;
    
    control_unit control_unit(
        .op(instr_d[6:0]),
        .funct3(instr_d[14:12]),
        .funct7(instr_d[31:25]),
        .imm12(instr_d[31:20]),
        .reg_write(reg_write_raw),
        .result_src(result_src_d),
        .mem_write(mem_write_raw),
        .jump(jump_raw),
        .branch(branch_raw),
        .jalr(jalr_raw),
        .alu_control(alu_control_d),
        .alu_src(alu_src_raw),
        .imm_src(imm_src_d),
        .csr_we(csr_we_raw),
        .is_ecall(is_ecall_raw),
        .is_mret(is_mret_raw),
        .is_sret(is_sret_raw),
        .md_req(md_req_raw),
        .is_illegal(is_illegal_raw)
    );

    assign reg_write_d  = exc_tag_in_d[4] ? 1'b0 : reg_write_raw;
    assign mem_write_d  = exc_tag_in_d[4] ? 1'b0 : mem_write_raw;
    assign jump_d       = exc_tag_in_d[4] ? 1'b0 : jump_raw;
    assign branch_d     = exc_tag_in_d[4] ? 1'b0 : branch_raw;
    assign jalr_d       = exc_tag_in_d[4] ? 1'b0 : jalr_raw;
    assign alu_src_d    = exc_tag_in_d[4] ? 1'b0 : alu_src_raw;
    assign csr_we_d     = exc_tag_in_d[4] ? 1'b0 : csr_we_raw;
    assign md_req_d     = exc_tag_in_d[4] ? 1'b0 : md_req_raw;
    assign is_ecall_d   = exc_tag_in_d[4] ? 1'b0 : is_ecall_raw;
    assign is_mret_d    = exc_tag_in_d[4] ? 1'b0 : is_mret_raw;
    assign is_sret_d    = exc_tag_in_d[4] ? 1'b0 : is_sret_raw;
    assign is_illegal_d = exc_tag_in_d[4] ? 1'b0 : is_illegal_raw;

    // Extract register addresses
    assign rs1_d = instr_d[19:15];
    assign rs2_d = instr_d[24:20];
    assign rd_d = instr_d[11:7];

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

    reg [4:0] exc_tag_out_reg;
    always @(*) begin
        if (exc_tag_in_d != 5'd0) begin
            exc_tag_out_reg = exc_tag_in_d;
        end else if (is_illegal_d) begin
            exc_tag_out_reg = 5'd18;
        end else if (is_ecall_d) begin
            if (current_prv == 2'b11)      exc_tag_out_reg = 5'd27;
            else if (current_prv == 2'b01) exc_tag_out_reg = 5'd25;
            else                           exc_tag_out_reg = 5'd24;
        end else if (is_mret_d) begin
            exc_tag_out_reg = 5'd1;
        end else if (is_sret_d) begin
            exc_tag_out_reg = 5'd2;
        end else begin
            exc_tag_out_reg = 5'd0;
        end
    end
    assign exc_tag_out_d = exc_tag_out_reg;

endmodule