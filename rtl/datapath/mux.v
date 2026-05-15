module mux (
    input  [31:0] a, b,
    input  s,
    output  [31:0] c
);
    assign c = s ? b : a;
endmodule

module mux_3_1 (
    input  [31:0] a, b, c,
    input  [1:0] s,
    output  [31:0] d 
);
    // s = 00: select a
    // s = 01: select b
    // s = 10: select c
    assign d = (s == 2'b00) ? a : 
               (s == 2'b01) ? b : 
               (s == 2'b10) ? c : 
               32'h00000000;
endmodule

// MUX to choose Result (write to Register File)
module mux_4to1 (
    input  [31:0] d0, // Result from ALU
    input  [31:0] d1, // Data read from Memory (Load)
    input  [31:0] d2, // PC + 4 (for JAL/JALR)
    input  [31:0] d3, // NEW: Data read from CSR (csr_rd)
    input  [2:0] s,   // Result source signal (2-bit)
    output reg [31:0] y
);
    always @(s or d0 or d1 or d2 or d3) begin
        case(s)
            3'b000: y = d0; 
            3'b001: y = d1; 
            3'b010: y = d2; 
            3'b011: y = d3; // Choose CSR
            default : y = 32'h00000000; // Default case
        endcase
    end
endmodule