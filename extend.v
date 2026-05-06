module extend(
    input  [31:0] instr,
    input  [2:0] imm_src,
    output reg [31:0] imm_ext
);

    always @(imm_src or instr) begin
        case(imm_src)
            // I-type: sign-extend imm[11:0]
            3'b000: begin
                // Check if this is LUI or AUIPC (upper 20 bits)
                // For normal I-type: instr[31:20]
                // For LUI/AUIPC: instr[31:12] should be passed through
                // We detect LUI/AUIPC by checking if it's an upper immediate instruction
                if (instr[6:0] == 7'b0110111 || instr[6:0] == 7'b0010111) begin
                    // U-type: upper 20 bits (for LUI/AUIPC)
                    imm_ext = {instr[31:12], 12'b0};
                end else begin
                    // Normal I-type
                    imm_ext = {{20{instr[31]}}, instr[31:20]};
                end
            end
            
            // S-type: sign-extend {imm[11:5], imm[4:0]}
            3'b001: imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            
            // B-type: sign-extend {imm[12], imm[10:5], imm[4:1], 0}
            3'b010: imm_ext = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            
            // J-type: sign-extend {imm[20], imm[10:1], imm[11], imm[19:12], 0}
            3'b011: imm_ext = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            
            // zero-extend for CSR instructions (if needed, can be modified based on specific CSR encoding)
             3'b100: imm_ext = {27'b0, instr[19:15]}; // Example for CSR rs1 field
            
            default: imm_ext = 32'h00000000;
        endcase
    end
    
endmodule