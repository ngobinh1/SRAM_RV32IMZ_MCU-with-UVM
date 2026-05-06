module hazard_unit (
    input  rst, reg_write_w, reg_write_m, pc_src_e,
    input  [4:0] rd_m, rd_w, rs1_e, rs2_e, rd_e, rs1_d, rs2_d,
    input  [2:0] result_src_e,
    input  icache_stall, dcache_stall,
    output reg [1:0] forward_a_e, forward_b_e,
    output reg stall_f, stall_d, stall_e, stall_m, stall_w,
    output flush_e, flush_d
);

    wire stall; 

    // Solving data hazards with forwarding
    // Priority: Memory stage (M) > Writeback stage (W)
    // Memory forwarding has priority because it has more recent data
    always @(rs1_e or rs2_e or reg_write_m or reg_write_w or rst) begin
        // Forward A - Check if rs1_e matches producing instruction
        if (rst == 1'b0) begin
            forward_a_e = 2'b00;  // No forwarding during reset
        end
        // Memory stage forwarding (higher priority)
        else if ((rs1_e == rd_m) && (reg_write_m == 1'b1) && (rs1_e != 5'b00000)) begin
            forward_a_e = 2'b10;  // Forward from Memory stage
        end
        // Writeback stage forwarding (lower priority)
        else if ((rs1_e == rd_w) && (reg_write_w == 1'b1) && (rs1_e != 5'b00000)) begin
            forward_a_e = 2'b01;  // Forward from Writeback stage
        end
        else begin
            forward_a_e = 2'b00;  // No forwarding needed
        end

        // Forward B - Check if rs2_e matches producing instruction
        if (rst == 1'b0) begin
            forward_b_e = 2'b00;  // No forwarding during reset
        end
        // Memory stage forwarding (higher priority)
        else if ((rs2_e == rd_m) && (reg_write_m == 1'b1) && (rs2_e != 5'b00000)) begin
            forward_b_e = 2'b10;  // Forward from Memory stage
        end
        // Writeback stage forwarding (lower priority)
        else if ((rs2_e == rd_w) && (reg_write_w == 1'b1) && (rs2_e != 5'b00000)) begin
            forward_b_e = 2'b01;  // Forward from Writeback stage
        end
        else begin
            forward_b_e = 2'b00;  // No forwarding needed
        end
    end

    // Solving data hazards with stalls (for load instructions)
    // When a load instruction is in Execute stage and the next instruction 
    // in Decode needs that loaded value, we must stall
    // result_src_e[0] == 1 indicates a load instruction (result from memory)
    assign stall = result_src_e[0] && (rd_e != 5'b00000) && ((rs1_d == rd_e) || (rs2_d == rd_e));
    always @(icache_stall or dcache_stall or stall) begin
        // Default is no stall
        stall_f = 0; stall_d = 0; stall_e = 0; stall_m = 0; stall_w = 0;

        if (dcache_stall) begin
            // D-Cache is busy -> Stall the entire system
            stall_f = 1; stall_d = 1; stall_e = 1; stall_m = 1; stall_w = 1;
        end 
        else if (icache_stall) begin
            // I-Cache is busy -> Stall PC and Decode, subsequent instructions continue to run
            stall_f = 1; stall_d = 1;
        end 
        else if (stall) begin
            // Load-Use hazard
            stall_f = 1; stall_d = 1;
        end
    end

    // Solving control hazards 
    // Flush decode when branch/jump is taken
    assign flush_d = pc_src_e & ~dcache_stall;
    
    // Flush execute when:
    // 1. Stalling (insert bubble)
    // 2. Branch/jump taken (wrong instruction in pipeline)
    assign flush_e = (stall | pc_src_e | icache_stall) & ~dcache_stall; 

endmodule