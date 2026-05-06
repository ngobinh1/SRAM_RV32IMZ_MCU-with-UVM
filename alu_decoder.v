module alu_decoder (
    input wire [1:0] alu_op,
    input wire [2:0] funct3,
    input wire [6:0] funct7, op,
    output  [3:0] alu_control
);
    // alu_op encoding:
    // 00: ADD (for load/store address calculation)
    // 01: SUB (for branches)
    // 10: Use funct3/funct7 (R-type and I-type ALU)
    // 11: Upper immediate (LUI, AUIPC)

    assign alu_control = 
        // Load/Store: always ADD
        (alu_op == 2'b00) ? 4'b0000 : 
        
        // Branch: always SUB for comparison
        (alu_op == 2'b01) ? 4'b0001 : 
        
        // R-type and I-type ALU operations
        (alu_op == 2'b10) ? (
            (funct3 == 3'b000) ? (
                // ADD or SUB (check op[5] and funct7[5])
                ({op[5], funct7[5]} == 2'b11) ? 4'b0001 :  // SUB (R-type only)
                4'b0000                                      // ADD (R-type or I-type)
            ) :
            (funct3 == 3'b001) ? 4'b1010 :  // SLL, SLLI - shift left logical
            (funct3 == 3'b010) ? 4'b0101 :  // SLT, SLTI - set less than (signed)
            (funct3 == 3'b011) ? 4'b0110 :  // SLTU, SLTIU - set less than unsigned
            (funct3 == 3'b100) ? 4'b0100 :  // XOR, XORI
            (funct3 == 3'b101) ? (
                // SRL/SRLI or SRA/SRAI (check funct7[5])
                (funct7[5] == 1'b1) ? 4'b1011 :  // SRA, SRAI - arithmetic right shift
                4'b1100                           // SRL, SRLI - logical right shift
            ) :
            (funct3 == 3'b110) ? 4'b0011 :  // OR, ORI
            (funct3 == 3'b111) ? 4'b0010 :  // AND, ANDI
            4'b0000                          // Default: ADD
        ) :
        
        // Upper immediate operations (LUI, AUIPC)
        (alu_op == 2'b11) ? (
            (funct3 == 3'b000) ? 4'b1000 :  // AUIPC - add PC + immediate
            (funct3 == 3'b001) ? 4'b1001 :  // LUI - pass immediate
            4'b1001                          // Default to LUI behavior
        ) :
        
        // Default
        4'b0000;

endmodule