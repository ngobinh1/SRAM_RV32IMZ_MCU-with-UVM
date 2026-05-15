module csr_alu (
    input  [2:0] funct3,
    input  [31:0] src_a,      // data from rs1
    input  [31:0] imm_ext,    // data from immediate (Z-imm) already sign-extended
    input  [31:0] csr_rd,     // data read from csr_file.v
    output reg [31:0] csr_wd  // data written to csr_file.v
);
    // If funct3[2] == 1 (instructions with 'i' suffix like csrrwi), use imm_ext. Otherwise, use src_a
    wire [31:0] csr_operand = (funct3[2]) ? imm_ext : src_a; 

    always @(funct3[1:0] or csr_rd or csr_operand) begin
        case (funct3[1:0])
            2'b01: csr_wd = csr_operand;               // csrrw, csrrwi (Ghi đè)
            2'b10: csr_wd = csr_rd | csr_operand;      // csrrs, csrrsi (Set bit)
            2'b11: csr_wd = csr_rd & ~csr_operand;     // csrrc, csrrci (Clear bit)
            default: csr_wd = 32'd0;
        endcase
    end
endmodule