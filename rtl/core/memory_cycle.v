module memory_cycle (
    input wire clk, rst,
    input wire mem_write_m,
    input wire [31:0] alu_result_m, write_data_m,
    input wire [2:0] funct3_m,
    input wire [31:0] read_data_m_in,
    output [31:0] read_data_m,
    output [31:0] write_data_m_out 
);

    assign write_data_m_out = write_data_m;
    assign read_data_m = read_data_m_in;

endmodule