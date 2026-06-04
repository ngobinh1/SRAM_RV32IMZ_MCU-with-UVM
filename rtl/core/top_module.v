module riscv_pipeline_top (
    input wire clk,
    input wire rst
);
    // Fetch stage signals
    wire [31:0] pc_f, pc_plus_4_f, instr_f, pc_target_e;
    wire pc_src_e, stall_f;

    // Decode stage signals
    wire [31:0] instr_d, pc_d, pc_plus_4_d;
    wire [31:0] read_data_1_d, read_data_2_d, imm_ext_d;
    wire [4:0] rs1_d, rs2_d, rd_d;
    wire reg_write_d, mem_write_d, jump_d, branch_d, alu_src_d, jalr_d;
    wire [2:0] funct3_d;
    wire [2:0] result_src_d;
    wire [3:0] alu_control_d;
    wire stall_d, flush_d;
    wire is_ecall_d, is_mret_d, csr_we_d, md_req_d, is_illegal_d;
    wire [2:0] md_op_d;
    wire [11:0] csr_addr_d=instr_d[31:20];
    wire [31:0] csr_rd_d;

    // Execute stage signals
    wire [31:0] read_data_1_e, read_data_2_e, imm_ext_e, pc_e, pc_plus_4_e;
    wire [31:0] alu_result_e, write_data_e;
    wire [4:0] rs1_e, rs2_e, rd_e;
    wire reg_write_e, mem_write_e, jump_e, branch_e, alu_src_e, jalr_e;
    wire [2:0] funct3_e;
    wire [2:0] result_src_e;
    wire [1:0] forward_a_e, forward_b_e;
    wire [3:0] alu_control_e;
    wire flush_e;
    wire csr_we_e;
    wire [11:0] csr_addr_e;
    wire [31:0] csr_rd_e, csr_wd_e;
    wire md_req_e;
    wire is_ecall_e, is_mret_e, is_illegal_e;
    wire [2:0] md_op_e;

    // Issue stage signals (output of issue, input to pipeline_2_3)
    wire issue_stall, issue_valid;
    wire reg_write_i, mem_write_i, alu_src_i, jump_i, branch_i, jalr_i;
    wire [2:0] funct3_i, result_src_i, md_op_i;
    wire [3:0] alu_control_i;
    wire [31:0] read_data_1_i, read_data_2_i, pc_i, pc_plus_4_i, imm_ext_i;
    wire [4:0] rs1_i, rs2_i, rd_i;
    wire csr_we_i, is_ecall_i, is_mret_i, md_req_i, is_illegal_i;
    wire [11:0] csr_addr_i;
    wire [31:0] csr_rd_i;

    // Memory stage signals
    wire [31:0] alu_result_m, write_data_m, pc_plus_4_m, read_data_m;
    wire [4:0] rd_m;
    wire [2:0] funct3_m;
    wire reg_write_m, mem_write_m;
    wire [2:0] result_src_m;
    wire csr_we_m;
    wire [11:0] csr_addr_m;
    wire [31:0] csr_rd_m, csr_wd_m;
    wire [31:0] write_data_m_aligned;

    // Writeback stage signals
    wire [31:0] alu_result_w, read_data_w, pc_plus_4_w, result_w;
    wire [4:0] rd_w;
    wire reg_write_w;
    wire [2:0] result_src_w;
    wire csr_we_w;
    wire [11:0] csr_addr_w;
    wire [31:0] csr_rd_w, csr_wd_w;

    // Exception PC
    wire [31:0] trap_vec, epc;

    wire icache_stall, dcache_stall;
    wire stall_e, stall_m, stall_w;

    wire en_e = ~stall_e;
    wire en_m = ~stall_m;
    wire en_w = ~stall_w;

    wire [31:0] instr_f_from_icache;
    wire [31:0] read_data_m_from_dcache;
    wire mem_read_m = (result_src_m == 3'b001);

    wire reg_write_w_pipe;
    wire [4:0] rd_w_pipe;
    wire [31:0] result_w_pipe;

    wire predict_taken_f, predict_taken_d, predict_taken_i, predict_taken_e;
    wire [31:0] predict_target_f, predict_target_d, predict_target_i, predict_target_e;
    wire actual_taken_e;
    wire [31:0] actual_target_e;
    wire update_valid_e;

    // ==========================================
    // AXI4-LITE WIRES
    // ==========================================
    // Master 0 (I-Cache)
    wire [31:0] i_araddr, i_rdata;
    wire [1:0]  i_rresp;
    wire i_arvalid, i_arready, i_rvalid, i_rready;

    // Master 1 (D-Cache)
    wire [31:0] d_awaddr, d_wdata, d_araddr, d_rdata;
    wire [3:0]  d_wstrb;
    wire [1:0]  d_bresp, d_rresp;
    wire d_awvalid, d_awready, d_wvalid, d_wready, d_bvalid, d_bready;
    wire d_arvalid, d_arready, d_rvalid, d_rready;
    
    // Slave 0 (SRAM Wrapper)
    wire [31:0] s_awaddr, s_wdata, s_araddr, s_rdata;
    wire [3:0]  s_wstrb;
    wire [1:0]  s_bresp, s_rresp;
    wire s_awvalid, s_awready, s_wvalid, s_wready, s_bvalid, s_bready;
    wire s_arvalid, s_arready, s_rvalid, s_rready;

    // Wires for SRAM Macro
    wire [9:0]  sram_ad;
    wire [31:0] sram_di, sram_do, sram_ben;
    wire sram_en, sram_r_wb;

    // Enable signal for fetch stage (inverse of stall)
    wire en_f = ~stall_f;
    wire en_d = ~stall_d;

    // Mult/Div unit signals
    wire [31:0] md_src_a, md_src_b_reg;
    wire [31:0] muldiv_result;
    wire div_busy, md_valid;
    wire real_div_busy = div_busy | (md_req_e & ~md_valid);

    // Fetch Cycle
    fetch_cycle fetch_stage (
        .clk(clk), .rst(rst), .en(en_f),
        .pc_src_e(pc_src_e), .pc_target_e(pc_target_e),
        .is_ecall(is_ecall_d), .is_mret(is_mret_d),
        .trap_vec(trap_vec), .epc(epc),
        .instr_f_in(instr_f_from_icache),
        .instr_f(instr_f), .pc_f(pc_f), .pc_plus_4_f(pc_plus_4_f),
        .predict_taken_f(predict_taken_f), .predict_target_f(predict_target_f)
    );

    // Pipeline Register: Fetch -> Decode
    pipeline_1_2 pipeline_fd (
        .clk(clk), .rst(rst), .clr(flush_d), .en(en_d),
        .instr_f(instr_f), .pc_f(pc_f), .pc_plus_4_f(pc_plus_4_f),
        .predict_taken_f(predict_taken_f), .predict_target_f(predict_target_f),
        .instr_d(instr_d), .pc_d(pc_d), .pc_plus_4_d(pc_plus_4_d),
        .predict_taken_d(predict_taken_d), .predict_target_d(predict_target_d)
    );

    wire        actual_rf_we  = (md_req_e & md_valid) ? 1'b1          : reg_write_w_pipe;
    wire [4:0]  actual_rf_rd  = (md_req_e & md_valid) ? rd_e          : rd_w_pipe; 
    wire [31:0] actual_rf_din = (md_req_e & md_valid) ? muldiv_result : result_w_pipe;

    // Decode Cycle
    decode_cycle decode_stage (
        .clk(clk), .rst(rst), .reg_write_w(actual_rf_we), .rd_w(actual_rf_rd),
        .instr_d(instr_d), .result_w(actual_rf_din), .pc_in(pc_d), .pc_plus_4_in(pc_plus_4_d),
        .imm_ext_d(imm_ext_d), .read_data_1_d(read_data_1_d), .read_data_2_d(read_data_2_d),
        .rs1_d(rs1_d), .rs2_d(rs2_d), .rd_d(rd_d),
        .reg_write_d(reg_write_d), .mem_write_d(mem_write_d),
        .jump_d(jump_d), .branch_d(branch_d), .jalr_d(jalr_d),
        .funct3_d(funct3_d), .alu_src_d(alu_src_d), .result_src_d(result_src_d),
        .alu_control_d(alu_control_d), .is_ecall_d(is_ecall_d), .is_mret_d(is_mret_d), .csr_we_d(csr_we_d),
        .md_req_d(md_req_d), .is_illegal_d(is_illegal_d), .md_op_d(md_op_d)
    );

    wire execute_ready = ~real_div_busy & ~dcache_stall;
    wire clr_issue = flush_e;

    // Issue Queue / Scheduler
    issue issue_stage (
        .clk(clk), .rst(rst), .clr(clr_issue),
        .execute_ready(execute_ready), .rd_e(rd_e), .result_src_e(result_src_e),
        .decode_valid(~stall_d),
        .reg_write_d(reg_write_d), .mem_write_d(mem_write_d), .alu_src_d(alu_src_d),
        .jump_d(jump_d), .branch_d(branch_d), .jalr_d(jalr_d),
        .funct3_d(funct3_d), .result_src_d(result_src_d), .alu_control_d(alu_control_d),
        .read_data_1_d(read_data_1_d), .read_data_2_d(read_data_2_d),
        .pc_d(pc_d), .pc_plus_4_d(pc_plus_4_d), .imm_ext_d(imm_ext_d),
        .rs1_d(rs1_d), .rs2_d(rs2_d), .rd_d(rd_d),
        .csr_we_d(csr_we_d), .csr_addr_d(csr_addr_d), .csr_rd_d(csr_rd_d),
        .is_ecall_d(is_ecall_d), .is_mret_d(is_mret_d), .md_req_d(md_req_d), .is_illegal_d(is_illegal_d), .md_op_d(md_op_d),
        .issue_stall(issue_stall), .issue_valid(issue_valid),
        .reg_write_i(reg_write_i), .mem_write_i(mem_write_i), .alu_src_i(alu_src_i),
        .jump_i(jump_i), .branch_i(branch_i), .jalr_i(jalr_i),
        .funct3_i(funct3_i), .result_src_i(result_src_i), .alu_control_i(alu_control_i),
        .read_data_1_i(read_data_1_i), .read_data_2_i(read_data_2_i),
        .pc_i(pc_i), .pc_plus_4_i(pc_plus_4_i), .imm_ext_i(imm_ext_i),
        .rs1_i(rs1_i), .rs2_i(rs2_i), .rd_i(rd_i),
        .csr_we_i(csr_we_i), .csr_addr_i(csr_addr_i), .csr_rd_i(csr_rd_i),
        .is_ecall_i(is_ecall_i), .is_mret_i(is_mret_i), .md_req_i(md_req_i), .is_illegal_i(is_illegal_i), .md_op_i(md_op_i),
        .predict_taken_d(predict_taken_d), .predict_target_d(predict_target_d),
        .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i)
    );

    wire flush_pipeline_2_3 = flush_e | ~issue_valid;

    // Pipeline Register: Decode/Issue -> Execute
    pipeline_2_3 pipeline_de (
        .clk(clk), .rst(rst), .clr(flush_pipeline_2_3), .en(en_e),
        .reg_write_d(reg_write_i), .mem_write_d(mem_write_i),
        .alu_src_d(alu_src_i), .jump_d(jump_i), .branch_d(branch_i), .jalr_d(jalr_i),
        .funct3_d(funct3_i), .result_src_d(result_src_i), .alu_control_d(alu_control_i),
        .read_data_1_d(read_data_1_i), .read_data_2_d(read_data_2_i),
        .pc_d(pc_i), .pc_plus_4_d(pc_plus_4_i), .imm_ext_d(imm_ext_i),
        .rs1_d(rs1_i), .rs2_d(rs2_i), .rd_d(rd_i),
        .csr_we_d(csr_we_i), .csr_addr_d(csr_addr_i), .csr_rd_d(csr_rd_i),
        .md_req_d(md_req_i), .is_illegal_d(is_illegal_i), .is_ecall_d(is_ecall_i), .is_mret_d(is_mret_i),
        .md_op_d(md_op_i),
        .reg_write_e(reg_write_e), .mem_write_e(mem_write_e),
        .alu_src_e(alu_src_e), .jump_e(jump_e), .branch_e(branch_e), .jalr_e(jalr_e),
        .funct3_e(funct3_e), .result_src_e(result_src_e), .alu_control_e(alu_control_e),
        .read_data_1_e(read_data_1_e), .read_data_2_e(read_data_2_e),
        .pc_e(pc_e), .pc_plus_4_e(pc_plus_4_e), .imm_ext_e(imm_ext_e),
        .rs1_e(rs1_e), .rs2_e(rs2_e), .rd_e(rd_e),
        .csr_we_e(csr_we_e), .csr_addr_e(csr_addr_e), .csr_rd_e(csr_rd_e),
        .md_req_e(md_req_e), .is_illegal_e(is_illegal_e), .is_ecall_e(is_ecall_e), .is_mret_e(is_mret_e),
        .md_op_e(md_op_e),
        .predict_taken_d(predict_taken_i), .predict_target_d(predict_target_i),
        .predict_taken_e(predict_taken_e), .predict_target_e(predict_target_e)
    );

    wire [31:0] src_a_e_forwarded = (forward_a_e == 2'b10) ? alu_result_m : (forward_a_e == 2'b01) ? result_w : read_data_1_e;
    
    csr_alu csr_alu_inst (
        .csr_rd(csr_rd_e), .csr_wd(csr_wd_e), .imm_ext(imm_ext_e), .src_a(src_a_e_forwarded), .funct3(funct3_e)
    );

    // Execute Cycle
    execute_cycle execute_stage (
        .forward_a_e(forward_a_e), .forward_b_e(forward_b_e),
        .jump_e(jump_e), .branch_e(branch_e), .jalr_e(jalr_e), .funct3_e(funct3_e),
        .alu_src_e(alu_src_e), .alu_control_e(alu_control_e),
        .alu_result_m(alu_result_m), .read_data_1_e(read_data_1_e), .read_data_2_e(read_data_2_e),
        .imm_ext_e(imm_ext_e), .pc_e(pc_e), .pc_plus_4_e(pc_plus_4_e), .result_w(result_w),
        .rd_e(rd_e), .pc_target_e(pc_target_e), .alu_result_e(alu_result_e),
        .write_data_e(write_data_e), .pc_src_e(pc_src_e), .src_a_out(md_src_a), .src_b_reg_out(md_src_b_reg),
        .predict_taken_e(predict_taken_e), .predict_target_e(predict_target_e),
        .actual_taken_e(actual_taken_e), .actual_target_e(actual_target_e),
        .update_valid_e(update_valid_e)
    );

    branch_predictor bp_inst (
        .clk(clk),
        .rst_n(rst),
        .if_pc(pc_f),
        .predict_taken(predict_taken_f),
        .predict_target(predict_target_f),
        .update_valid(update_valid_e),
        .update_pc(pc_e),
        .actual_taken(actual_taken_e),
        .actual_target(actual_target_e)
    );

    wire md_ack = en_e & md_valid;
    
    muldiv_alu u_muldiv_core (
        .clk(clk),
        .rst(rst),
        .req(md_req_e),
        .ack(md_ack),
        .funct3(funct3_e),
        .a(md_src_a),
        .b(md_src_b_reg),
        .result(muldiv_result),
        .busy(div_busy),
        .valid(md_valid)
    );

    // Pipeline Register: Execute -> Memory
    pipeline_3_4 pipeline_em (
        .clk(clk), .rst(rst), .en(en_m),
        .reg_write_e(reg_write_e & ~md_req_e), .mem_write_e(mem_write_e), .result_src_e(result_src_e),
        .funct3_e(funct3_e), .alu_result_e(alu_result_e), .write_data_e(write_data_e),
        .pc_plus_4_e(pc_plus_4_e), .rd_e(rd_e),
        .csr_we_e(csr_we_e), .csr_addr_e(csr_addr_e), .csr_rd_e(csr_rd_e), .csr_wd_e(csr_wd_e),
        .reg_write_m(reg_write_m), .mem_write_m(mem_write_m), .funct3_m(funct3_m),
        .result_src_m(result_src_m), .alu_result_m(alu_result_m), .write_data_m(write_data_m),
        .pc_plus_4_m(pc_plus_4_m), .rd_m(rd_m),
        .csr_we_m(csr_we_m), .csr_addr_m(csr_addr_m), .csr_rd_m(csr_rd_m), .csr_wd_m(csr_wd_m)
        );
    
    // Memory Cycle
    memory_cycle memory_stage (
        .clk(clk), .rst(rst), .mem_write_m(mem_write_m),
        .alu_result_m(alu_result_m), .write_data_m(write_data_m), .funct3_m(funct3_m),
        .read_data_m_in(read_data_m_from_dcache), .read_data_m(read_data_m), .write_data_m_out(write_data_m_aligned) 
    );

    // Pipeline Register: Memory -> Writeback
    pipeline_4_5 pipeline_mw (
        .clk(clk), .rst(rst), .en(en_w),
        .reg_write_m(reg_write_m), .result_src_m(result_src_m), .alu_result_m(alu_result_m),
        .read_data_m(read_data_m), .pc_plus_4_m(pc_plus_4_m), .rd_m(rd_m),
        .csr_we_m(csr_we_m), .csr_addr_m(csr_addr_m), .csr_rd_m(csr_rd_m), .csr_wd_m(csr_wd_m),
        .reg_write_w(reg_write_w_pipe), .result_src_w(result_src_w), .alu_result_w(alu_result_w),
        .read_data_w(read_data_w), .pc_plus_4_w(pc_plus_4_w), .rd_w(rd_w_pipe),
        .csr_we_w(csr_we_w), .csr_addr_w(csr_addr_w), .csr_rd_w(csr_rd_w), .csr_wd_w(csr_wd_w)
    );

    wire is_exception_d = is_ecall_e | is_illegal_e;
    wire [31:0] exception_cause = is_ecall_e ? 32'd11 : 32'd2;

    csr_file csr_file_inst (
        .clk(clk), .rst(rst), .csr_we(csr_we_w),
        .csr_raddr(instr_d[31:20]), .csr_waddr(csr_addr_w), .csr_wd(csr_wd_w), .csr_rd(csr_rd_d),
        .is_exception(is_exception_d), .pc(pc_e), .cause(exception_cause), .epc(epc), .trap_vec(trap_vec)
    );

    // Writeback Cycle
    writeback_cycle writeback_stage (
        .result_src_w(result_src_w), .alu_result_w(alu_result_w),
        .read_data_w(read_data_w), .pc_plus_4_w(pc_plus_4_w),
        .csr_rd_w(csr_rd_w), .result_w(result_w_pipe) 
    );

    assign rd_w        = actual_rf_rd;
    assign reg_write_w = actual_rf_we;
    assign result_w    = actual_rf_din;

    // Hazard Unit
    hazard_unit hazard_detection (
        .rst(rst), .reg_write_w(reg_write_w), .reg_write_m(reg_write_m),
        .pc_src_e(pc_src_e), .rd_m(rd_m), .rd_w(rd_w),
        .rs1_e(rs1_e), .rs2_e(rs2_e), .rd_e(rd_e), .rs1_d(rs1_d), .rs2_d(rs2_d),
        .result_src_e(result_src_e), .forward_a_e(forward_a_e), .forward_b_e(forward_b_e),
        .stall_f(stall_f), .stall_d(stall_d), .icache_stall(icache_stall), .dcache_stall(dcache_stall),
        .div_busy(real_div_busy), .issue_stall(issue_stall),
        .stall_e(stall_e), .stall_m(stall_m), .stall_w(stall_w),
        .flush_e(flush_e), .flush_d(flush_d)
    );

    // ==========================================
    // L1 I-CACHE (AXI4-Lite Master)
    // ==========================================
    l1_icache icache_inst (
        .clk(clk), .rst_n(rst), .cpu_addr(pc_f), .cpu_rdata(instr_f_from_icache), .icache_stall(icache_stall),
        .m_axi_araddr(i_araddr), .m_axi_arvalid(i_arvalid), .m_axi_arready(i_arready),
        .m_axi_rdata(i_rdata), .m_axi_rresp(i_rresp), .m_axi_rvalid(i_rvalid), .m_axi_rready(i_rready)
    );

    // ==========================================
    // L1 D-CACHE (AXI4-Lite Master)
    // ==========================================
    l1_dcache dcache_inst (
        .clk(clk), .rst_n(rst), .cpu_addr(alu_result_m), .cpu_wdata(write_data_m_aligned),
        .cpu_we(mem_write_m), .cpu_re(mem_read_m), .cpu_funct3(funct3_m),
        .cpu_rdata(read_data_m_from_dcache), .dcache_stall(dcache_stall),
        
        .m_axi_awaddr(d_awaddr), .m_axi_awvalid(d_awvalid), .m_axi_awready(d_awready),
        .m_axi_wdata(d_wdata), .m_axi_wstrb(d_wstrb), .m_axi_wvalid(d_wvalid), .m_axi_wready(d_wready),
        .m_axi_bresp(d_bresp), .m_axi_bvalid(d_bvalid), .m_axi_bready(d_bready),
        .m_axi_araddr(d_araddr), .m_axi_arvalid(d_arvalid), .m_axi_arready(d_arready),
        .m_axi_rdata(d_rdata), .m_axi_rresp(d_rresp), .m_axi_rvalid(d_rvalid), .m_axi_rready(d_rready)
    );

    // ==========================================
    // AXI INTERCONNECT
    // ==========================================
    axi_interconnect axi_ic_inst (
        .clk(clk), .rst_n(rst),
        .m0_araddr(i_araddr), .m0_arvalid(i_arvalid), .m0_arready(i_arready), .m0_rdata(i_rdata), .m0_rresp(i_rresp), .m0_rvalid(i_rvalid), .m0_rready(i_rready),
        
        .m1_awaddr(d_awaddr), .m1_awvalid(d_awvalid), .m1_awready(d_awready), .m1_wdata(d_wdata), .m1_wstrb(d_wstrb), .m1_wvalid(d_wvalid), .m1_wready(d_wready), .m1_bresp(d_bresp), .m1_bvalid(d_bvalid), .m1_bready(d_bready),
        .m1_araddr(d_araddr), .m1_arvalid(d_arvalid), .m1_arready(d_arready), .m1_rdata(d_rdata), .m1_rresp(d_rresp), .m1_rvalid(d_rvalid), .m1_rready(d_rready),
        
        .s0_awaddr(s_awaddr), .s0_awvalid(s_awvalid), .s0_awready(s_awready), .s0_wdata(s_wdata), .s0_wstrb(s_wstrb), .s0_wvalid(s_wvalid), .s0_wready(s_wready), .s0_bresp(s_bresp), .s0_bvalid(s_bvalid), .s0_bready(s_bready),
        .s0_araddr(s_araddr), .s0_arvalid(s_arvalid), .s0_arready(s_arready), .s0_rdata(s_rdata), .s0_rresp(s_rresp), .s0_rvalid(s_rvalid), .s0_rready(s_rready)
    );

    // ==========================================
    // AXI SRAM WRAPPER (Slave)
    // ==========================================
    axi_sram_wrapper sram_wrap_inst (
        .clk(clk), .rst_n(rst),
        .s_axi_awaddr(s_awaddr), .s_axi_awvalid(s_awvalid), .s_axi_awready(s_awready),
        .s_axi_wdata(s_wdata), .s_axi_wstrb(s_wstrb), .s_axi_wvalid(s_wvalid), .s_axi_wready(s_wready),
        .s_axi_bresp(s_bresp), .s_axi_bvalid(s_bvalid), .s_axi_bready(s_bready),
        .s_axi_araddr(s_araddr), .s_axi_arvalid(s_arvalid), .s_axi_arready(s_arready),
        .s_axi_rdata(s_rdata), .s_axi_rresp(s_rresp), .s_axi_rvalid(s_rvalid), .s_axi_rready(s_rready),
        
        .sram_ad(sram_ad), .sram_di(sram_di), .sram_ben(sram_ben), 
        .sram_en(sram_en), .sram_r_wb(sram_r_wb), .sram_do(sram_do)
    );

    // ==========================================
    // EF_SRAM_1024x32 MACRO
    // ==========================================
    EF_SRAM_1024x32 sram_macro (
        .CLKin(~clk), 
        .AD(sram_ad),
        .DI(sram_di),
        .DO(sram_do),
        .BEN(sram_ben),
        .EN(sram_en),
        .R_WB(sram_r_wb),
        .ScanOutCC(),
        
        // Test/scan pins tied to 0
        .TM(1'b0), .SM(1'b0), .ScanInCC(1'b0), .ScanInDL(1'b0), .ScanInDR(1'b0),
        .WLBI(1'b0), .WLOFF(1'b0),
        .vpwrac(1'b1), .vpwrpc(1'b1)
    );
    always @(posedge clk) begin
        if ($time > 714900 && $time < 715100) begin
            $display("DEBUG_TRACE: time=%0t pc_f=%h pc_next_final=%h pc_next_normal=%h is_ecall_d=%b is_mret_d=%b epc=%h pc_src_e=%b actual_target_e=%h", $time, pc_f, fetch_stage.pc_next_final, fetch_stage.pc_next_normal, is_ecall_d, is_mret_d, epc, pc_src_e, actual_target_e);
        end
    end
endmodule