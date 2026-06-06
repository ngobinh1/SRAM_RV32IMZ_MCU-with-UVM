module execute_cycle(
    input wire [1:0] forward_a_e, forward_b_e, 
    input wire jump_e, branch_e, alu_src_e, jalr_e,
    input wire [2:0] funct3_e,
    input wire [3:0] alu_control_e,
    input wire [31:0] alu_result_m, read_data_1_e, read_data_2_e, imm_ext_e, pc_e, pc_plus_4_e, result_w,
    input wire [4:0] rd_e, 
    input wire predict_taken_e,
    input wire [31:0] predict_target_e,
    output  [31:0] pc_target_e, alu_result_e, write_data_e, 
    output  pc_src_e,
    output wire [31:0] src_a_out,
    output wire [31:0] src_b_reg_out,
    output wire actual_taken_e,
    output wire [31:0] actual_target_e,
    output wire update_valid_e
);
    wire [31:0] src_a_e, src_b_e, src_b_interim_e;
    wire [31:0] alu_input_a;
    wire zero_e;
    wire overflow_e, carry_e, neg_e;
    wire branch_taken_e;
    wire [31:0] branch_adder_result;

    // Forwarding MUX for source A
    mux_3_1 src_a_emux (
        .a(read_data_1_e),
        .b(result_w),
        .c(alu_result_m),
        .s(forward_a_e),
        .d(src_a_e)
    );

    // Forwarding MUX for source B (before alu_src mux)
    mux_3_1 src_b_interim_e_mux (
        .a(read_data_2_e),
        .b(result_w),
        .c(alu_result_m),
        .s(forward_b_e),
        .d(src_b_interim_e)
    );

    // ALU source MUX (register or immediate)
    mux alu_src_mux (
        .a(src_b_interim_e),
        .b(imm_ext_e),
        .s(alu_src_e),
        .c(src_b_e)
    );

    // For AUIPC, we need to use PC instead of register value
    // AUIPC is identified by alu_control = 1000
    assign alu_input_a = (alu_control_e == 4'b1000) ? pc_e : src_a_e;

    // ALU
    alu alu_unit (
        .a(alu_input_a),
        .b(src_b_e),
        .alu_control(alu_control_e),
        .result(alu_result_e),
        .overflow(overflow_e),
        .carry(carry_e),
        .zero(zero_e),
        .neg(neg_e)
    );

    // Dedicated Branch Comparator (Decoupled from main ALU)
    wire [31:0] cmp_a = src_a_e;
    wire [31:0] cmp_b = src_b_interim_e;
    wire cmp_eq = (cmp_a == cmp_b);
    wire cmp_lt = ($signed(cmp_a) < $signed(cmp_b));
    wire cmp_ltu = (cmp_a < cmp_b);

    // Branch Condition Evaluation based on funct3
    assign branch_taken_e = 
        (funct3_e == 3'b000) ? cmp_eq :                  // BEQ
        (funct3_e == 3'b001) ? !cmp_eq :                 // BNE
        (funct3_e == 3'b100) ? cmp_lt :                  // BLT
        (funct3_e == 3'b101) ? !cmp_lt :                 // BGE
        (funct3_e == 3'b110) ? cmp_ltu :                 // BLTU
        (funct3_e == 3'b111) ? !cmp_ltu :                // BGEU
        1'b0;
    
    // Dedicated Branch Adder
    wire [31:0] branch_adder_a = jalr_e ? src_a_e : pc_e;
    
    adder branch_adder (
        .a(branch_adder_a),
        .b(imm_ext_e),
        .c(branch_adder_result)
    );

    // MUX for branch/jump target (for BTB update)
    assign actual_target_e = jalr_e ? (branch_adder_result & 32'hFFFFFFFE) : branch_adder_result;
    
    // Actual taken status
    assign actual_taken_e = (branch_taken_e & branch_e) | jump_e | jalr_e;
    
    // Predictor update valid
    assign update_valid_e = branch_e | jump_e | jalr_e;

    // Misprediction detection
    wire mispredict_e = (predict_taken_e != actual_taken_e) || 
                        (predict_taken_e && actual_taken_e && (predict_target_e != actual_target_e));

    // Redirect PC on misprediction
    assign pc_target_e = actual_taken_e ? actual_target_e : pc_plus_4_e;
    
    // PC source control (1 = redirect fetch)
    assign pc_src_e = mispredict_e;
    
    // Write data for store instructions (use forwarded value)
    assign write_data_e = src_b_interim_e;
    assign src_a_out       = src_a_e;
    assign src_b_reg_out   = src_b_interim_e;

endmodule