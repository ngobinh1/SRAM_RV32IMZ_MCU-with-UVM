module issue (
    input wire clk, rst, clr,
    
    // Status from execution units & pipeline
    input wire execute_ready,      // Execute is ready to take new instructions
    input wire [4:0] rd_e,
    input wire [2:0] result_src_e, // result_src_e[0] == 1 means Load
    
    // Inputs from Decode
    input wire decode_valid,       // Decode has a valid instruction
    input wire reg_write_d, mem_write_d, alu_src_d, jump_d, branch_d, jalr_d,
    input wire [2:0] funct3_d, result_src_d,
    input wire [3:0] alu_control_d,
    input wire [31:0] read_data_1_d, read_data_2_d, pc_d, pc_plus_4_d, imm_ext_d,
    input wire [4:0] rs1_d, rs2_d, rd_d,
    input wire csr_we_d,
    input wire [11:0] csr_addr_d,
    input wire [31:0] csr_rd_d,
    input wire is_ecall_d, is_mret_d, is_sret_d, md_req_d, is_illegal_d,
    input wire [2:0] md_op_d,
    input wire predict_taken_d,
    input wire [31:0] predict_target_d,
    input wire [4:0] exc_tag_d,
    input wire [31:0] badaddr_d,
    
    // Stall to Decode/Fetch
    output wire issue_stall,
    
    // Outputs to Execute (pipeline_2_3)
    output wire issue_valid,
    output wire reg_write_i, mem_write_i, alu_src_i, jump_i, branch_i, jalr_i,
    output wire [2:0] funct3_i, result_src_i,
    output wire [3:0] alu_control_i,
    output wire [31:0] read_data_1_i, read_data_2_i, pc_i, pc_plus_4_i, imm_ext_i,
    output wire [4:0] rs1_i, rs2_i, rd_i,
    output wire csr_we_i,
    output wire [11:0] csr_addr_i,
    output wire [31:0] csr_rd_i,
    output wire is_ecall_i, is_mret_i, is_sret_i, md_req_i, is_illegal_i,
    output wire [2:0] md_op_i,
    output wire predict_taken_i,
    output wire [31:0] predict_target_i,
    output wire [4:0] exc_tag_i,
    output wire [31:0] badaddr_i
);

    // Load-Use Hazard check on the instruction ready to issue
    wire load_use_hazard = result_src_e[0] && (rd_e != 0) && ((rs1_d == rd_e) || (rs2_d == rd_e));
    
    // We can dispatch if Execute is ready and no load-use hazard
    wire can_dispatch = execute_ready && !load_use_hazard;
    
    // Output valid signal to Execute
    assign issue_valid = decode_valid && can_dispatch && !clr;
    
    // Stall Decode if we cannot dispatch it. 
    // We remove decode_valid from this condition to prevent a combinational loop 
    // with stall_d -> decode_valid -> issue_stall -> stall_d.
    // Invalid instructions (NOPs) won't trigger load-use hazards anyway because their rs1/rs2 are 0.
    assign issue_stall = !can_dispatch;
    
    assign reg_write_i   = reg_write_d;
    assign mem_write_i   = mem_write_d;
    assign alu_src_i     = alu_src_d;
    assign jump_i        = jump_d;
    assign branch_i      = branch_d;
    assign jalr_i        = jalr_d;
    assign funct3_i      = funct3_d;
    assign result_src_i  = result_src_d;
    assign alu_control_i = alu_control_d;
    assign read_data_1_i = read_data_1_d;
    assign read_data_2_i = read_data_2_d;
    assign pc_i          = pc_d;
    assign pc_plus_4_i   = pc_plus_4_d;
    assign imm_ext_i     = imm_ext_d;
    assign rs1_i         = rs1_d;
    assign rs2_i         = rs2_d;
    assign rd_i          = rd_d;
    assign csr_we_i      = csr_we_d;
    assign csr_addr_i    = csr_addr_d;
    assign csr_rd_i      = csr_rd_d;
    assign is_ecall_i    = is_ecall_d;
    assign is_mret_i     = is_mret_d;
    assign is_sret_i     = is_sret_d;
    assign md_req_i      = md_req_d;
    assign is_illegal_i  = is_illegal_d;
    assign md_op_i       = md_op_d;
    assign predict_taken_i = predict_taken_d;
    assign predict_target_i = predict_target_d;
    assign exc_tag_i     = exc_tag_d;
    assign badaddr_i     = badaddr_d;

endmodule
