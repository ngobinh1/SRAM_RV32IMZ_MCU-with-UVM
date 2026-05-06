module data_memory (
    input wire clk, rst, write_en,
    input wire [31:0] addr, write_data,
    input wire [2:0] funct3,
    output reg [31:0] read_data 
);
    reg [31:0] mem [1023:0];
    integer i;

    // Initialize ALL memory locations to zero
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
    end

    wire [31:0] word = mem[addr[31:2]]; // Read the entire word from memory (aligned to 4 bytes)
    wire [1:0] byte_offset = addr[1:0]; // Locate the byte within word

    // ---------------- LOGIC LOAD ----------------
    always @(funct3 or word or byte_offset) begin
        if (!rst) read_data = 32'd0;
        else begin
            case(funct3)
                3'b000: begin // lb (Load Byte - Sign Extend)
                    case(byte_offset)
                        2'b00: read_data = {{24{word[7]}}, word[7:0]};
                        2'b01: read_data = {{24{word[15]}}, word[15:8]};
                        2'b10: read_data = {{24{word[23]}}, word[23:16]};
                        2'b11: read_data = {{24{word[31]}}, word[31:24]};
                    endcase
                end
                3'b100: begin // lbu (Load Byte Unsigned - Zero Extend)
                    case(byte_offset)
                        2'b00: read_data = {24'd0, word[7:0]};
                        2'b01: read_data = {24'd0, word[15:8]};
                        2'b10: read_data = {24'd0, word[23:16]};
                        2'b11: read_data = {24'd0, word[31:24]};
                    endcase
                end
                3'b001: begin // lh (Load Halfword - Sign Extend)
                    if (byte_offset[1] == 1'b0) read_data = {{16{word[15]}}, word[15:0]};
                    else                        read_data = {{16{word[31]}}, word[31:16]};
                end
                3'b101: begin // lhu (Load Halfword Unsigned - Zero Extend)
                    if (byte_offset[1] == 1'b0) read_data = {16'd0, word[15:0]};
                    else                        read_data = {16'd0, word[31:16]};
                end
                3'b010: read_data = word; // lw (Load Word)
                default: read_data = 32'd0;
            endcase
        end
    end

    // ---------------- LOGIC STORE ----------------
    always @(posedge clk) begin
        if (write_en) begin
            case(funct3)
                3'b000: begin // sb (Store Byte)
                    case(byte_offset)
                        2'b00: mem[addr[31:2]][7:0]   <= write_data[7:0];
                        2'b01: mem[addr[31:2]][15:8]  <= write_data[7:0];
                        2'b10: mem[addr[31:2]][23:16] <= write_data[7:0];
                        2'b11: mem[addr[31:2]][31:24] <= write_data[7:0];
                    endcase
                end
                3'b001: begin // sh (Store Halfword)
                    if (byte_offset[1] == 1'b0) mem[addr[31:2]][15:0]  <= write_data[15:0];
                    else                        mem[addr[31:2]][31:16] <= write_data[15:0];
                end
                3'b010: mem[addr[31:2]] <= write_data; // sw (Store Word)
            endcase
        end
    end
endmodule