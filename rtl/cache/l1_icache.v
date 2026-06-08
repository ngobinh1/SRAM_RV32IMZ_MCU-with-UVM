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
    // 8-Set, 2-Way Set Associative Cache (Total 16 lines)
    reg [31:0] cache_data  [0:7][0:1];
    reg [26:0] cache_tag   [0:7][0:1];
    reg        cache_valid [0:7][0:1];
    reg        lru_bit     [0:7]; // 0: way 0 is LRU, 1: way 1 is LRU

    // Address Breakdown (Word Aligned)
    wire [2:0]  index = cpu_addr[4:2];
    wire [26:0] tag   = cpu_addr[31:5];

    // Hit Logic
    wire hit_w0 = cache_valid[index][0] && (cache_tag[index][0] == tag);
    wire hit_w1 = cache_valid[index][1] && (cache_tag[index][1] == tag);
    wire hit    = hit_w0 || hit_w1;
    assign cpu_rdata = hit_w0 ? cache_data[index][0] : 
                       hit_w1 ? cache_data[index][1] : 32'h00000000;
    
    // FSM States
    localparam IDLE = 2'b00, AR_WAIT = 2'b01, R_WAIT = 2'b10;
    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Stall CPU when Cache miss or fetching
    assign icache_stall = (state == IDLE && !hit) || (state != IDLE);

    always @(*) begin
        next_state = state;
        m_axi_arvalid = 1'b0;
        m_axi_araddr  = 32'h0;
        m_axi_rready  = 1'b0;

        case (state)
            IDLE: begin
                if (!hit && rst_n) begin
                    m_axi_arvalid = 1'b1;
                    m_axi_araddr  = {tag, index, 2'b00};
                    if (m_axi_arready)
                        next_state = R_WAIT;
                    else
                        next_state = AR_WAIT;
                end
            end
            AR_WAIT: begin
                if (rst_n) begin
                    m_axi_arvalid = 1'b1;
                    m_axi_araddr  = {tag, index, 2'b00};
                    if (m_axi_arready) next_state = R_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            R_WAIT: begin
                if (rst_n) begin
                    m_axi_rready = 1'b1;
                    if (m_axi_rvalid) next_state = IDLE;
                end else begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Update Cache Memory
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                cache_valid[i][0] <= 1'b0;
                cache_valid[i][1] <= 1'b0;
                lru_bit[i] <= 1'b0;
            end
        end else if (state == R_WAIT && m_axi_rvalid) begin
            cache_valid[index][lru_bit[index]] <= 1'b1;
            cache_tag[index][lru_bit[index]]   <= tag;
            cache_data[index][lru_bit[index]]  <= m_axi_rdata;
            lru_bit[index] <= ~lru_bit[index];
        end else if (hit) begin
            if (hit_w0) lru_bit[index] <= 1'b1;
            if (hit_w1) lru_bit[index] <= 1'b0;
        end
    end
endmodule
