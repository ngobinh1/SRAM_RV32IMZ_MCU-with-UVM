module store_buffer #(
    parameter DEPTH = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Interface with Core (LSU output)
    input  wire        sb_push_req,
    input  wire [31:0] sb_push_addr,
    input  wire [31:0] sb_push_data,
    input  wire [3:0]  sb_push_be,
    output wire        sb_full,
    output wire        sb_empty,
    
    // Interface with Core (Load Forwarding)
    input  wire        load_req,
    input  wire [31:0] load_addr,
    input  wire [3:0]  load_be,
    output reg         fwd_valid,
    output reg  [31:0] fwd_data,
    
    // Interface with MMU/Cache
    output wire        mem_req,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_data,
    output wire [3:0]  mem_be,
    input  wire        mem_ack
);

    reg [31:0] addr_q [0:DEPTH-1];
    reg [31:0] data_q [0:DEPTH-1];
    reg [3:0]  be_q   [0:DEPTH-1];
    reg        valid_q[0:DEPTH-1];

    reg [$clog2(DEPTH)-1:0] head;
    reg [$clog2(DEPTH)-1:0] tail;
    reg [$clog2(DEPTH):0]   count;

    integer i;

    assign sb_full = (count == DEPTH);
    assign sb_empty = (count == 0);

    assign mem_req  = !sb_empty;
    assign mem_addr = addr_q[head];
    assign mem_data = data_q[head];
    assign mem_be   = be_q[head];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head  <= 0;
            tail  <= 0;
            count <= 0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid_q[i] <= 1'b0;
            end
        end else begin
            case ({sb_push_req && !sb_full, mem_ack && !sb_empty})
                2'b10: begin // Push only
                    addr_q[tail]  <= sb_push_addr;
                    data_q[tail]  <= sb_push_data;
                    be_q[tail]    <= sb_push_be;
                    valid_q[tail] <= 1'b1;
                    
                    tail  <= (tail == DEPTH - 1) ? 0 : tail + 1;
                    count <= count + 1;
                end
                2'b01: begin // Pop only
                    valid_q[head] <= 1'b0;
                    head  <= (head == DEPTH - 1) ? 0 : head + 1;
                    count <= count - 1;
                end
                2'b11: begin // Push and Pop
                    valid_q[head] <= 1'b0;
                    head  <= (head == DEPTH - 1) ? 0 : head + 1;
                    
                    addr_q[tail]  <= sb_push_addr;
                    data_q[tail]  <= sb_push_data;
                    be_q[tail]    <= sb_push_be;
                    valid_q[tail] <= 1'b1;
                    
                    tail  <= (tail == DEPTH - 1) ? 0 : tail + 1;
                end
            endcase
        end
    end

    reg [$clog2(DEPTH)-1:0] idx;
    always @(*) begin
        fwd_valid = 1'b0;
        fwd_data  = 32'b0;
        
        if (load_req) begin
            for (i = DEPTH; i >= 1; i = i - 1) begin
                idx = (tail >= i) ? (tail - i) : (DEPTH + tail - i);
                
                if (valid_q[idx] && (addr_q[idx][31:2] == load_addr[31:2])) begin
                    // Forward if store byte enables cover load byte enables
                    if ((be_q[idx] & load_be) == load_be) begin
                        fwd_valid = 1'b1;
                        fwd_data  = data_q[idx];
                    end
                end
            end
        end
    end

endmodule
