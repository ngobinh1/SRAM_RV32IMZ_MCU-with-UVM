// pipeline for fetch and decode
module if_id_reg (
    input wire clk, rst, flush, stall,
    input wire valid_in, 
    input wire [4:0] exc_tag_in, 
    input wire irq_tag_in,
    input wire [31:0] badaddr_in,
    input wire [31:0] instr_f, pc_f, pc_plus_4_f,
    input wire predict_taken_f,
    input wire [31:0] predict_target_f,
    output [31:0] instr_d, pc_d, pc_plus_4_d,
    output predict_taken_d,
    output [31:0] predict_target_d
,
    output valid_out,
    output [4:0] exc_tag_out,
    output irq_tag_out,
    output [31:0] badaddr_out
);
    reg [31:0] instr_reg, pc_reg, pc_plus_4_reg, predict_target_reg;
    reg predict_taken_reg;

        reg valid_reg;
    reg [4:0] exc_tag_reg;
    reg irq_tag_reg;
    reg [31:0] badaddr_reg;

// Initialize registers to prevent 'x' values
    initial begin
        instr_reg = 32'h00000000;
        pc_reg = 32'h00000000;
        pc_plus_4_reg = 32'h00000000;
        predict_taken_reg = 1'b0;
        predict_target_reg = 32'h00000000;
            valid_reg = 1'b0;
        exc_tag_reg = 5'b0;
        irq_tag_reg = 1'b0;
        badaddr_reg = 32'h00000000;
end

    always @(posedge clk ) begin
        if((rst == 1'b0)||(flush == 1'b1)) begin
            instr_reg <= 32'h00000000;
            pc_reg <= 32'h00000000;
            pc_plus_4_reg <= 32'h00000000;
            predict_taken_reg <= 1'b0;
            predict_target_reg <= 32'h00000000;
                    valid_reg <= 1'b0;
            exc_tag_reg <= 5'b0;
            irq_tag_reg <= 1'b0;
            badaddr_reg <= 32'h00000000;
end
        else begin
            if(!stall) begin
                instr_reg <= instr_f;
                pc_reg <= pc_f;
                pc_plus_4_reg <= pc_plus_4_f;
                predict_taken_reg <= predict_taken_f;
                predict_target_reg <= predict_target_f;
                        valid_reg <= valid_in;
            exc_tag_reg <= exc_tag_in;
            irq_tag_reg <= irq_tag_in;
            badaddr_reg <= badaddr_in;
end
            else begin
                instr_reg <= instr_reg;
                pc_reg <= pc_reg;
                pc_plus_4_reg <= pc_plus_4_reg;
                predict_taken_reg <= predict_taken_reg;
                predict_target_reg <= predict_target_reg;
                badaddr_reg <= badaddr_reg;
            end
        end
    end

    assign instr_d = instr_reg;
    assign pc_d = pc_reg;
    assign pc_plus_4_d = pc_plus_4_reg;
    assign predict_taken_d = predict_taken_reg;
    assign predict_target_d = predict_target_reg;

    assign valid_out = valid_reg;
    assign exc_tag_out = exc_tag_reg;
    assign irq_tag_out = irq_tag_reg;
    assign badaddr_out = badaddr_reg;

endmodule 

