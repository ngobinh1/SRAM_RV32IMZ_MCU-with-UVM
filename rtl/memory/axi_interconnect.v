// BANDWIDTH NOTE: Single-slave configuration. I-Cache and D-Cache share
// one 32-bit AXI path to SRAM. Maximum sustained throughput = 1 access/cycle.
// For higher bandwidth, replace with dual-port SRAM or add a second slave port.
module axi_interconnect (
    input wire clk, rst_n,

    // Master 0 (I-Cache)
    input  wire [31:0] m0_araddr, input wire m0_arvalid, output wire m0_arready,
    input  wire [7:0]  m0_arlen, input wire [2:0] m0_arsize, input wire [1:0] m0_arburst,
    output wire [31:0] m0_rdata,  output wire [1:0] m0_rresp, output wire m0_rvalid, input wire m0_rready, output wire m0_rlast,

    // Master 1 (D-Cache)
    input  wire [31:0] m1_awaddr, input wire m1_awvalid, output wire m1_awready,
    input  wire [7:0]  m1_awlen, input wire [2:0] m1_awsize, input wire [1:0] m1_awburst,
    input  wire [31:0] m1_wdata,  input wire [3:0] m1_wstrb, input wire m1_wvalid, output wire m1_wready, input wire m1_wlast,
    output wire [1:0]  m1_bresp,  output wire m1_bvalid, input wire m1_bready,
    input  wire [31:0] m1_araddr, input wire m1_arvalid, output wire m1_arready,
    input  wire [7:0]  m1_arlen, input wire [2:0] m1_arsize, input wire [1:0] m1_arburst,
    output wire [31:0] m1_rdata,  output wire [1:0] m1_rresp, output wire m1_rvalid, input wire m1_rready, output wire m1_rlast,

    // Slave 0 (SRAM)
    output wire [31:0] s0_awaddr, output wire s0_awvalid, input wire s0_awready,
    output wire [7:0]  s0_awlen, output wire [2:0] s0_awsize, output wire [1:0] s0_awburst,
    output wire [31:0] s0_wdata,  output wire [3:0] s0_wstrb, output wire s0_wvalid, input wire s0_wready, output wire s0_wlast,
    input  wire [1:0]  s0_bresp,  input wire s0_bvalid, output wire s0_bready,
    output wire [31:0] s0_araddr, output wire s0_arvalid, input wire s0_arready,
    output wire [7:0]  s0_arlen, output wire [2:0] s0_arsize, output wire [1:0] s0_arburst,
    input  wire [31:0] s0_rdata,  input wire [1:0] s0_rresp, input wire s0_rvalid, output wire s0_rready, input wire s0_rlast
);
    // ------------------------------------------------------------------------
    // Write Channels (AW, W, B) transform data from D-Cache (M1) to SRAM (S0)
    // ------------------------------------------------------------------------
    assign s0_awaddr  = m1_awaddr;  assign s0_awvalid = m1_awvalid; assign m1_awready = s0_awready;
    assign s0_awlen   = m1_awlen;   assign s0_awsize  = m1_awsize;  assign s0_awburst = m1_awburst;
    assign s0_wdata   = m1_wdata;   assign s0_wstrb   = m1_wstrb;   assign s0_wvalid  = m1_wvalid; assign m1_wready = s0_wready;
    assign s0_wlast   = m1_wlast;
    assign m1_bresp   = s0_bresp;   assign m1_bvalid  = s0_bvalid;  assign s0_bready  = m1_bready;

    // ------------------------------------------------------------------------
    // Arbitration for Read Channels (AR, R) - Prioritize D-Cache when there are conflicts
    // ------------------------------------------------------------------------
    wire m1_req = m1_arvalid;
    wire m0_req = m0_arvalid & ~m1_arvalid;

    reg current_r_owner; // 0 = M0 (I-Cache), 1 = M1 (D-Cache)
    
    // Lock owner during active R phase
    reg r_busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_r_owner <= 1'b0;
            r_busy <= 1'b0;
        end else begin
            if (s0_arvalid && s0_arready) begin
                current_r_owner <= m1_req ? 1'b1 : 1'b0;
                r_busy <= 1'b1;
            end
            if (s0_rvalid && s0_rready && s0_rlast) begin
                r_busy <= 1'b0;
            end
        end
    end

    wire block_new_ar = r_busy;

    // Read Channel (AR)
    assign s0_araddr  = m1_req ? m1_araddr : m0_araddr;
    assign s0_arlen   = m1_req ? m1_arlen : m0_arlen;
    assign s0_arsize  = m1_req ? m1_arsize : m0_arsize;
    assign s0_arburst = m1_req ? m1_arburst : m0_arburst;
    assign s0_arvalid = block_new_ar ? 1'b0 : (m1_req ? m1_arvalid : (m0_req ? m0_arvalid : 1'b0));
    assign m1_arready = m1_req ? s0_arready : 1'b0;
    assign m0_arready = m0_req ? s0_arready : 1'b0;

    // Data Channel (R) - Return results to the correct owner
    assign m1_rdata  = s0_rdata; assign m1_rresp  = s0_rresp; assign m1_rlast = s0_rlast;
    assign m0_rdata  = s0_rdata; assign m0_rresp  = s0_rresp; assign m0_rlast = s0_rlast;
    
    assign m1_rvalid = s0_rvalid & (current_r_owner == 1'b1);
    assign m0_rvalid = s0_rvalid & (current_r_owner == 1'b0);
    assign s0_rready = (current_r_owner == 1'b1) ? m1_rready : m0_rready;

   // synthesis translate_off
   // pragma coverage off
   property no_dual_arready;
     @(posedge clk) disable iff (!rst_n)
     !(m0_arready && m1_arready);
   endproperty
   assert property (no_dual_arready)
     else $error("[AXI_IC] Dual arready asserted simultaneously — arbitration error");

   property arvalid_stable_until_ready_m0;
     @(posedge clk) disable iff (!rst_n)
     (m0_arvalid && !m0_arready) |=> m0_arvalid;
   endproperty
   assert property (arvalid_stable_until_ready_m0)
     else $error("[AXI_IC] m0_arvalid dropped before m0_arready — transaction lost");
   // pragma coverage on
   // synthesis translate_on

endmodule