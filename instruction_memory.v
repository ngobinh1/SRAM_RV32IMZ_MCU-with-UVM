module instruction_memory (
    input  rst,
    input  [31:0] addr,
    output  [31:0] read_data
);

    reg [31:0] mem [1023:0];
    integer i;

    initial begin
        // Initialize ALL memory to zero first
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h00000000;
        end

    $readmemh("full_test.hex", dut.fetch_stage.instruction_memory.mem);
    // $display("Memory[0] = %h", mem[0]); 
    // $display("Memory[1] = %h", mem[1]);
    // $display("Memory[2] = %h", mem[2]);
    // $display("Memory[3] = %h", mem[3]);
    // $display("Memory[4] = %h", mem[4]);
    // $display("Memory[5] = %h", mem[5]);
    // $display("Memory[6] = %h", mem[6]);
    // $display("Memory[7] = %h", mem[7]);
    // $display("Memory[9] = %h", mem[9]);
    // $display("Memory[10] = %h", mem[10]);
    // $display("Memory[11] = %h", mem[11]);
    // $display("Memory[12] = %h", mem[12]);
    // $display("Memory[13] = %h", mem[13]);
    // $display("Memory[14] = %h", mem[14]);
    // $display("Memory[15] = %h", mem[15]);
    // $display("Memory[16] = %h", mem[16]);
    // $display("Memory[17] = %h", mem[17]);
    // $display("Memory[18] = %h", mem[18]);
    // $display("Memory[19] = %h", mem[19]);
    // $display("Memory[20] = %h", mem[20]);
end

    assign read_data = (rst == 1'b0) ? 32'h00000000 : mem[addr[31:2]];

endmodule