//pipeline for decode and execute
module id_ex_reg (
    input wire clk, rst, flush, stall,
    input wire valid_in, 
    input wire [4:0] exc_tag_in, 
    input wire irq_tag_in,
    input wire [31:0] badaddr_in,
    input wire reg_write_d, mem_write_d, alu_src_d, jump_d, branch_d, jalr_d, 
    input wire [2:0] funct3_d,
    input wire [2:0] result_src_d,
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
    output  reg_write_e, mem_write_e, alu_src_e, jump_e, branch_e, jalr_e,
    output  [2:0] funct3_e,
    output  [2:0] result_src_e,
    output  [3:0] alu_control_e,
    output  [31:0] read_data_1_e, read_data_2_e, pc_e, pc_plus_4_e, imm_ext_e,
    output  [4:0] rs1_e, rs2_e, rd_e,
    output  csr_we_e,
    output  [11:0] csr_addr_e,
    output  [31:0] csr_rd_e,
    output  is_ecall_e, is_mret_e, is_sret_e, md_req_e, is_illegal_e,
    output  [2:0] md_op_e,
    output  predict_taken_e,
    output  [31:0] predict_target_e
,
    output valid_out,
    output [4:0] exc_tag_out,
    output irq_tag_out,
    output [31:0] badaddr_out
);  
    reg reg_write_reg, mem_write_reg, alu_src_reg, jump_reg, branch_reg, jalr_reg;
    reg [2:0] result_src_reg;
    reg [2:0] funct3_reg;
    reg [3:0] alu_control_reg;
    reg [31:0] read_data_1_reg, read_data_2_reg, pc_reg, pc_plus_4_reg, imm_ext_reg;
    reg [4:0] rs1_reg, rs2_reg, rd_reg;
    reg csr_we_reg;
    reg [11:0] csr_addr_reg;
    reg [31:0] csr_rd_reg;
    reg is_ecall_reg, is_mret_reg, is_sret_reg, md_req_reg, is_illegal_reg;
    reg [2:0] md_op_reg;
    reg predict_taken_reg;
    reg [31:0] predict_target_reg;
    
        reg valid_reg;
    reg [4:0] exc_tag_reg;
    reg irq_tag_reg;
    reg [31:0] badaddr_reg;

// Initialize all registers to prevent 'x' values
    initial begin
        reg_write_reg = 1'b0;
        mem_write_reg = 1'b0;
        alu_src_reg = 1'b0;
        jump_reg = 1'b0;
        branch_reg = 1'b0;
        result_src_reg = 2'b00;
        jalr_reg = 1'b0;
        funct3_reg = 3'b000;
        alu_control_reg = 4'b0000;
        read_data_1_reg = 32'h00000000;
        read_data_2_reg = 32'h00000000;
        pc_reg = 32'h00000000;
        pc_plus_4_reg = 32'h00000000;
        imm_ext_reg = 32'h00000000;
        rs1_reg = 5'h00;
        rs2_reg = 5'h00;
        rd_reg = 5'h00;
        csr_we_reg = 1'b0;
        csr_addr_reg = 12'h000;
        csr_rd_reg = 32'h00000000;
        is_ecall_reg = 1'b0;
        is_mret_reg = 1'b0;
        is_sret_reg = 1'b0;
        md_req_reg = 1'b0;
        is_illegal_reg = 1'b0;
        md_op_reg = 3'b000;
        predict_taken_reg = 1'b0;
        predict_target_reg = 32'h00000000;
            valid_reg = 1'b0;
        exc_tag_reg = 5'b0;
        irq_tag_reg = 1'b0;
        badaddr_reg = 32'h00000000;
end
    
    always @(posedge clk ) begin
        if((rst == 1'b0)||(flush == 1'b1)) begin
            reg_write_reg <= 1'b0;
            mem_write_reg <= 1'b0;
            alu_src_reg <= 1'b0;
            jump_reg <= 1'b0;
            jalr_reg <= 1'b0;
            branch_reg <= 1'b0;
            funct3_reg <= 3'b000;
            result_src_reg <= 2'b00;
            alu_control_reg <= 4'b0000;
            read_data_1_reg <= 32'h00000000;
            read_data_2_reg <= 32'h00000000;
            pc_reg <= 32'h00000000;
            pc_plus_4_reg <= 32'h00000000;
            imm_ext_reg <= 32'h00000000;
            rs1_reg <= 5'h00;
            rs2_reg <= 5'h00;
            rd_reg <= 5'h00;
            csr_we_reg <= 1'b0;
            csr_addr_reg <= 12'h000;
            csr_rd_reg <= 32'h00000000;
            is_ecall_reg <= 1'b0;
            is_mret_reg <= 1'b0;
            is_sret_reg <= 1'b0;
            md_req_reg <= 1'b0;
            is_illegal_reg <= 1'b0;
            md_op_reg <= 3'b000;
            predict_taken_reg <= 1'b0;
            predict_target_reg <= 32'h00000000;
                    valid_reg <= 1'b0;
            exc_tag_reg <= 5'b0;
            irq_tag_reg <= 1'b0;
            badaddr_reg <= 32'h00000000;
