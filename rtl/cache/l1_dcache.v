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

    // AXI4-Lite Master Interface
    output reg  [31:0] m_axi_awaddr,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,

    output reg  [31:0] m_axi_araddr,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready
);
    // 8-Set, 2-Way Set Associative Write-Back Cache (16 lines total)
    reg [31:0] cache_data  [0:7][0:1];
    reg [26:0] cache_tag   [0:7][0:1];
    reg        cache_valid [0:7][0:1];
    reg        cache_dirty [0:7][0:1];
    reg        lru_bit     [0:7];

    wire [2:0]  index  = cpu_addr[4:2];
    wire [26:0] tag    = cpu_addr[31:5];
    wire [1:0]  offset = cpu_addr[1:0];

    wire hit_w0 = cache_valid[index][0] && (cache_tag[index][0] == tag);
    wire hit_w1 = cache_valid[index][1] && (cache_tag[index][1] == tag);
    wire hit    = hit_w0 || hit_w1;
    
    wire current_way = hit_w0 ? 1'b0 : 
                       hit_w1 ? 1'b1 : lru_bit[index];

    assign cpu_rdata = hit_w0 ? cache_data[index][0] :
                       hit_w1 ? cache_data[index][1] : 32'h0;

    // Decode CPU funct3 and offset into a 32-bit Write Mask
    reg [31:0] write_mask;
    always @(*) begin
        write_mask = 32'h00000000;
        if (cpu_funct3 == 3'b000) begin // SB
            if (offset == 2'b00) write_mask = 32'h000000FF;
            else if (offset == 2'b01) write_mask = 32'h0000FF00;
            else if (offset == 2'b10) write_mask = 32'h00FF0000;
            else if (offset == 2'b11) write_mask = 32'hFF000000;
        end
        else if (cpu_funct3 == 3'b001) begin // SH
            if (offset[1] == 1'b0) write_mask = 32'h0000FFFF;
            else                   write_mask = 32'hFFFF0000;
        end
        else begin // SW
            write_mask = 32'hFFFFFFFF;
        end
    end

    // FSM States
    localparam IDLE=3'd0, AW_WAIT=3'd1, W_WAIT=3'd2, B_WAIT=3'd3, AR_WAIT=3'd4, R_WAIT=3'd5;
    reg [2:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    wire valid_request = cpu_we || cpu_re;
    wire cache_miss = valid_request && !hit;
    wire line_dirty = cache_dirty[index][lru_bit[index]];

    assign dcache_stall = (state == IDLE && cache_miss) || (state != IDLE);

    always @(*) begin
        next_state = state;
        m_axi_awvalid = 1'b0; m_axi_awaddr = 32'h0;
        m_axi_wvalid  = 1'b0; m_axi_wdata  = 32'h0; m_axi_wstrb = 4'h0;
        m_axi_bready  = 1'b0;
        m_axi_arvalid = 1'b0; m_axi_araddr = 32'h0;
        m_axi_rready  = 1'b0;

        case (state)
            IDLE: begin
                if (cache_miss && rst_n) begin
                    if (line_dirty && cache_valid[index][lru_bit[index]]) 
                        next_state = AW_WAIT; // Evict line
                    else 
                        next_state = AR_WAIT; // Fetch new line
                end
            end
            
            AW_WAIT: begin
                if (rst_n) begin
                    m_axi_awvalid = 1'b1;
                    m_axi_awaddr  = {cache_tag[index][lru_bit[index]], index, 2'b00};
                    m_axi_wvalid = 1'b1;
                    m_axi_wdata  = cache_data[index][lru_bit[index]];
                    m_axi_wstrb  = 4'b1111;
                    if (m_axi_awready && m_axi_wready) 
                        next_state = B_WAIT;
                    else if (m_axi_awready) 
                        next_state = W_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            W_WAIT: begin
                if (rst_n) begin
                    m_axi_wvalid = 1'b1;
                    m_axi_wdata  = cache_data[index][lru_bit[index]];
                    m_axi_wstrb  = 4'b1111; // Evict entire word
                    if (m_axi_wready) next_state = B_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            B_WAIT: begin
                if (rst_n) begin
                    m_axi_bready = 1'b1;
                    if (m_axi_bvalid) next_state = AR_WAIT;
                end else begin
                    next_state = IDLE;
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
                cache_dirty[i][0] <= 1'b0;
                cache_dirty[i][1] <= 1'b0;
                lru_bit[i]        <= 1'b0;
            end
        end else begin
            if (state == R_WAIT && m_axi_rvalid) begin
                cache_valid[index][lru_bit[index]] <= 1'b1;
                cache_tag[index][lru_bit[index]]   <= tag;
                cache_dirty[index][lru_bit[index]] <= 1'b0; // Just fetched, not dirty
                // Replace data
                cache_data[index][lru_bit[index]]  <= m_axi_rdata;
            end
            
            // Handle CPU Write (Write-Hit)
            if (state == IDLE && hit && cpu_we) begin
                cache_dirty[index][current_way] <= 1'b1;
                cache_data[index][current_way] <= (cache_data[index][current_way] & ~write_mask) | (cpu_wdata & write_mask);
            end

            // Update LRU on hit or miss completion
            if (state == IDLE && hit && valid_request) begin
                if (hit_w0) lru_bit[index] <= 1'b1;
                if (hit_w1) lru_bit[index] <= 1'b0;
            end else if (state == R_WAIT && m_axi_rvalid) begin
                lru_bit[index] <= ~lru_bit[index];
            end
        end
    end
endmodule