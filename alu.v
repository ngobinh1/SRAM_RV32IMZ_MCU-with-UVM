module alu (
    input wire [31:0] a, b,
    input wire [3:0] alu_control,
    output reg overflow, carry, neg, zero,
    output reg [31:0] result
);
    wire [31:0] sum, b_inv;
    wire cout;

    // For subtraction: a + (~b + 1) = a - b
    assign b_inv = (alu_control[0] == 1'b1) ? ~b : b;
    assign {cout, sum} = a + b_inv + {31'b0, alu_control[0]};

    always @(alu_control or a or b) begin
        case(alu_control)
            4'b0000: result = sum;                     // ADD
            4'b0001: result = sum;                     // SUB
            4'b0010: result = a & b;                   // AND, ANDI
            4'b0011: result = a | b;                   // OR, ORI
            4'b0100: result = a ^ b;                   // XOR, XORI
            4'b0101: begin
                // SLT, SLTI - signed comparison
                if (a[31] != b[31]) begin
                    // Different signs: negative number is less than positive
                    result = {31'b0, a[31]};
                end else begin
                    // Same sign: compare magnitude
                    result = {31'b0, (a < b)};
                end
            end
            4'b0110: result = {31'b0, (a < b)};        // SLTU, SLTIU - unsigned comparison
            4'b0111: result = {a[31:12], 12'b0};       // Reserved
            4'b1000: result = a + b;                   // AUIPC - PC + (imm << 12)
                                                        // Note: b already has imm << 12 from extend
            4'b1001: result = b;                       // LUI - just pass immediate
                                                        // Note: b already has imm << 12 from extend
            4'b1010: result = a << b[4:0];             // SLL, SLLI - shift left logical
            4'b1011: result = a[31]? ((a >> b[4:0])|~(32'hFFFFFFFF >> b[4:0])) : (a >> b[4:0]);   // SRA, SRAI - arithmetic right shift
            4'b1100: result = a >> b[4:0];             // SRL, SRLI - logical right shift
            default: result = 32'h00000000;
        endcase

        // Overflow: for add/sub only (alu_control[1] == 0)
        overflow = ((sum[31] ^ a[31]) & 
                   (~(alu_control[0] ^ b[31] ^ a[31])) &
                   (~alu_control[1]));

        // Carry: for add/sub only
        carry = ((~alu_control[1]) & cout);

        // Zero flag
        zero = (result == 32'h00000000);

        // Negative flag
        neg = result[31];
    end

endmodule