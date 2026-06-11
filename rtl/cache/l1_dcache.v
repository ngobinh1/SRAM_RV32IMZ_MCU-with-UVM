module l1_dcache (
    input  wire        clk, rst_n,
    
    // CPU interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    input  wire [2:0]  cpu_funct3,
    output wire [31:0] cpu_rdata,
    output wire        dcache_stall,

    // AXI4-Full Master Interface
    output wire [31:0] m_axi_awaddr,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,

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
    // 8-Set, 2-Way Set Associative Write-Back Cache, 128-bit Cache Line
    reg [127:0] cache_data  [0:7][0:1];
    reg [24:0]  cache_tag   [0:7][0:1];
    reg         cache_valid [0:7][0:1];
    reg         cache_dirty [0:7][0:1];
    reg         lru_bit     [0:7];

    wire [1:0]  word_sel = cpu_addr[3:2];
    wire [2:0]  index    = cpu_addr[6:4];
    wire [24:0] tag      = cpu_addr[31:7];
    wire [1:0]  offset   = cpu_addr[1:0];

    wire hit_w0 = cache_valid[index][0] && (cache_tag[index][0] == tag);
    wire hit_w1 = cache_valid[index][1] && (cache_tag[index][1] == tag);
    wire hit    = hit_w0 || hit_w1;
    
    wire current_way = hit_w0 ? 1'b0 : 
                       hit_w1 ? 1'b1 : lru_bit[index];

    wire [127:0] hit_line = hit_w0 ? cache_data[index][0] :
                            hit_w1 ? cache_data[index][1] : 128'h0;

    assign cpu_rdata = (word_sel == 2'b11) ? hit_line[127:96] :
                       (word_sel == 2'b10) ? hit_line[95:64]  :
                       (word_sel == 2'b01) ? hit_line[63:32]  :
                                             hit_line[31:0];

    // Decode CPU funct3 and offset into a 32-bit Write Mask
    reg [31:0] write_mask_32;
    always @(*) begin
        write_mask_32 = 32'h00000000;
        if (cpu_funct3 == 3'b000) begin // SB
            if (offset == 2'b00) write_mask_32 = 32'h000000FF;
            else if (offset == 2'b01) write_mask_32 = 32'h0000FF00;
            else if (offset == 2'b10) write_mask_32 = 32'h00FF0000;
            else if (offset == 2'b11) write_mask_32 = 32'hFF000000;
        end
        else if (cpu_funct3 == 3'b001) begin // SH
            if (offset[1] == 1'b0) write_mask_32 = 32'h0000FFFF;
            else                   write_mask_32 = 32'hFFFF0000;
        end
        else begin // SW
            write_mask_32 = 32'hFFFFFFFF;
        end
    end

    wire [127:0] full_write_mask = (word_sel == 2'b11) ? {write_mask_32, 96'd0} :
                                   (word_sel == 2'b10) ? {32'd0, write_mask_32, 64'd0} :
                                   (word_sel == 2'b01) ? {64'd0, write_mask_32, 32'd0} :
                                                         {96'd0, write_mask_32};
                                                         
    wire [127:0] full_cpu_wdata  = (word_sel == 2'b11) ? {cpu_wdata, 96'd0} :
                                   (word_sel == 2'b10) ? {32'd0, cpu_wdata, 64'd0} :
                                   (word_sel == 2'b01) ? {64'd0, cpu_wdata, 32'd0} :
                                                         {96'd0, cpu_wdata};

    wire valid_request = cpu_we || cpu_re;
    wire cache_miss = valid_request && !hit;
    wire line_dirty = cache_dirty[index][lru_bit[index]];
    wire [127:0] evict_data = cache_data[index][lru_bit[index]];

    // FSM States
    localparam IDLE = 2'd0, EVICT = 2'd1, REFILL = 2'd2;
    reg [1:0] state, next_state;

    // Control signals for AXI Master
    reg start_txn;
    reg rw_txn; // 0=read, 1=write
    reg [31:0] addr_txn;
    wire done;
    wire [31:0] master_rdata;
    wire master_rdata_valid;

    // Write word count logic to feed the correct 32-bit chunk to axi4_full_master
    reg [1:0] write_word_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) write_word_cnt <= 2'b00;
        else if (state == EVICT) begin
            if (m_axi_wvalid && m_axi_wready) write_word_cnt <= write_word_cnt + 1;
        end else begin
            write_word_cnt <= 2'b00;
        end
    end

    wire [31:0] wdata_in = (write_word_cnt == 2'b11) ? evict_data[127:96] :
                           (write_word_cnt == 2'b10) ? evict_data[95:64]  :
                           (write_word_cnt == 2'b01) ? evict_data[63:32]  :
                                                       evict_data[31:0];

    axi4_full_master #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4)
    ) master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_txn),
        .rw(rw_txn),
        .addr(addr_txn),
        .len(8'd3), // 4 beats
        .wdata_in(wdata_in),
        .rdata_out(master_rdata),
        .rdata_valid(master_rdata_valid),
        .done(done),
        .error(),
        
        .m_axi_awid(), .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen), .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst), .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wlast(m_axi_wlast), .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bid(4'h0), .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        
        .m_axi_arid(), .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen), .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst), .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rid(4'h0), .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp), .m_axi_rlast(m_axi_rlast), .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    assign dcache_stall = (state == IDLE && cache_miss) || (state != IDLE);

    always @(*) begin
        next_state = state;
        start_txn  = 1'b0;
        rw_txn     = 1'b0;
        addr_txn   = 32'h0;

        case (state)
            IDLE: begin
                if (cache_miss && rst_n) begin
                    start_txn = 1'b1;
                    if (line_dirty && cache_valid[index][lru_bit[index]]) begin
                        rw_txn = 1'b1; // Evict
                        addr_txn = {cache_tag[index][lru_bit[index]], index, 4'b0000};
                        next_state = EVICT;
                    end else begin
                        rw_txn = 1'b0; // Fetch
                        addr_txn = {tag, index, 4'b0000};
                        next_state = REFILL;
                    end
                end
            end
            
            EVICT: begin
                if (done) begin
                    start_txn = 1'b1;
                    rw_txn = 1'b0; // Fetch
                    addr_txn = {tag, index, 4'b0000};
                    next_state = REFILL;
                end
            end
            
            REFILL: begin
                if (done) next_state = IDLE;
            end
        endcase
    end

    // Refill buffer
    reg [127:0] refill_buf;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                cache_valid[i][0] <= 1'b0;
                cache_valid[i][1] <= 1'b0;
                cache_dirty[i][0] <= 1'b0;
                cache_dirty[i][1] <= 1'b0;
                lru_bit[i]        <= 1'b0;
            end
            refill_buf <= 128'h0;
        end else begin
            if (state == REFILL && master_rdata_valid) begin
                refill_buf <= {master_rdata, refill_buf[127:32]};
            end
            
            if (state == REFILL && done) begin
                cache_valid[index][lru_bit[index]] <= 1'b1;
                cache_tag[index][lru_bit[index]]   <= tag;
                cache_dirty[index][lru_bit[index]] <= 1'b0;
                cache_data[index][lru_bit[index]]  <= {master_rdata, refill_buf[127:32]};
                lru_bit[index] <= ~lru_bit[index];
            end
            
            // Handle CPU Write (Write-Hit)
            if (state == IDLE && hit && cpu_we) begin
                cache_dirty[index][current_way] <= 1'b1;
                cache_data[index][current_way] <= (cache_data[index][current_way] & ~full_write_mask) | (full_cpu_wdata & full_write_mask);
            end

            // Update LRU
            if (state == IDLE && hit && valid_request) begin
                if (hit_w0) lru_bit[index] <= 1'b1;
                if (hit_w1) lru_bit[index] <= 1'b0;
            end
        end
    end
endmodule