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
    input wire is_ecall_d, is_mret_d, md_req_d, is_illegal_d,
    input wire [2:0] md_op_d,
    
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
    output wire is_ecall_i, is_mret_i, md_req_i, is_illegal_i,
    output wire [2:0] md_op_i
);

    localparam PW = 242;

    wire [PW-1:0] push_data = {
        reg_write_d, mem_write_d, alu_src_d, jump_d, branch_d, jalr_d,
        funct3_d, result_src_d, alu_control_d,
        read_data_1_d, read_data_2_d, pc_d, pc_plus_4_d, imm_ext_d,
        rs1_d, rs2_d, rd_d,
        csr_we_d, csr_addr_d, csr_rd_d,
        is_ecall_d, is_mret_d, md_req_d, is_illegal_d, md_op_d
    };

    reg [PW-1:0] queue [1:0];
    reg [1:0] valid_q;
    
    wire [PW-1:0] head_data = (valid_q == 2'b00) ? push_data : queue[0];
    wire head_valid = (valid_q != 2'b00) || decode_valid;
    
    // Extract rs1 and rs2 from head_data
    // md_op(3) + is_illegal(1) + md_req(1) + is_mret(1) + is_ecall(1) = 7 bits
    // csr_rd(32)[38:7], csr_addr(12)[50:39], csr_we(1)[51]
    // rd(5)[56:52], rs2(5)[61:57], rs1(5)[66:62]
    wire [4:0] head_rs1 = head_data[66:62];
    wire [4:0] head_rs2 = head_data[61:57];
    
    // Load-Use Hazard check on the instruction ready to issue
    wire load_use_hazard = result_src_e[0] && (rd_e != 0) && ((head_rs1 == rd_e) || (head_rs2 == rd_e));
    
    // We can dispatch if Execute is ready and no load-use hazard
    wire can_dispatch = execute_ready && !load_use_hazard;
    wire pop_en = head_valid && can_dispatch && !clr;
    
    wire issue_full = (valid_q == 2'b11);
    
    // Push when decode is valid and we aren't clearing
    wire push_en = decode_valid && !clr && !(issue_full && !pop_en); 
    
    // Only stall Decode if the queue is full and we cannot pop an instruction.
    // This breaks the combinational loop between issue_stall and decode_valid.
    assign issue_stall = issue_full && !pop_en;
    
    assign issue_valid = pop_en;

    assign {
        reg_write_i, mem_write_i, alu_src_i, jump_i, branch_i, jalr_i,
        funct3_i, result_src_i, alu_control_i,
        read_data_1_i, read_data_2_i, pc_i, pc_plus_4_i, imm_ext_i,
        rs1_i, rs2_i, rd_i,
        csr_we_i, csr_addr_i, csr_rd_i,
        is_ecall_i, is_mret_i, md_req_i, is_illegal_i, md_op_i
    } = head_data;

    always @(posedge clk) begin
        if (!rst || clr) begin
            valid_q <= 2'b00;
        end else begin
            case ({push_en, pop_en})
                2'b10: begin
                    if (valid_q == 2'b00) begin
                        queue[0] <= push_data;
                        valid_q <= 2'b01;
                    end else if (valid_q == 2'b01) begin
                        queue[1] <= push_data;
                        valid_q <= 2'b11;
                    end
                end
                2'b01: begin
                    if (valid_q == 2'b11) begin
                        queue[0] <= queue[1];
                        valid_q <= 2'b01;
                    end else if (valid_q == 2'b01) begin
                        valid_q <= 2'b00;
                    end
                end
                2'b11: begin
                    if (valid_q == 2'b00) begin
                        // Bypass
                    end else if (valid_q == 2'b01) begin
                        queue[0] <= push_data;
                    end else if (valid_q == 2'b11) begin
                        queue[0] <= queue[1];
                        queue[1] <= push_data;
                    end
                end
                default: ; 
            endcase
        end
    end
endmodule
