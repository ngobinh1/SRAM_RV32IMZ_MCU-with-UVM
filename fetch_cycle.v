module fetch_cycle(
    input wire clk, rst, en,
    input wire pc_src_e,
    input wire [31:0] pc_target_e,

    input wire is_ecall, is_mret,
    input wire [31:0] trap_vec, epc,

    input wire [31:0] instr_f_in,
    output  [31:0] instr_f,
    output  [31:0] pc_f, pc_plus_4_f
);
    wire [31:0] pc_next_final;
    wire [31:0] pc_next_normal;
    // reg [31:0] instr_f_reg, pc_f_reg, pc_plus_4_f_reg;

    mux fetch_mux(
        .a(pc_plus_4_f),
        .b(pc_target_e),
        .s(pc_src_e),
        .c(pc_next_normal)
    );

    assign pc_next_final = (is_ecall === 1'b1) ? trap_vec :
                          (is_mret === 1'b1)  ? epc      :
                                               pc_next_normal;

    pc fetch_counter(
        .clk(clk),
        .rst(rst),
        .pc(pc_f),
        .pc_next(pc_next_final),
        .en(en)
    );

    adder fetch_adder(
        .a(pc_f),
        .b(32'h00000004),
        .c(pc_plus_4_f)
    );

    assign instr_f = instr_f_in;
    

    //  always @(posedge clk ) begin
    //      if(~rst) begin
    //          instr_f_reg <= 32'h00000000;
    //          pc_f_reg <= 32'h00000000;
    //          pc_plus_4_f_reg <= 32'h00000000;
    //      end
    //      else begin
    //          instr_f_reg <= instr_f;
    //          pc_f_reg <= pc_f;
    //          pc_plus_4_f_reg <= pc_plus_4_f;
    //      end
    //  end

    //  assign instr_f = (~rst) ? 32'h00000000 : instr_f_reg;
    //  assign pc_f = (~rst) ? 32'h00000000 : pc_f_reg;
    //  assign pc_plus_4_f = (~rst) ? 32'h00000000 : pc_plus_4_f_reg;

endmodule 