module l1_icache (
    input  wire        clk, rst_n,
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output wire [31:0] cpu_rdata,
    output wire        icache_stall,

    // Arbiter/Memory Interface
    output reg         mem_req,
    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
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
    localparam IDLE = 1'b0, ALLOCATE = 1'b1;
    reg state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Stall the CPU if we are missing or currently fetching
    assign icache_stall = (state == IDLE && !hit) || (state == ALLOCATE);

    always @(state or mem_ready or hit) begin
        next_state = state;
        mem_req = 1'b0;

        case (state)
            IDLE: begin
                if (!hit) begin
                    mem_req = 1'b1;
                    next_state = ALLOCATE;
                end
            end
            ALLOCATE: begin
                mem_req = 1'b1;
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
            end
        end else if (state == ALLOCATE && mem_ready) begin
            cache_valid[index] <= 1'b1;
            cache_tag[index]   <= tag;
            cache_data[index]  <= mem_rdata;
        end
    end
endmodule