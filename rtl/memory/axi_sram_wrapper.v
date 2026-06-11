module axi_sram_wrapper (
    input wire clk,
    input wire rst_n,

    // AXI4-Full Slave Interface - Write Channels
    input  wire [31:0] s_axi_awaddr,
    input  wire [7:0]  s_axi_awlen,
    input  wire [2:0]  s_axi_awsize,
    input  wire [1:0]  s_axi_awburst,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wlast,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // AXI4-Full Slave Interface - Read Channels
    input  wire [31:0] s_axi_araddr,
    input  wire [7:0]  s_axi_arlen,
    input  wire [2:0]  s_axi_arsize,
    input  wire [1:0]  s_axi_arburst,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rlast,
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
    assign sram_ben = (sram_r_wb) ? 32'h00000000 : { {8{~s_axi_wstrb[3]}}, {8{~s_axi_wstrb[2]}}, {8{~s_axi_wstrb[1]}}, {8{~s_axi_wstrb[0]}} };

    // FSM
    reg [1:0] state;
    localparam IDLE = 2'b00, WRITE = 2'b01, WRITE_RESP = 2'b10, READ = 2'b11;

    reg [7:0] r_cnt, w_cnt;
    reg [7:0] arlen_q, awlen_q;
    reg [31:0] next_r_addr, next_w_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sram_en <= 1'b0; sram_r_wb <= 1'b1; sram_ad <= 10'd0; sram_di <= 32'd0;
            r_cnt <= 0; w_cnt <= 0; arlen_q <= 0; awlen_q <= 0;
            next_r_addr <= 0; next_w_addr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        sram_en <= 1'b1; sram_r_wb <= 1'b0; // Write mode
                        sram_ad <= s_axi_awaddr[11:2]; sram_di <= s_axi_wdata;
                        awlen_q <= s_axi_awlen; w_cnt <= 0; next_w_addr <= s_axi_awaddr + 4;
                        if (s_axi_awlen == 0 || s_axi_wlast) state <= WRITE_RESP;
                        else state <= WRITE;
                    end else if (s_axi_arvalid) begin
                        sram_en <= 1'b1; sram_r_wb <= 1'b1; // Read mode
                        sram_ad <= s_axi_araddr[11:2];
                        arlen_q <= s_axi_arlen; r_cnt <= 0; next_r_addr <= s_axi_araddr + 4;
                        state <= READ;
                    end else begin
                        sram_en <= 1'b0;
                    end
                end
                WRITE: begin
                    if (s_axi_wvalid) begin
                        sram_en <= 1'b1; sram_r_wb <= 1'b0;
                        sram_ad <= next_w_addr[11:2]; sram_di <= s_axi_wdata;
                        next_w_addr <= next_w_addr + 4;
                        w_cnt <= w_cnt + 1;
                        if (w_cnt == awlen_q - 1 || s_axi_wlast) state <= WRITE_RESP;
                    end else begin
                        sram_en <= 1'b0;
                    end
                end
                WRITE_RESP: begin
                    sram_en <= 1'b0;
                    if (s_axi_bready) state <= IDLE;
                end
                READ: begin
                    // Proceed to next read address
                    if (r_cnt < arlen_q && s_axi_rready) begin
                        sram_en <= 1'b1; sram_r_wb <= 1'b1;
                        sram_ad <= next_r_addr[11:2];
                        next_r_addr <= next_r_addr + 4;
                    end else begin
                        sram_en <= 1'b0;
                    end
                    if (s_axi_rready) begin
                        if (r_cnt == arlen_q) state <= IDLE;
                        else r_cnt <= r_cnt + 1;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        s_axi_awready = 1'b0; s_axi_wready  = 1'b0; s_axi_bvalid  = 1'b0;
        s_axi_arready = 1'b0; s_axi_rvalid  = 1'b0; s_axi_bresp   = 2'b00;
        s_axi_rresp   = 2'b00; s_axi_rdata   = sram_do; s_axi_rlast = 1'b0;

        case (state)
            IDLE: begin
                if (s_axi_awvalid && s_axi_wvalid) begin
                    s_axi_awready = 1'b1; s_axi_wready  = 1'b1;
                end else if (s_axi_arvalid) begin
                    s_axi_arready = 1'b1;
                end
            end
            WRITE: begin
                s_axi_wready = 1'b1;
            end
            WRITE_RESP: begin
                s_axi_bvalid = 1'b1;
            end
            READ: begin
                s_axi_rvalid = 1'b1;
                if (r_cnt == arlen_q) s_axi_rlast = 1'b1;
            end
        endcase
    end
endmodule