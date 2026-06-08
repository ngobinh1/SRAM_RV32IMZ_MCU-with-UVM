module writeback_cycle (
    input wire [2:0] result_src_w,
    input wire [31:0] alu_result_w, read_data_w, pc_plus_4_w, csr_rd_w,
    output  [31:0] result_w
);
    // Result source MUX
    // 00: ALU result
    // 01: Memory read data
    // 10: PC + 4 (for JAL/JALR)
    // 11: CSR read data
    mux_4to1 result_mux (
        .d0(alu_result_w),
        .d1(read_data_w),
        .d2(pc_plus_4_w),
        .d3(csr_rd_w), // Assuming csr_rd is available as an input
        .s(result_src_w),
        .y(result_w)
    );
endmodule

module writeback_arbiter (
    // ALU/MEM/CSR pipeline
    input wire pipe_we,
    input wire [4:0] pipe_rd,
    input wire [31:0] pipe_data,
    
    // MULDIV
    input wire md_we,
    input wire [4:0] md_rd,
    input wire [31:0] md_data,
    
    // Output to RF
    output wire rf_we,
    output wire [4:0] rf_waddr,
    output wire [31:0] rf_wdata
);
    assign rf_we    = md_we | pipe_we;
    assign rf_waddr = md_we ? md_rd   : pipe_rd;
    assign rf_wdata = md_we ? md_data : pipe_data;
endmodule