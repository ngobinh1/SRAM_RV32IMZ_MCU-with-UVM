`timescale 1ns/1ps

module register_file (
    input wire clk,
    input wire rst,
    input wire write_en_3,
    input wire [4:0] addr_1,
    input wire [4:0] addr_2,
    input wire [4:0] addr_3,
    input wire [31:0] write_data_3,
    output wire [31:0] read_data_1,
    output wire [31:0] read_data_2
);
    // 1. Declare the register array
    // Yosys (in OpenLane) will automatically map this to D-Flip-Flops (Standard Cells)
    reg [31:0] register_array [0:31];
    integer i;

    // 2. Synchronous Write Block
    always @(posedge clk) begin
        if (!rst) begin
            // Optional: Reset all registers to 0 (useful for clean simulation)
            for (i = 0; i < 32; i = i + 1) begin
                register_array[i] <= 32'd0;
            end
        end else begin
            // Only write if write_en_3 is HIGH and we are NOT writing to x0 (addr_3 != 0)
            if (write_en_3 && (addr_3 != 5'd0)) begin
                register_array[addr_3] <= write_data_3;
            end
        end
    end

    // 3. Combinational Read Block + Internal Bypassing
    // - If reading x0 (addr == 0), always return 0.
    // - If reading the same register that is currently being written, forward the new data immediately.
    // - Otherwise, read from the DFF array.
    
    assign read_data_1 = (addr_1 == 5'd0) ? 32'd0 : 
                         ((write_en_3 && (addr_1 == addr_3)) ? write_data_3 : register_array[addr_1]);

    assign read_data_2 = (addr_2 == 5'd0) ? 32'd0 : 
                         ((write_en_3 && (addr_2 == addr_3)) ? write_data_3 : register_array[addr_2]);

endmodule