end
        else if(!stall) begin
            reg_write_reg <= reg_write_d;
            mem_write_reg <= mem_write_d;
            alu_src_reg <= alu_src_d;
            jalr_reg <= jalr_d;
            funct3_reg <= funct3_d;
            jump_reg <= jump_d;
            branch_reg <= branch_d;
            result_src_reg <= result_src_d;
            alu_control_reg <= alu_control_d;
            read_data_1_reg <= read_data_1_d;
            read_data_2_reg <= read_data_2_d;
            pc_reg <= pc_d;
            pc_plus_4_reg <= pc_plus_4_d;
            imm_ext_reg <= imm_ext_d;
            rs1_reg <= rs1_d;
            rs2_reg <= rs2_d;
            rd_reg <= rd_d;
            csr_we_reg <= csr_we_d;
            csr_addr_reg <= csr_addr_d;
            csr_rd_reg <= csr_rd_d;
            is_ecall_reg <= is_ecall_d;
            is_mret_reg <= is_mret_d;
            is_sret_reg <= is_sret_d;
            md_req_reg <= md_req_d;
            is_illegal_reg <= is_illegal_d;
            md_op_reg <= md_op_d;
            predict_taken_reg <= predict_taken_d;
            predict_target_reg <= predict_target_d;
                    valid_reg <= valid_in;
            exc_tag_reg <= exc_tag_in;
            irq_tag_reg <= irq_tag_in;
            badaddr_reg <= badaddr_in;
end
    end

    assign reg_write_e = reg_write_reg;
    assign mem_write_e = mem_write_reg;
    assign alu_src_e = alu_src_reg;
    assign jump_e = jump_reg;
    assign jalr_e = jalr_reg;
    assign funct3_e = funct3_reg;
    assign branch_e = branch_reg;
    assign result_src_e = result_src_reg;
    assign alu_control_e = alu_control_reg;
    assign read_data_1_e = read_data_1_reg;
    assign read_data_2_e = read_data_2_reg;
    assign pc_e = pc_reg;
    assign pc_plus_4_e = pc_plus_4_reg;
    assign imm_ext_e = imm_ext_reg;
    assign rs1_e = rs1_reg;
    assign rs2_e = rs2_reg;
    assign rd_e = rd_reg;  
    assign csr_we_e = csr_we_reg;
    assign csr_addr_e = csr_addr_reg;
    assign csr_rd_e = csr_rd_reg;
    assign is_ecall_e = is_ecall_reg;
    assign is_mret_e = is_mret_reg;
    assign is_sret_e = is_sret_reg;
    assign md_req_e = md_req_reg;
    assign is_illegal_e = is_illegal_reg;
    assign md_op_e = md_op_reg;
    assign predict_taken_e = predict_taken_reg;
    assign predict_target_e = predict_target_reg;
    assign valid_out = valid_reg;
    assign exc_tag_out = exc_tag_reg;
    assign irq_tag_out = irq_tag_reg;
    assign badaddr_out = badaddr_reg;

endmodule

//pipeline for execute and memory
module ex_mem_reg (
    input wire clk, rst, flush, stall,
    input wire valid_in, 
    input wire [4:0] exc_tag_in, 
    input wire irq_tag_in,
    input wire [31:0] badaddr_in,
    input wire reg_write_e, mem_write_e,
    input wire [2:0] result_src_e, 
    input wire [31:0] alu_result_e, write_data_e, pc_plus_4_e, src_a_e, imm_ext_e,
    input wire [2:0] funct3_e,
    input wire [4:0] rd_e, 
    input wire csr_we_e,
    input wire [11:0] csr_addr_e,
    input wire [31:0] csr_rd_e, csr_wd_e,
    output  reg_write_m, mem_write_m,
    output  [2:0] result_src_m,
    output  [31:0] alu_result_m, write_data_m, pc_plus_4_m, src_a_m, imm_ext_m,
    output  [4:0] rd_m,
    output  [2:0] funct3_m,
    output  csr_we_m,
    output  [11:0] csr_addr_m,
    output  [31:0] csr_rd_m, csr_wd_m
,
    output valid_out,
    output [4:0] exc_tag_out,
    output irq_tag_out,
    output [31:0] badaddr_out
);

    reg reg_write_reg, mem_write_reg;
    reg [2:0] result_src_reg;
    reg [31:0] alu_result_reg, write_data_reg, pc_plus_4_reg, src_a_reg, imm_ext_reg;
    reg [4:0] rd_reg;
    reg [2:0] funct3_reg;
    reg csr_we_reg;
    reg [11:0] csr_addr_reg;
    reg [31:0] csr_rd_reg, csr_wd_reg;

        reg valid_reg;
    reg [4:0] exc_tag_reg;
    reg irq_tag_reg;
    reg [31:0] badaddr_reg;

