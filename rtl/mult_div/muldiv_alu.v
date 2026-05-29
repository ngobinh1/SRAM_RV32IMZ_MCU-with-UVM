`timescale 1ns/1ps

module muldiv_alu (
    input  wire        clk,
    input  wire        rst,
    input  wire        req,
    input  wire        ack,     // NEW: Tín hiệu xác nhận từ Pipeline
    input  wire [2:0]  funct3,
    input  wire [31:0] a,
    input  wire [31:0] b,

    output reg  [31:0] result,
    output reg         busy,
    output reg         valid
);

    localparam IDLE = 2'd0,
               MUL  = 2'd1,
               DIV  = 2'd2,
               DONE = 2'd3;
    reg [1:0] state;

    //------------------------------------------------------------
    // Instruction decode
    //------------------------------------------------------------
    wire is_mul = (funct3[2] == 1'b0);
    wire is_div_op = (funct3 == 3'b100) || (funct3 == 3'b101);
    wire is_rem_op = (funct3 == 3'b110) || (funct3 == 3'b111);
    wire is_signed_div = (funct3 == 3'b100) || (funct3 == 3'b110);

    //------------------------------------------------------------
    // Multiplier
    //------------------------------------------------------------
    wire signed [31:0] s_a = a;
    wire signed [31:0] s_b = b;
    wire signed [63:0] ss_mul = s_a * s_b;
    wire signed [63:0] su_mul = s_a * $signed({1'b0,b});
    wire        [63:0] uu_mul = a * b;

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
            state  <= IDLE;
            result <= 32'd0;
            busy   <= 1'b0;
            valid  <= 1'b0;
            div_q  <= 32'd0;
            div_r  <= 32'd0;
            count  <= 6'd0;
        end
        else begin
            case (state)

            IDLE: begin
                busy  <= 1'b0;
                valid <= 1'b0;
                if (req) begin       // Nhận lệnh chạy ngay không cần quan tâm sườn
                    busy <= 1'b1;
                    if (is_mul) begin
                        state <= MUL;
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

            MUL: begin
                case (funct3)
                    3'b000: result <= ss_mul[31:0];
                    3'b001: result <= ss_mul[63:32];
                    3'b010: result <= su_mul[63:32];
                    3'b011: result <= uu_mul[63:32];
                    default: result <= 32'd0;
                endcase
                state <= DONE;
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
                if (ack) begin       // Chờ Pipeline xác nhận đã lấy dữ liệu rồi mới nghỉ
                    state <= IDLE;
                    valid <= 1'b0;
                end
            end

            endcase
        end
    end

endmodule