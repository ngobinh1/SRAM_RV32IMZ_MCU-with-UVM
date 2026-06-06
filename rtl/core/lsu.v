module lsu (
    // Inputs for Address Generation
    input  wire [31:0] addr_in,
    
    // Inputs for Control
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  funct3,
    
    // Data from Core
    input  wire [31:0] store_data_in,
    
    // Data from Memory/Cache
    input  wire [31:0] rdata_from_cache,
    
    // Outputs to Memory/Cache
    output wire [31:0] effective_addr,
    output wire [3:0]  byte_enable,
    output wire [31:0] store_data_aligned,
    
    // Outputs to Core (Writeback)
    output reg  [31:0] load_data_extracted,
    
    // Exception Generation
    output wire        load_misaligned,
    output wire        store_misaligned
);

    // 1. Address Generation
    assign effective_addr = addr_in;
    
    wire [1:0] offset = effective_addr[1:0];
    
    // 7. Alignment Check
    wire is_word = (funct3 == 3'b010);
    wire is_halfword = (funct3 == 3'b001) || (funct3 == 3'b101);
    
    wire misaligned = (is_word && (offset != 2'b00)) || 
                      (is_halfword && (offset[0] != 1'b0));
                      
    assign load_misaligned  = mem_read  && misaligned;
    assign store_misaligned = mem_write && misaligned;

    // 2. Byte Lane Decode (byte_enable)
    reg [3:0] be;
    always @(*) begin
        if ((mem_write && !store_misaligned) || (mem_read && !load_misaligned)) begin
            case (funct3[1:0])
                2'b00: begin // Byte
                    case (offset)
                        2'b00: be = 4'b0001;
                        2'b01: be = 4'b0010;
                        2'b10: be = 4'b0100;
                        2'b11: be = 4'b1000;
                    endcase
                end
                2'b01: begin // Halfword
                    case (offset[1])
                        1'b0: be = 4'b0011;
                        1'b1: be = 4'b1100;
                    endcase
                end
                2'b10: begin // Word
                    be = 4'b1111;
                end
                default: be = 4'b0000;
            endcase
        end else begin
            be = 4'b0000;
        end
    end
    assign byte_enable = be;

    // 3. Store Data Alignment
    reg [31:0] aligned_store;
    always @(*) begin
        case (funct3)
            3'b000: begin // SB
                aligned_store = {store_data_in[7:0], store_data_in[7:0], store_data_in[7:0], store_data_in[7:0]};
            end
            3'b001: begin // SH
                aligned_store = {store_data_in[15:0], store_data_in[15:0]};
            end
            3'b010: begin // SW
                aligned_store = store_data_in;
            end
            default: aligned_store = store_data_in;
        endcase
    end
    assign store_data_aligned = aligned_store;

    // 4, 5, 6. Load Data Extraction & Extension
    reg [7:0] byte_data;
    reg [15:0] halfword_data;
    
    always @(*) begin
        // Byte extraction
        case (offset)
            2'b00: byte_data = rdata_from_cache[7:0];
            2'b01: byte_data = rdata_from_cache[15:8];
            2'b10: byte_data = rdata_from_cache[23:16];
            2'b11: byte_data = rdata_from_cache[31:24];
        endcase
        
        // Halfword extraction
        case (offset)
            2'b00: halfword_data = rdata_from_cache[15:0];
            2'b10: halfword_data = rdata_from_cache[31:16];
            default: halfword_data = 16'h0000;
        endcase
        
        // Output MUX with Extension
        case (funct3)
            3'b000: load_data_extracted = {{24{byte_data[7]}}, byte_data};          // LB
            3'b001: load_data_extracted = {{16{halfword_data[15]}}, halfword_data}; // LH
            3'b010: load_data_extracted = rdata_from_cache;                         // LW
            3'b100: load_data_extracted = {24'b0, byte_data};                       // LBU
            3'b101: load_data_extracted = {16'b0, halfword_data};                   // LHU
            default: load_data_extracted = rdata_from_cache;
        endcase
    end

endmodule