// Initialize all registers to prevent 'x' values
    initial begin
        reg_write_reg = 1'b0;
        mem_write_reg = 1'b0;
        result_src_reg = 2'b00;
        funct3_reg = 3'b000;
        alu_result_reg = 32'h00000000;
        write_data_reg = 32'h00000000;
        pc_plus_4_reg = 32'h00000000;
        src_a_reg = 32'h00000000;
        imm_ext_reg = 32'h00000000;
        rd_reg = 5'h00;
        csr_we_reg = 1'b0;
        csr_addr_reg = 12'h000;
        csr_rd_reg = 32'h00000000;
        csr_wd_reg = 32'h00000000;
            valid_reg = 1'b0;
        exc_tag_reg = 5'b0;
        irq_tag_reg = 1'b0;
        badaddr_reg = 32'h00000000;
end

    always @(posedge clk ) begin
        if((rst == 1'b0)||(flush == 1'b1)) begin
            reg_write_reg <= 1'b0;
            mem_write_reg <= 1'b0;
            result_src_reg <= 2'b00;
            funct3_reg <= 3'b000;
            alu_result_reg <= 32'h00000000;
            write_data_reg <= 32'h00000000;
            pc_plus_4_reg <= 32'h00000000;
            src_a_reg <= 32'h00000000;
            imm_ext_reg <= 32'h00000000;
            rd_reg <= 5'h00;
            csr_we_reg <= 1'b0;
            csr_addr_reg <= 12'h000;
            csr_rd_reg <= 32'h00000000;
            csr_wd_reg <= 32'h00000000;
                    valid_reg <= 1'b0;
            exc_tag_reg <= 5'b0;
            irq_tag_reg <= 1'b0;
            badaddr_reg <= 32'h00000000;
end
        else if(!stall) begin 
            reg_write_reg <= reg_write_e;
            mem_write_reg <= mem_write_e;
            result_src_reg <= result_src_e;
            funct3_reg <= funct3_e;
            alu_result_reg <= alu_result_e;
            write_data_reg <= write_data_e;
            pc_plus_4_reg <= pc_plus_4_e;
            src_a_reg <= src_a_e;
            imm_ext_reg <= imm_ext_e;
            rd_reg <= rd_e;
            csr_we_reg <= csr_we_e;
            csr_addr_reg <= csr_addr_e;
            csr_rd_reg <= csr_rd_e;
            csr_wd_reg <= csr_wd_e;
                    valid_reg <= valid_in;
            exc_tag_reg <= exc_tag_in;
            irq_tag_reg <= irq_tag_in;
            badaddr_reg <= badaddr_in;
end
    end

    assign reg_write_m = reg_write_reg;
    assign mem_write_m = mem_write_reg;
    assign result_src_m = result_src_reg;
    assign funct3_m = funct3_reg;
    assign alu_result_m = alu_result_reg;
    assign write_data_m = write_data_reg;
    assign pc_plus_4_m = pc_plus_4_reg;
    assign src_a_m = src_a_reg;
    assign imm_ext_m = imm_ext_reg;
    assign rd_m = rd_reg;   
    assign csr_we_m = csr_we_reg;
    assign csr_addr_m = csr_addr_reg;
    assign csr_rd_m = csr_rd_reg;
    assign csr_wd_m = csr_wd_reg;
    assign valid_out = valid_reg;
    assign exc_tag_out = exc_tag_reg;
    assign irq_tag_out = irq_tag_reg;
    assign badaddr_out = badaddr_reg;

endmodule 


