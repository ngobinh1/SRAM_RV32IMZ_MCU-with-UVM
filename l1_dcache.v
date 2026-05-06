module l1_dcache (
    input  wire        clk, rst_n,
    
    // CPU interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,     // Read Enable (Crucial to avoid stalling on ALU ops)
    input  wire [2:0]  cpu_funct3,
    output wire [31:0] cpu_rdata,
    output wire        dcache_stall,

    // Memory interface (to Arbiter)
    output reg         mem_req,
    output reg         mem_we,
    output reg  [31:0] mem_addr, 
    output reg  [31:0] mem_wdata,
    output reg  [31:0] mem_ben,
    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
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
        if (cpu_funct3 == 3'b000) begin // SB (Store Byte)
            if (offset == 2'b00) write_mask = 32'h000000FF;
            else if (offset == 2'b01) write_mask = 32'h0000FF00;
            else if (offset == 2'b10) write_mask = 32'h00FF0000;
            else if (offset == 2'b11) write_mask = 32'hFF000000;
        end
        else if (cpu_funct3 == 3'b001) begin // SH (Store Half-word)
            if (offset[1] == 1'b0) write_mask = 32'h0000FFFF;
            else                   write_mask = 32'hFFFF0000;
        end
        else begin // SW (Store Word)
            write_mask = 32'hFFFFFFFF;
        end
    end

    // FSM States
    localparam IDLE = 2'b00, WRITE_BACK = 2'b01, ALLOCATE = 2'b10;
    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Only interact with Cache if it's a genuine Load or Store
    wire valid_request = cpu_we || cpu_re;
    wire cache_miss = valid_request && !hit;
    wire line_dirty = cache_dirty[index];

    assign dcache_stall = (state == IDLE && cache_miss) || (state != IDLE);

    always @(state or mem_ready or hit or cache_miss or line_dirty or cache_data[index] or cache_tag[index] or cache_valid[index]) begin
        next_state = state;
        mem_req = 1'b0;
        mem_we = 1'b0;
        mem_addr = 32'h0;
        mem_wdata = 32'h0;
        mem_ben = 32'hFFFFFFFF; // SRAM operates on full words during line fill/evict

        case (state)
            IDLE: begin
                if (cache_miss) begin
                    if (line_dirty && cache_valid[index]) begin
                        next_state = WRITE_BACK; // Evict dirty line first
                    end else begin
                        next_state = ALLOCATE;   // Fetch new line
                    end
                end
            end
            
            WRITE_BACK: begin
                mem_req = 1'b1;
                mem_we  = 1'b1; 
                mem_addr = {cache_tag[index], index, 2'b00}; // Old address
                mem_wdata = cache_data[index];
                
                if (mem_ready) begin
                    next_state = ALLOCATE;
                end
            end
            
            ALLOCATE: begin
                mem_req = 1'b1;
                mem_we  = 1'b0; 
                mem_addr = {tag, index, 2'b00}; // New address
                
                if (mem_ready) begin
                    next_state = IDLE;
                end
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
            if (state == ALLOCATE && mem_ready) begin
                // Fill line from SRAM
                cache_valid[index] <= 1'b1;
                cache_dirty[index] <= 1'b0;
                cache_tag[index]   <= tag;
                cache_data[index]  <= mem_rdata;
            end 
            else if (state == IDLE && hit && cpu_we) begin
                // CPU writes to Cache (Byte Masking logic)
                cache_dirty[index] <= 1'b1;
                cache_data[index]  <= (cache_data[index] & ~write_mask) | (cpu_wdata & write_mask);
            end
        end
    end
endmodule