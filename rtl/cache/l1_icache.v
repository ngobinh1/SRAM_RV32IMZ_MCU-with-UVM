module l1_icache (
    input  wire        clk, rst_n,
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output wire [31:0] cpu_rdata,
    output wire        icache_stall,

    // AXI4-Full Master Read Interface
    output wire [31:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready
);
    // 8-Set, 2-Way Set Associative Cache, 128-bit Cache Line (4 Words)
    reg [127:0] cache_data  [0:7][0:1];
    reg [24:0]  cache_tag   [0:7][0:1];
    reg         cache_valid [0:7][0:1];
    reg         lru_bit     [0:7]; // 0: way 0 is LRU, 1: way 1 is LRU

    // Address Breakdown
    wire [1:0]  word_sel = cpu_addr[3:2];
    wire [2:0]  index    = cpu_addr[6:4];
    wire [24:0] tag      = cpu_addr[31:7];

    // Hit Logic
    wire hit_w0 = cache_valid[index][0] && (cache_tag[index][0] == tag);
    wire hit_w1 = cache_valid[index][1] && (cache_tag[index][1] == tag);
    wire hit    = hit_w0 || hit_w1;
    
    wire [127:0] hit_line = hit_w0 ? cache_data[index][0] : 
                            hit_w1 ? cache_data[index][1] : 128'd0;
    
    assign cpu_rdata = (word_sel == 2'b11) ? hit_line[127:96] :
                       (word_sel == 2'b10) ? hit_line[95:64]  :
                       (word_sel == 2'b01) ? hit_line[63:32]  :
                                             hit_line[31:0];
    
    // AXI4 Master Integration
    reg start_read;
    wire done;
    wire [31:0] master_rdata;
    wire master_rdata_valid;

    axi4_full_master #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4)
    ) master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_read),
        .rw(1'b0), // 0 = read
        .addr({tag, index, 4'b0000}),
        .len(8'd3), // 4 beats
        .wdata_in(32'h0),
        .rdata_out(master_rdata),
        .rdata_valid(master_rdata_valid),
        .done(done),
        .error(),
        
        .m_axi_awid(), .m_axi_awaddr(), .m_axi_awlen(), .m_axi_awsize(), .m_axi_awburst(), .m_axi_awvalid(), .m_axi_awready(1'b0),
        .m_axi_wdata(), .m_axi_wstrb(), .m_axi_wlast(), .m_axi_wvalid(), .m_axi_wready(1'b0),
        .m_axi_bid(4'h0), .m_axi_bresp(2'h0), .m_axi_bvalid(1'b0), .m_axi_bready(),
        
        .m_axi_arid(),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(4'h0),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    // FSM States
    localparam IDLE = 1'b0, WAIT_REFILL = 1'b1;
    reg state, next_state;
    
    // Refill buffer
    reg [127:0] refill_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    assign icache_stall = (state == IDLE && !hit) || (state != IDLE);

    always @(*) begin
        next_state = state;
        start_read = 1'b0;

        case (state)
            IDLE: begin
                if (!hit && rst_n) begin
                    start_read = 1'b1;
                    next_state = WAIT_REFILL;
                end
            end
            WAIT_REFILL: begin
                if (done) next_state = IDLE;
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
            refill_buf <= 128'h0;
        end else begin
            if (master_rdata_valid) begin
                refill_buf <= {master_rdata, refill_buf[127:32]};
            end
            if (done) begin
                cache_valid[index][lru_bit[index]] <= 1'b1;
                cache_tag[index][lru_bit[index]]   <= tag;
                cache_data[index][lru_bit[index]]  <= {master_rdata, refill_buf[127:32]};
                lru_bit[index] <= ~lru_bit[index];
            end else if (hit && state == IDLE) begin
                if (hit_w0) lru_bit[index] <= 1'b1;
                if (hit_w1) lru_bit[index] <= 1'b0;
            end
        end
    end
endmodule
