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
    // 16-line Direct Mapped Write-Back Cache
    reg [31:0] cache_data  [0:15];
    reg [25:0] cache_tag   [0:15];
    reg        cache_valid [0:15];
    reg        cache_dirty [0:15];

    wire [3:0]  index  = cpu_addr[5:2];
    wire [25:0] tag    = cpu_addr[31:6];
    wire [1:0]  offset = cpu_addr[1:0];

    wire hit = cache_valid[index] && (cache_tag[index] == tag);
    assign cpu_rdata = hit ? cache_data[index] : 32'h0;

    // Decode CPU funct3 and offset into a 32-bit Write Mask
    reg [31:0] write_mask;
    always @(cpu_funct3 or offset) begin
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
    wire line_dirty = cache_dirty[index];

    assign dcache_stall = (state == IDLE && cache_miss) || (state != IDLE);

    always @(state or cache_miss or line_dirty or cache_valid or cache_tag or cache_data or index or m_axi_awready or m_axi_wready or m_axi_bvalid or tag or m_axi_arready or m_axi_rvalid) begin
        next_state = state;
        m_axi_awvalid = 1'b0; m_axi_awaddr = 32'h0;
        m_axi_wvalid  = 1'b0; m_axi_wdata  = 32'h0; m_axi_wstrb = 4'h0;
        m_axi_bready  = 1'b0;
        m_axi_arvalid = 1'b0; m_axi_araddr = 32'h0;
        m_axi_rready  = 1'b0;

        case (state)
            IDLE: begin
                if (cache_miss) begin
                    if (line_dirty && cache_valid[index]) 
                        next_state = AW_WAIT; // Evict line
                    else 
                        next_state = AR_WAIT; // Fetch new line
                end
            end
            
            AW_WAIT: begin
                m_axi_awvalid = 1'b1;
                m_axi_awaddr  = {cache_tag[index], index, 2'b00};
                m_axi_wvalid = 1'b1;
                m_axi_wdata  = cache_data[index];
                m_axi_wstrb  = 4'b1111;
                if (m_axi_awready && m_axi_wready) 
                    next_state = B_WAIT;
                else if (m_axi_awready) 
                    next_state = W_WAIT;
            end
            
            W_WAIT: begin
                m_axi_wvalid = 1'b1;
                m_axi_wdata  = cache_data[index];
                m_axi_wstrb  = 4'b1111; // Evict entire word (4 bytes)
                if (m_axi_wready) next_state = B_WAIT;
            end
            
            B_WAIT: begin
                m_axi_bready = 1'b1;
                if (m_axi_bvalid) next_state = AR_WAIT;
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
                cache_dirty[i] <= 1'b0;
            end
        end else begin
            if (state == R_WAIT && m_axi_rvalid) begin
                cache_valid[index] <= 1'b1;
                cache_dirty[index] <= 1'b0;
                cache_tag[index]   <= tag;
                cache_data[index]  <= m_axi_rdata;
            end 
            else if (state == IDLE && hit && cpu_we) begin
                cache_dirty[index] <= 1'b1;
                cache_data[index]  <= (cache_data[index] & ~write_mask) | (cpu_wdata & write_mask);
            end
        end
    end
endmodule