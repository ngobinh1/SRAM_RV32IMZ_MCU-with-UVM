module sram_arbiter (
    input wire clk,
    input wire rst_n,

    // Interface with I-Cache
    input  wire        i_req,
    input  wire [31:0] i_addr,
    output reg  [31:0] i_rdata,
    output reg         i_ready,

    // Interface with D-Cache
    input  wire        d_req,
    input  wire        d_we,
    input  wire [31:0] d_ben, // 32-bit Byte Enable (Generated from L1 D-Cache based on funct3)
    input  wire [31:0] d_addr,
    input  wire [31:0] d_wdata,
    output reg  [31:0] d_rdata,
    output reg         d_ready,

    // Direct interface with EF_SRAM_1024x32
    output reg  [9:0]  sram_ad,
    output reg  [31:0] sram_di,
    output reg  [31:0] sram_ben,
    output reg         sram_en,
    output reg         sram_r_wb, // 1: Read, 0: Write
    input  wire [31:0] sram_do
);

    localparam IDLE = 1'b0, WAIT_READ = 1'b1;
    reg state, next_state;
    reg current_master; // 0: I-Cache, 1: D-Cache

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(state or i_req or d_req or d_we or i_addr or d_addr or d_wdata or d_ben or sram_do) begin
        // Default values to keep SRAM disabled and nothing ready
        next_state = state;
        sram_en = 0; sram_r_wb = 1; 
        sram_ad = 0; sram_di = 0; sram_ben = 32'hFFFFFFFF;
        i_ready = 0; d_ready = 0;
        
        case (state)
            IDLE: begin
                if (d_req) begin
                    current_master = 1'b1;
                    sram_en = 1'b1;
                    sram_ad = d_addr[11:2]; // 10-bit Word address
                    sram_r_wb = ~d_we;
                    sram_di = d_wdata;
                    sram_ben = d_ben;

                    if (!d_we) next_state = WAIT_READ; // Reading takes 1 cycle
                    else       d_ready = 1'b1;         // Writing completes immediately at the next rising edge
                end 
                else if (i_req) begin
                    current_master = 1'b0;
                    sram_en = 1'b1;
                    sram_ad = i_addr[11:2]; // I-Cache addr
                    sram_r_wb = 1'b1;
                    sram_ben = 32'hFFFFFFFF; // I-Cache always reads the full 32 bits
                    next_state = WAIT_READ;
                end
            end

            WAIT_READ: begin
                // Read data returns in this cycle
                if (current_master) begin
                    d_rdata = sram_do;
                    d_ready = 1'b1;
                end else begin
                    i_rdata = sram_do;
                    i_ready = 1'b1;
                end
                next_state = IDLE;
            end
        endcase
    end
endmodule