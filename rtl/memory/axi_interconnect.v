module axi_interconnect (
    input wire clk, rst_n,

    // Master 0 (I-Cache) - Only Read
    input  wire [31:0] m0_araddr, input wire m0_arvalid, output wire m0_arready,
    output wire [31:0] m0_rdata,  output wire [1:0] m0_rresp, output wire m0_rvalid, input wire m0_rready,

    // Master 1 (D-Cache) - Read/Write
    input  wire [31:0] m1_awaddr, input wire m1_awvalid, output wire m1_awready,
    input  wire [31:0] m1_wdata,  input wire [3:0] m1_wstrb, input wire m1_wvalid, output wire m1_wready,
    output wire [1:0]  m1_bresp,  output wire m1_bvalid, input wire m1_bready,
    input  wire [31:0] m1_araddr, input wire m1_arvalid, output wire m1_arready,
    output wire [31:0] m1_rdata,  output wire [1:0] m1_rresp, output wire m1_rvalid, input wire m1_rready,

    // Slave 0 (SRAM)
    output wire [31:0] s0_awaddr, output wire s0_awvalid, input wire s0_awready,
    output wire [31:0] s0_wdata,  output wire [3:0] s0_wstrb, output wire s0_wvalid, input wire s0_wready,
    input  wire [1:0]  s0_bresp,  input wire s0_bvalid, output wire s0_bready,
    output wire [31:0] s0_araddr, output wire s0_arvalid, input wire s0_arready,
    input  wire [31:0] s0_rdata,  input wire [1:0] s0_rresp, input wire s0_rvalid, output wire s0_rready
);
    // ------------------------------------------------------------------------
    // Write Channels (AW, W, B) transform data from D-Cache (M1) to SRAM (S0)
    // ------------------------------------------------------------------------
    assign s0_awaddr  = m1_awaddr;  assign s0_awvalid = m1_awvalid; assign m1_awready = s0_awready;
    assign s0_wdata   = m1_wdata;   assign s0_wstrb   = m1_wstrb;   assign s0_wvalid  = m1_wvalid; assign m1_wready = s0_wready;
    assign m1_bresp   = s0_bresp;   assign m1_bvalid  = s0_bvalid;  assign s0_bready  = m1_bready;

    // ------------------------------------------------------------------------
    // Arbitration for Read Channels (AR, R) - Prioritize D-Cache when there are conflicts
    // ------------------------------------------------------------------------
    wire m1_req = m1_arvalid;
    wire m0_req = m0_arvalid & ~m1_arvalid;

    reg current_r_owner; // 0 = M0 (I-Cache), 1 = M1 (D-Cache)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_r_owner <= 1'b0;
        else if (s0_arvalid && s0_arready) current_r_owner <= m1_req ? 1'b1 : 1'b0;
    end

    // Read Channel (AR)
    assign s0_araddr  = m1_req ? m1_araddr : m0_araddr;
    assign s0_arvalid = m1_req ? m1_arvalid : m0_req ? m0_arvalid : 1'b0;
    assign m1_arready = m1_req ? s0_arready : 1'b0;
    assign m0_arready = m0_req ? s0_arready : 1'b0;

    // Data Channel (R) - Return results to the correct owner
    assign m1_rdata  = s0_rdata; assign m1_rresp  = s0_rresp;
    assign m0_rdata  = s0_rdata; assign m0_rresp  = s0_rresp;
    
    assign m1_rvalid = s0_rvalid & (current_r_owner == 1'b1);
    assign m0_rvalid = s0_rvalid & (current_r_owner == 1'b0);
    assign s0_rready = (current_r_owner == 1'b1) ? m1_rready : m0_rready;

endmodule