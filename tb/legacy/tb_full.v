`timescale 1ns/1ps

module tb_riscv_pipeline_mega();
    reg clk;
    reg rst;

    riscv_pipeline_top dut (
        .clk(clk),
        .rst(rst),
        .meip(1'b0), 
        .mtip(1'b0)
    );

    always #5 clk = ~clk;

    integer i;

    // Monitor additional registers for easier debugging
    wire [31:0] reg_x3  = dut.decode_stage.register_file.register_array[3];
    wire [31:0] reg_x4  = dut.decode_stage.register_file.register_array[4];
    wire [31:0] reg_x7  = dut.decode_stage.register_file.register_array[7];
    wire [31:0] reg_x8  = dut.decode_stage.register_file.register_array[8];
    wire [31:0] reg_x22 = dut.decode_stage.register_file.register_array[22];
    wire [31:0] reg_x25 = dut.decode_stage.register_file.register_array[25];
    wire [31:0] reg_x26 = dut.decode_stage.register_file.register_array[26];
    wire [31:0] reg_x29 = dut.decode_stage.register_file.register_array[29];
    wire [31:0] reg_x31 = dut.decode_stage.register_file.register_array[31];

    integer cycle = 0; // Biến đếm chu kỳ clock

    initial begin
        clk = 1; rst = 0;

        for (i = 0; i < 1024; i = i + 1) begin
            dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory[i] = 32'h00000000;
        end

        #2;
        // Change absolute path
        $readmemh("sim/hex/full_test.hex", dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory);
        
        #98 rst = 1;
        $display("========================================");
        $display("DEBUG: memory[0] = %h", dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory[0]);
        $display("DEBUG: memory[1] = %h", dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory[1]);
        $display("========================================");
        #10;

        $display("\n========================================================");
        $display("   [MEGA TEST DEBUG] PIPELINE CYCLE-BY-CYCLE TRACE");
        $display("========================================================");
        
        wait(dut.instr_f === 32'h00000063);
        
        #50;

        $display("\n========================================================");
        $display("   [MEGA TEST DEBUG] DETAILED VALUES OF EACH REGISTER");
        $display("========================================================");
        
        $display("\n--- 1. ALU COMPUTATION STAGE (Test Data Hazard) ---");
        $display("x3  (addi -10) : %0d \t(Hex: %h)", $signed(reg_x3), reg_x3);
        $display("x4  (xori)     : %0d \t(Hex: %h)", $signed(reg_x4), reg_x4);
        $display("x7  (add)      : %0d \t(Hex: %h)", $signed(reg_x7), reg_x7);
        $display("x8  (sub)      : %0d \t(Hex: %h) -> Should be 3", $signed(reg_x8), reg_x8);

        $display("\n--- 2. COMPARISON (Test SLT signed/unsigned) ---");
        $display("x22 (slt x3,x8): %0d \t(Hex: %h) -> Should be 1", reg_x22, reg_x22);

        $display("\n--- 3. MEMORY ACCESS (Test Load-Use Stall) ---");
        $display("x25 (lw)       : %0d \t(Hex: %h)", $signed(reg_x25), reg_x25);
        $display("x26 (add x25,0): %0d \t(Hex: %h) -> Should be 12345003", $signed(reg_x26), reg_x26);
        $display("x29 (lb x7)    : %0d \t(Hex: %h) -> Should be ffffffef", $signed(reg_x29), reg_x29);

        $display("\n========================================================");
        $display("                   OVERALL CONCLUSION                   ");
        $display("========================================================");
        
        // Update with ACCURATE EXPECTED parameters
        $display("1. Data Hazard & ALU: %s (Expected x8 = 3)", (reg_x8 == 3) ? "PASS" : "FAIL");
        $display("2. Set Less Than    : %s (Expected x22 = 1)", (reg_x22 == 1) ? "PASS" : "FAIL");
        $display("3. Load-Use Stall   : %s (Expected x26 = 12345003)", (reg_x26 == 32'h12345003) ? "PASS" : "FAIL");
        $display("4. Memory Access    : %s (Expected x29 = ffffffef)", (reg_x29 == 32'hFFFFFFEF) ? "PASS" : "FAIL");
        
        $display("\n--- CONTROL HAZARD SUMMARY (BRANCH/JUMP) ---");
        if (reg_x31 === 32'd1) begin
            $display(">> [PERFECT PASS] Pipeline bypassed all Traps!");
        end else if ($signed(reg_x31) < 0) begin
            $display(">> [FAIL] CPU fell into TRAP number: %0d", reg_x31);
        end else begin
            $display(">> [FAIL] System hang. x31 = %h", reg_x31);
        end

        $display("========================================================\n");
        $finish;
    end


    always @(negedge clk) begin
        if (rst == 1'b1) begin
            cycle = cycle + 1;
            $display("\n--- Cycle %0d ---", cycle);
            
            // 1. Fetch Stage
            $display("  [IF]  PC = %h | Instr = %h %s", 
                dut.pc_f, dut.instr_f, 
                dut.stall_f ? ">>> [STALL]" : "");
                
            // 2. Decode Stage
            $display("  [ID]  PC = %h | Instr = %h | rs1=x%0d, rs2=x%0d, rd=x%0d %s%s", 
                dut.pc_d, dut.instr_d, dut.rs1_d, dut.rs2_d, dut.rd_d, 
                dut.stall_d ? ">>> [STALL]" : "", 
                dut.flush_d ? ">>> [FLUSH]" : "");
                
            // 3. Execute Stage
            $display("  [EX]  PC = %h | ALU_Out = %h | rd=x%0d %s", 
                dut.pc_e, dut.alu_result_e, dut.rd_e, 
                dut.flush_e ? ">>> [FLUSH]" : "");
                
            // 4. Memory Stage
            $display("  [MEM] ALU_Out/Addr = %h | WriteData = %h | ReadData = %h | rd=x%0d | MemWr=%b", 
                dut.alu_result_m, dut.write_data_m, dut.read_data_m, dut.rd_m, dut.mem_write_m);
                
            // 5. Writeback Stage
            $display("  [WB]  Result = %h | rd=x%0d | RegWr=%b", 
                dut.result_w, dut.rd_w, dut.reg_write_w);
                
            // 6. Branch Predictor
            $display("  [BP]  predict_taken_f=%b | predict_target_f=%h | update_valid_e=%b | actual_taken_e=%b",
                dut.predict_taken_f, dut.predict_target_f, dut.update_valid_e, dut.actual_taken_e);
        end
    end

    always @(posedge clk) begin
        if (rst) begin // Only log when system is running
            $display("Time: %0t | PC_F: %h", $time, dut.pc_f);
            
            // --- I-Cache Monitoring ---
            if (dut.icache_stall) begin
                $display("  [I-CACHE MISS] Stalling pipeline to fetch Instruction at Addr: %h", dut.pc_f);
            end else begin
                $display("  [I-CACHE HIT]  Instruction fetched: %h", dut.instr_f);
            end

            // --- D-Cache Monitoring ---
            // dut.mem_read_m and dut.mem_write_m were declared in top_module
            if (dut.dcache_stall) begin
                $display("  [D-CACHE MISS/BUSY] Stalling pipeline to process Data at Addr: %h", dut.alu_result_m);
            end else if (dut.mem_write_m || dut.mem_read_m) begin 
                $display("  [D-CACHE HIT]  Data successfully accessed at Addr: %h", dut.alu_result_m);
            end
            
            $display("--------------------------------------------------");
        end
    end

    // 6. Graceful Exit Condition
    // Stop simulation automatically when the program finishes (e.g., hits an ECALL instruction)
    always @(posedge clk) begin
        // Assuming 32'h00000073 is ECALL in your ISA
        if (dut.instr_f === 32'h00000073 && !dut.icache_stall) begin
            $display("==================================================");
            $display("ECALL Instruction encountered. Simulation Finished!");
            $display("==================================================");
            #20;
            $finish;
        end
    end

endmodule