module axi4_full_master #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,

    // User Interface
    input wire start,
    input wire rw, // 0 for read, 1 for write
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [7:0] len,
    input wire [DATA_WIDTH-1:0] wdata_in,
    output reg [DATA_WIDTH-1:0] rdata_out,
    output reg rdata_valid,
    output reg done,
    output reg error,

    // AXI4 Full Master Interface
    // Write Address Channel
    output reg [ID_WIDTH-1:0] m_axi_awid,
    output reg [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg [7:0] m_axi_awlen,
    output reg [2:0] m_axi_awsize,
    output reg [1:0] m_axi_awburst,
    output reg m_axi_awvalid,
    input wire m_axi_awready,

    // Write Data Channel
    output reg [DATA_WIDTH-1:0] m_axi_wdata,
    output reg [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output reg m_axi_wlast,
    output reg m_axi_wvalid,
    input wire m_axi_wready,

    // Write Response Channel
    input wire [ID_WIDTH-1:0] m_axi_bid,
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output reg m_axi_bready,

    // Read Address Channel
    output reg [ID_WIDTH-1:0] m_axi_arid,
    output reg [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg [7:0] m_axi_arlen,
    output reg [2:0] m_axi_arsize,
    output reg [1:0] m_axi_arburst,
    output reg m_axi_arvalid,
    input wire m_axi_arready,

    // Read Data Channel
    input wire [ID_WIDTH-1:0] m_axi_rid,
    input wire [DATA_WIDTH-1:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output reg m_axi_rready
);

    // FSM States
    localparam IDLE = 3'd0;
    localparam WA_WAIT = 3'd1;
    localparam W_WAIT = 3'd2;
    localparam B_WAIT = 3'd3;
    localparam RA_WAIT = 3'd4;
    localparam R_WAIT = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] burst_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            burst_count <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            rdata_valid <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            rdata_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        burst_count <= len;
                        error <= 1'b0;
                    end
                end
                W_WAIT: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        if (burst_count > 0)
                            burst_count <= burst_count - 1;
                    end
                end
                B_WAIT: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        done <= 1'b1;
                        if (m_axi_bresp != 2'b00) error <= 1'b1;
                    end
                end
                R_WAIT: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        rdata_out <= m_axi_rdata;
                        rdata_valid <= 1'b1;
                        if (m_axi_rresp != 2'b00) error <= 1'b1;
                        if (m_axi_rlast) done <= 1'b1;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        m_axi_awvalid = 1'b0;
        m_axi_wvalid = 1'b0;
        m_axi_wlast = 1'b0;
        m_axi_bready = 1'b0;
        m_axi_arvalid = 1'b0;
        m_axi_rready = 1'b0;

        m_axi_awid = 0;
        m_axi_awaddr = addr;
        m_axi_awlen = len;
        m_axi_awsize = 3'b010; // 4 bytes
        m_axi_awburst = 2'b01; // INCR
        m_axi_wdata = wdata_in;
        m_axi_wstrb = 4'hF;
        
        m_axi_arid = 0;
        m_axi_araddr = addr;
        m_axi_arlen = len;
        m_axi_arsize = 3'b010;
        m_axi_arburst = 2'b01;

        case (state)
            IDLE: begin
                if (start) begin
                    if (rw) next_state = WA_WAIT; // Write
                    else next_state = RA_WAIT;    // Read
                end
            end
            WA_WAIT: begin
                m_axi_awvalid = 1'b1;
                if (m_axi_awready) next_state = W_WAIT;
            end
            W_WAIT: begin
                m_axi_wvalid = 1'b1;
                if (burst_count == 0) m_axi_wlast = 1'b1;
                if (m_axi_wready) begin
                    if (burst_count == 0) next_state = B_WAIT;
                end
            end
            B_WAIT: begin
                m_axi_bready = 1'b1;
                if (m_axi_bvalid) next_state = IDLE;
            end
            RA_WAIT: begin
                m_axi_arvalid = 1'b1;
                if (m_axi_arready) next_state = R_WAIT;
            end
            R_WAIT: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid && m_axi_rlast) next_state = IDLE;
            end
        endcase
    end
endmodule
