module l1_icache (
    input  wire        clk, rst_n,
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output wire [31:0] cpu_rdata,
    output wire        icache_stall,

    // AXI4-Lite Master Read Interface
    output reg  [31:0] m_axi_araddr,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready
);
    // 16-line Direct Mapped Cache
    reg [31:0] cache_data  [0:15];
    reg [25:0] cache_tag   [0:15];
    reg        cache_valid [0:15];

    // Address Breakdown (Word Aligned)
    wire [3:0]  index = cpu_addr[5:2];
    wire [25:0] tag   = cpu_addr[31:6];

    // Hit Logic
    wire hit = cache_valid[index] && (cache_tag[index] == tag);
    assign cpu_rdata = hit ? cache_data[index] : 32'h00000000;
    
    // FSM States
    localparam IDLE = 2'b00, AR_WAIT = 2'b01, R_WAIT = 2'b10;
    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Stall CPU khi Cache miss hoặc đang fetch
    assign icache_stall = (state == IDLE && !hit) || (state != IDLE);

    always @(state or hit or tag or index or m_axi_arready or m_axi_rvalid) begin
        next_state = state;
        m_axi_arvalid = 1'b0;
        m_axi_araddr  = 32'h0;
        m_axi_rready  = 1'b0;

        case (state)
            IDLE: begin
                if (!hit) begin
                    m_axi_arvalid = 1'b1;
                    m_axi_araddr  = {tag, index, 2'b00};
                    if (m_axi_arready)
                        next_state = R_WAIT;
                    else
                        next_state = AR_WAIT;
                end
            end
            AR_WAIT: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = {tag, index, 2'b00};
                if (m_axi_arready) next_state = R_WAIT;
            end
            R_WAIT: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid) next_state = IDLE;
            end
        endcase
    end

    // Update Cache Memory
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                cache_valid[i] <= 1'b0;
            end
        end else if (state == R_WAIT && m_axi_rvalid) begin
            cache_valid[index] <= 1'b1;
            cache_tag[index]   <= tag;
            cache_data[index]  <= m_axi_rdata;
        end
    end
endmodule