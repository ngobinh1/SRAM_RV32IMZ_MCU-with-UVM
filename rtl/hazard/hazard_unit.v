module hazard_unit (
    input  rst, reg_write_w, reg_write_m, pc_src_e,
    input  [4:0] rd_m, rd_w, rs1_e, rs2_e, rd_e, rs1_d, rs2_d,
    input  [2:0] result_src_e,
    input  icache_stall, dcache_stall,
    input wire div_busy, issue_stall,
    input wire wb_trap_redirect,
    input wire [4:0] exc_tag_m, exc_tag_w,
    output reg [1:0] forward_a_e, forward_b_e,
    output reg stall_f, stall_d, stall_e, stall_m, stall_w,
    output flush_e, flush_d, flush_m, flush_w
); 

    // Solving data hazards with forwarding
    // Priority: Memory stage (M) > Writeback stage (W)
    // Memory forwarding has priority because it has more recent data
    always @(*) begin
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

    // Solving data hazards with stalls
    always @(*) begin
        // Default is no stall
        stall_f = 0; stall_d = 0; stall_e = 0; stall_m = 0; stall_w = 0;

        if (wb_trap_redirect) begin
            stall_f = 0; stall_d = 0; stall_e = 0; stall_m = 0; stall_w = 0;
        end
        else if (dcache_stall) begin
            // D-Cache is busy -> Stall the entire system
            stall_f = 1; stall_d = 1; stall_e = 1;
            stall_m = (exc_tag_m != 5'd0) ? 1'b0 : 1'b1;
            stall_w = (exc_tag_w != 5'd0) ? 1'b0 : 1'b1;
        end 
        else if (icache_stall) begin
            // I-Cache is busy -> Stall PC and Decode
            stall_f = 1; stall_d = 1;
            // If a branch is taken, stall Execute so we don't lose the branch target
            if (pc_src_e) stall_e = 1;
        end 
        else if (issue_stall) begin
            // Issue queue full or blocking due to RAW hazard/execute busy
            stall_f = 1; stall_d = 1;
        end
    end

    // Solving control hazards 
    // Flush decode when branch/jump is taken, but don't flush if we are stalling for icache
    assign flush_d = wb_trap_redirect | (pc_src_e & ~dcache_stall & ~icache_stall);
    
    // Flush execute when branch/jump taken, but don't flush if we are stalling for icache
    assign flush_e = wb_trap_redirect | (pc_src_e & ~dcache_stall & ~icache_stall);  

    assign flush_m = wb_trap_redirect;
    assign flush_w = wb_trap_redirect;

endmodule