module branch_predictor (
    input wire clk,
    input wire rst_n,

    input wire [31:0] if_pc,

    output wire predict_taken,
    output wire [31:0] predict_target,

    input wire update_valid,
    input wire [31:0] update_pc,
    input wire actual_taken,
    input wire [31:0] actual_target
);
    // 16 entries BTB
    // valid[15:0]
    // tag: PC[31:6] (26 bits)
    // target: [31:0]
    
    // 16 entries BHT
    // 2-bit counter

    // arrays
    reg [25:0] btb_tag [15:0];
    reg [31:0] btb_target [15:0];
    reg [15:0] btb_valid;

    reg [1:0] bht [15:0];

    // index is PC[5:2]
    wire [3:0] if_idx = if_pc[5:2];
    wire [25:0] if_tag = if_pc[31:6];

    wire [3:0] update_idx = update_pc[5:2];
    wire [25:0] update_tag = update_pc[31:6];

    // Prediction
    wire is_btb_hit = btb_valid[if_idx] && (btb_tag[if_idx] == if_tag);
    wire is_bht_taken = (bht[if_idx] >= 2'b10);

    assign predict_taken = is_btb_hit && is_bht_taken;
    assign predict_target = is_btb_hit ? btb_target[if_idx] : 32'b0;

    // Update
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            btb_valid <= 16'b0;
            for (i = 0; i < 16; i = i + 1) begin
                bht[i] <= 2'b01; // Weak Not Taken
                btb_tag[i] <= 26'b0;
                btb_target[i] <= 32'b0;
            end
        end else begin
            if (update_valid) begin
                // Update BHT
                if (actual_taken) begin
                    if (bht[update_idx] != 2'b11) bht[update_idx] <= bht[update_idx] + 1;
                end else begin
                    if (bht[update_idx] != 2'b00) bht[update_idx] <= bht[update_idx] - 1;
                end

                // Update BTB
                if (actual_taken) begin
                    btb_valid[update_idx] <= 1'b1;
                    btb_tag[update_idx] <= update_tag;
                    btb_target[update_idx] <= actual_target;
                end
            end
        end
    end
endmodule
