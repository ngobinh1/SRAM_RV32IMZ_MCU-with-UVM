`timescale 1ns/1ps

module muldiv_alu (
    input  wire        clk,
    input  wire        rst,
    input  wire        req,
    input  wire        ack,     // Tín hiệu xác nhận từ Pipeline
    input  wire [2:0]  funct3,
    input  wire [31:0] a,
    input  wire [31:0] b,

    output reg  [31:0] result,
    output reg         busy,
    output reg         valid
);

    localparam IDLE     = 4'd0,
               MUL_ALBL = 4'd1,
               MUL_ALBH = 4'd2,
               MUL_AHBL = 4'd3,
               MUL_AHBH = 4'd4,
               MUL_DONE = 4'd5,
               DIV      = 4'd6,
               DONE     = 4'd7;
    
    reg [3:0] state;

    //------------------------------------------------------------
    // Instruction decode
    //------------------------------------------------------------
    wire is_mul = (funct3[2] == 1'b0);
    wire is_div_op = (funct3 == 3'b100) || (funct3 == 3'b101);
    wire is_rem_op = (funct3 == 3'b110) || (funct3 == 3'b111);
    wire is_signed_div = (funct3 == 3'b100) || (funct3 == 3'b110);
    wire is_mulh = (funct3 == 3'b001) || (funct3 == 3'b010) || (funct3 == 3'b011);

    wire is_signed_a = (funct3 == 3'b001) || (funct3 == 3'b010);
    wire is_signed_b = (funct3 == 3'b001);

    //------------------------------------------------------------
    // Multiplier 17x17
    //------------------------------------------------------------
    reg  [16:0] mul_op_a;
    reg  [16:0] mul_op_b;
    wire signed [33:0] mul_res = $signed(mul_op_a) * $signed(mul_op_b);
    reg  [63:0] mac_res;

    //------------------------------------------------------------
    // Divider
    //------------------------------------------------------------
    wire sign_a = is_signed_div & a[31];
    wire sign_b = is_signed_div & b[31];
    wire [31:0] abs_a = sign_a ? (~a + 1'b1) : a;
    wire [31:0] abs_b = sign_b ? (~b + 1'b1) : b;
    wire out_sign_q = sign_a ^ sign_b;
    wire out_sign_r = sign_a;
    wire div_by_zero = (b == 32'd0);
    wire overflow = is_signed_div && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);

    reg [31:0] div_q, div_r;
    reg [5:0]  count;
    reg sign_q_reg, sign_r_reg, is_rem_reg;
    reg [32:0] sub_res;
    reg [31:0] next_r;

    //------------------------------------------------------------
    // Main FSM
    //------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            state    <= IDLE;
            result   <= 32'd0;
            busy     <= 1'b0;
            valid    <= 1'b0;
            div_q    <= 32'd0;
            div_r    <= 32'd0;
            count    <= 6'd0;
            mac_res  <= 64'd0;
            mul_op_a <= 17'd0;
            mul_op_b <= 17'd0;
        end
        else begin
            case (state)

            IDLE: begin
                busy  <= 1'b0;
                valid <= 1'b0;
                if (req) begin
                    busy <= 1'b1;
                    if (is_mul) begin
                        mul_op_a <= {1'b0, a[15:0]};
                        mul_op_b <= {1'b0, b[15:0]};
                        mac_res  <= 64'd0;
                        state    <= MUL_ALBL;
                    end
                    else begin
                        sign_q_reg <= out_sign_q;
                        sign_r_reg <= out_sign_r;
                        is_rem_reg <= is_rem_op;
                        if (div_by_zero) begin
                            div_q <= 32'hFFFF_FFFF;
                            div_r <= a;
                            count <= 6'd0;
                        end
                        else if (overflow) begin
                            div_q <= 32'h8000_0000;
                            div_r <= 32'd0;
                            count <= 6'd0;
                        end
                        else begin
                            div_q <= abs_a;
                            div_r <= 32'd0;
                            count <= 6'd32;
                        end
                        state <= DIV;
                    end
                end
            end

            MUL_ALBL: begin
                mac_res  <= {30'd0, mul_res};
                mul_op_a <= {1'b0, a[15:0]};
                mul_op_b <= {is_signed_b & b[31], b[31:16]};
                state    <= MUL_ALBH;
            end

            MUL_ALBH: begin
                mac_res  <= $signed(mac_res) + $signed({{14{mul_res[33]}}, mul_res, 16'd0});
                mul_op_a <= {is_signed_a & a[31], a[31:16]};
                mul_op_b <= {1'b0, b[15:0]};
                state    <= MUL_AHBL;
            end

            MUL_AHBL: begin
                mac_res  <= $signed(mac_res) + $signed({{14{mul_res[33]}}, mul_res, 16'd0});
                if (is_mulh) begin
                    mul_op_a <= {is_signed_a & a[31], a[31:16]};
                    mul_op_b <= {is_signed_b & b[31], b[31:16]};
                    state    <= MUL_AHBH;
                end
                else begin
                    state    <= MUL_DONE;
                end
            end

            MUL_AHBH: begin
                mac_res <= $signed(mac_res) + $signed({mul_res, 32'd0});
                state   <= MUL_DONE;
            end

            MUL_DONE: begin
                result <= is_mulh ? mac_res[63:32] : mac_res[31:0];
                state  <= DONE;
            end

            DIV: begin
                if (count > 0) begin
                    next_r = {div_r[30:0], div_q[31]};
                    sub_res = {1'b0, next_r} - {1'b0, abs_b};
                    if (sub_res[32]) begin
                        div_r <= next_r;
                        div_q <= {div_q[30:0], 1'b0};
                    end
                    else begin
                        div_r <= sub_res[31:0];
                        div_q <= {div_q[30:0], 1'b1};
                    end
                    count <= count - 1'b1;
                end
                else begin
                    if (sign_q_reg) div_q <= ~div_q + 1'b1;
                    if (sign_r_reg) div_r <= ~div_r + 1'b1;
                    result <= is_rem_reg ? (sign_r_reg ? (~div_r + 1'b1) : div_r) : (sign_q_reg ? (~div_q + 1'b1) : div_q);
                    state <= DONE;
                end
            end

            DONE: begin
                busy  <= 1'b0;
                valid <= 1'b1;
                if (ack) begin
                    state <= IDLE;
                    valid <= 1'b0;
                end
            end

            endcase
        end
    end

endmodule