//pipeline for memory and writeback
module mem_wb_reg (
    input wire clk, rst, flush, stall,
    input wire valid_in, 
    input wire [4:0] exc_tag_in, 
    input wire irq_tag_in,
    input wire [31:0] badaddr_in,
    input wire reg_write_m, 
    input wire [2:0] result_src_m,
    input wire [31:0] alu_result_m, read_data_m, pc_plus_4_m,
    input wire [4:0] rd_m,
    input wire csr_we_m,
    input wire [11:0] csr_addr_m,
    input wire [31:0] csr_rd_m, csr_wd_m,
    output  reg_write_w, 
    output  [2:0] result_src_w,
    output  [31:0] alu_result_w, read_data_w, pc_plus_4_w,
    output  [4:0] rd_w,
    output  csr_we_w,
    output  [11:0] csr_addr_w,
    output  [31:0] csr_rd_w, csr_wd_w  
,
    output valid_out,
    output [4:0] exc_tag_out,
    output irq_tag_out,
    output [31:0] badaddr_out
);

    reg reg_write_reg; 
    reg [2:0] result_src_reg;
    reg [31:0] alu_result_reg, read_data_reg, pc_plus_4_reg;
    reg [4:0] rd_reg;
    reg csr_we_reg;
    reg [11:0] csr_addr_reg;
    reg [31:0] csr_rd_reg, csr_wd_reg;

        reg valid_reg;
    reg [4:0] exc_tag_reg;
    reg irq_tag_reg;
    reg [31:0] badaddr_reg;

// Initialize all registers to prevent 'x' values
    initial begin
        reg_write_reg = 1'b0;
        result_src_reg = 2'b00;
        alu_result_reg = 32'h00000000;
        read_data_reg = 32'h00000000;
        pc_plus_4_reg = 32'h00000000;
        rd_reg = 5'h00;
        csr_we_reg = 1'b0;
        csr_addr_reg = 12'h000;
        csr_rd_reg = 32'h00000000;
        csr_wd_reg = 32'h00000000;
            valid_reg = 1'b0;
        exc_tag_reg = 5'b0;
        irq_tag_reg = 1'b0;
        badaddr_reg = 32'h00000000;
end

    always @(posedge clk ) begin
        if((rst == 1'b0)||(flush == 1'b1)) begin
            reg_write_reg <= 1'b0;
            result_src_reg <= 2'b00;
            alu_result_reg <= 32'h00000000;
            read_data_reg <= 32'h00000000;
            pc_plus_4_reg <= 32'h00000000;
            rd_reg <= 5'h00;
            csr_we_reg <= 1'b0;
            csr_addr_reg <= 12'h000;
            csr_rd_reg <= 32'h00000000;
            csr_wd_reg <= 32'h00000000;
                    valid_reg <= 1'b0;
            exc_tag_reg <= 5'b0;
            irq_tag_reg <= 1'b0;
            badaddr_reg <= 32'h00000000;
end
        else if(!stall) begin 
            reg_write_reg <= reg_write_m;
            result_src_reg <= result_src_m;
            alu_result_reg <= alu_result_m;
            read_data_reg <= read_data_m;
            pc_plus_4_reg <= pc_plus_4_m;
            rd_reg <= rd_m;
            csr_we_reg <= csr_we_m;
            csr_addr_reg <= csr_addr_m;
            csr_rd_reg <= csr_rd_m;
            csr_wd_reg <= csr_wd_m;
                    valid_reg <= valid_in;
            exc_tag_reg <= exc_tag_in;
            irq_tag_reg <= irq_tag_in;
            badaddr_reg <= badaddr_in;
end
    end

    assign reg_write_w = reg_write_reg;
    assign result_src_w = result_src_reg;
    assign alu_result_w = alu_result_reg;
    assign read_data_w = read_data_reg;
    assign pc_plus_4_w = pc_plus_4_reg;
    assign rd_w = rd_reg;
    assign csr_we_w = csr_we_reg;
    assign csr_addr_w = csr_addr_reg;
    assign csr_rd_w = csr_rd_reg;
    assign csr_wd_w = csr_wd_reg;

    assign valid_out = valid_reg;
    assign exc_tag_out = exc_tag_reg;
    assign irq_tag_out = irq_tag_reg;
    assign badaddr_out = badaddr_reg;

endmodule
