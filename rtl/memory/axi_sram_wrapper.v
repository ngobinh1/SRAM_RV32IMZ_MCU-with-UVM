module axi_sram_wrapper (
    input wire clk,
    input wire rst_n,

    // AXI4-Lite Slave Interface - Write Channels
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // AXI4-Lite Slave Interface - Read Channels
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // SRAM Macro Interface
    output reg  [9:0]  sram_ad,
    output reg  [31:0] sram_di,
    output wire [31:0] sram_ben,
    output reg         sram_en,
    output reg         sram_r_wb,
    input  wire [31:0] sram_do
);

    // Convert WSTRB (4-bit) to BEN (32-bit) for EF_SRAM
    assign sram_ben = {{8{s_axi_wstrb[3]}}, {8{s_axi_wstrb[2]}}, {8{s_axi_wstrb[1]}}, {8{s_axi_wstrb[0]}}};

    // FSM
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00, WRITE = 2'b01, READ_WAIT = 2'b10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(state or s_axi_awvalid or s_axi_wvalid or s_axi_arvalid or s_axi_awaddr or s_axi_wdata or s_axi_araddr or s_axi_bready or s_axi_rready or sram_do) begin
        // Default AXI
        s_axi_awready = 1'b0; s_axi_wready  = 1'b0; s_axi_bvalid  = 1'b0;
        s_axi_arready = 1'b0; s_axi_rvalid  = 1'b0; s_axi_bresp   = 2'b00; s_axi_rresp = 2'b00;
        
        // Default SRAM
        sram_en = 1'b0; sram_r_wb = 1'b1; sram_ad = 10'd0; sram_di = 32'd0;
        s_axi_rdata = sram_do;
        next_state = state;

        case (state)
            IDLE: begin
                if (s_axi_awvalid && s_axi_wvalid) begin
                    // Write Transaction
                    s_axi_awready = 1'b1;
                    s_axi_wready  = 1'b1;
                    sram_en       = 1'b1;
                    sram_r_wb     = 1'b0; // Write mode
                    sram_ad       = s_axi_awaddr[11:2]; // Map to Word address
                    sram_di       = s_axi_wdata;
                    next_state    = WRITE;
                end 
                else if (s_axi_arvalid) begin
                    // Read Transaction
                    s_axi_arready = 1'b1;
                    sram_en       = 1'b1;
                    sram_r_wb     = 1'b1; // Read mode
                    sram_ad       = s_axi_araddr[11:2];
                    next_state    = READ_WAIT;
                end
            end

            WRITE: begin
                s_axi_bvalid = 1'b1;
                if (s_axi_bready) next_state = IDLE;
            end

            READ_WAIT: begin
                // SRAM delivers results in the next cycle.
                s_axi_rvalid = 1'b1;
                if (s_axi_rready) next_state = IDLE;
            end
        endcase
    end
endmodule