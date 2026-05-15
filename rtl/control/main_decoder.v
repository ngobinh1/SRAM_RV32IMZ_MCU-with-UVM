module main_decoder (
    input  [6:0] op,
    output  [2:0] result_src, 
    output [1:0] alu_op,
    output  [2:0] imm_src,
    output  mem_write, alu_src, reg_write, jump, branch, jalr
);
    /*
    Instruction types and their opcodes:
    - R-type:   0110011 (ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA)
    - I-type:   0010011 (ADDI, XORI, ORI, ANDI, SLTI, SLTIU, SLLI, SRLI, SRAI)
    - Load:     0000011 (LW)
    - Store:    0100011 (SW)
    - Branch:   1100011 (BEQ, BNE, BLT, BGE, BLTU, BGEU)
    - JALR:     1100111
    - JAL:      1101111
    - LUI:      0110111
    - AUIPC:    0010111
    - CSR:      1110011 (ECALL, EBREAK, CSR instructions)
    
    Immediate formats:
    - 00: I-type (12-bit immediate)
    - 01: S-type (store)
    - 10: B-type (branch)
    - 11: J-type (JAL) or U-type (LUI/AUIPC - both are 20-bit upper)
    */

    assign reg_write = (op == 7'b0000011 ||  // LW
                       op == 7'b0110011 ||   // R-type
                       op == 7'b0010011 ||   // I-type ALU
                       op == 7'b1101111 ||   // JAL
                       op == 7'b1100111 ||   // JALR
                       op == 7'b0110111 ||   // LUI
                       op == 7'b0010111) ?   // AUIPC
                       1'b1 : 1'b0;

    // FIXED: Added U-type handling for LUI and AUIPC
    // For LUI and AUIPC, we use imm_src = 00 (I-type) since we'll use instr[31:12] directly in ALU
    assign imm_src = (op == 7'b0100011) ? 3'b001 :  // S-type (store)
                    (op == 7'b1100011) ? 3'b010 :   // B-type (branch)
                    (op == 7'b1101111) ? 3'b011 :   // J-type (JAL)
                    // (op == 7'b0110011) ? 3'bxxx :   // R-type (don't care)
                    (op == 7'b1110011) ? 3'b100 :   // CSR instructions (if needed)
                    3'b000;                         // I-type (default, includes LUI/AUIPC)

    assign alu_src = (op == 7'b0000011 ||  // LW
                     op == 7'b0100011 ||   // SW
                     op == 7'b0010011 ||   // I-type ALU
                     op == 7'b1100111 ||   // JALR
                     op == 7'b0110111 ||   // LUI
                     op == 7'b0010111) ?   // AUIPC
                     1'b1 : 1'b0;

    assign mem_write = (op == 7'b0100011) ? 1'b1 : 1'b0;  // SW

    assign result_src = (op == 7'b0000011) ? 3'b01 :  // LW (from memory)
                       (op == 7'b1101111 ||           // JAL (PC+4)
                        op == 7'b1100111) ? 3'b10 :   // JALR (PC+4)
                        (op == 7'b1110011) ? 3'b11 :   // CSR instructions (if needed)
                       3'b00;                         // ALU result (default)

    assign branch = (op == 7'b1100011) ? 1'b1 : 1'b0;  // Branch instructions

    assign alu_op = (op == 7'b0110011 ||   // R-type
                    op == 7'b0010011) ?    // I-type ALU
                    2'b10 :                // Use funct3/funct7
                    (op == 7'b1100011) ?   // Branch
                    2'b01 :                // SUB for comparison
                    (op == 7'b0110111 ||   // LUI
                     op == 7'b0010111) ?   // AUIPC
                    2'b11 :                // Upper immediate
                    2'b00;                 // ADD (load/store/JAL/JALR)
    
    assign jump = (op == 7'b1101111 ||     // JAL
                   op == 7'b1100111) ?     // JALR
                   1'b1 : 1'b0;

    assign jalr = (op == 7'b1100111) ? 1'b1 : 1'b0;

endmodule