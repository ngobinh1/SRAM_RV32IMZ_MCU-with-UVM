module memory_cycle (
    input wire clk, rst,
    input wire mem_write_m,
    input wire [31:0] alu_result_m, write_data_m,
    input wire [2:0] funct3_m,
    input wire [31:0] read_data_m_in,
    output [31:0] read_data_m,
    output [31:0] write_data_m_out // [QUAN TRỌNG] Cổng mới thêm để xuất dữ liệu đã căn lề cho D-Cache
);

    // Tính toán số bit cần dịch dựa trên 2 bit cuối của địa chỉ
    // byte_offset = 0, 1, 2, 3 -> shift_amt = 0, 8, 16, 24
    wire [1:0] byte_offset = alu_result_m[1:0];
    wire [4:0] shift_amt = {byte_offset, 3'b000}; 

    // =========================================================================
    // 1. DATA ALIGNMENT CHO LỆNH STORE (sb, sh, sw)
    // =========================================================================
    reg [31:0] aligned_write_data;
    
    always @(funct3_m or shift_amt or write_data_m) begin
        case (funct3_m)
            3'b000:  aligned_write_data = write_data_m << shift_amt; // sb (Store Byte)
            3'b001:  aligned_write_data = write_data_m << shift_amt; // sh (Store Halfword)
            3'b010:  aligned_write_data = write_data_m;              // sw (Store Word)
            default: aligned_write_data = write_data_m;
        endcase
    end
    assign write_data_m_out = aligned_write_data;

    // =========================================================================
    // 2. DATA EXTENSION CHO LỆNH LOAD (lb, lh, lw, lbu, lhu)
    // =========================================================================
    reg [31:0] processed_read_data;
    wire [31:0] shifted_read_data = read_data_m_in >> shift_amt;

    always @(funct3_m or read_data_m_in or shifted_read_data) begin
        case (funct3_m)
            3'b000: // lb (Load Byte - Sign extend)
                processed_read_data = {{24{shifted_read_data[7]}}, shifted_read_data[7:0]};
            3'b001: // lh (Load Halfword - Sign extend)
                processed_read_data = {{16{shifted_read_data[15]}}, shifted_read_data[15:0]};
            3'b010: // lw (Load Word - Không cần dịch)
                processed_read_data = read_data_m_in;
            3'b100: // lbu (Load Byte Unsigned - Zero extend)
                processed_read_data = {24'b0, shifted_read_data[7:0]};
            3'b101: // lhu (Load Halfword Unsigned - Zero extend)
                processed_read_data = {16'b0, shifted_read_data[15:0]};
            default: 
                processed_read_data = read_data_m_in;
        endcase
    end
    assign read_data_m = processed_read_data;

endmodule