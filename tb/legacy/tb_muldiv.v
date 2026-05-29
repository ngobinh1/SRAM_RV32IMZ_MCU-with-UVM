`timescale 1ns/1ps

module tb_riscv_pipeline_muldiv();
    reg clk;
    reg rst;

    riscv_pipeline_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    integer i;

    // Monitor additional registers for original debugging
    wire [31:0] reg_x3  = dut.decode_stage.register_file.register_array[3];
    wire [31:0] reg_x4  = dut.decode_stage.register_file.register_array[4];
    wire [31:0] reg_x7  = dut.decode_stage.register_file.register_array[7];
    wire [31:0] reg_x8  = dut.decode_stage.register_file.register_array[8];
    wire [31:0] reg_x22 = dut.decode_stage.register_file.register_array[22];
    wire [31:0] reg_x25 = dut.decode_stage.register_file.register_array[25];
    wire [31:0] reg_x26 = dut.decode_stage.register_file.register_array[26];
    wire [31:0] reg_x29 = dut.decode_stage.register_file.register_array[29];
    wire [31:0] reg_x31 = dut.decode_stage.register_file.register_array[31];

    // --- NEW WIRES FOR MULDIV RV32M TEST ---
    wire [31:0] reg_x14 = dut.decode_stage.register_file.register_array[14]; // MUL
    wire [31:0] reg_x15 = dut.decode_stage.register_file.register_array[15]; // MULH
    wire [31:0] reg_x16 = dut.decode_stage.register_file.register_array[16]; // DIV
    wire [31:0] reg_x17 = dut.decode_stage.register_file.register_array[17]; // REM
    wire [31:0] reg_x18 = dut.decode_stage.register_file.register_array[18]; // DIVU
    wire [31:0] reg_x19 = dut.decode_stage.register_file.register_array[19]; // DIV by 0
    wire [31:0] reg_x23 = dut.decode_stage.register_file.register_array[23]; // DIV Overflow

    integer cycle = 0;

    initial begin
        clk = 1;
        rst = 0;

        // Clear Memory
        for (i = 0; i < 1024; i = i + 1) begin
            dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory[i] = 32'h00000000;
        end

        #2;
        $readmemh("sim/hex/muldiv_test.hex", dut.sram_macro.EF_SRAM_1024x32_inst.memory_mode_inst.memory);
        #98 rst = 1;

        #10;
        $display("\n========================================================");
        $display("   [MEGA TEST DEBUG] PIPELINE CYCLE-BY-CYCLE TRACE");
        $display("========================================================");

        wait(dut.instr_f === 32'h00000073);
    end

    // Cycle Logger
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
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            $display("Time: %0t | PC_F: %h", $time, dut.pc_f);
            if (dut.icache_stall) begin
                $display("  [I-CACHE MISS] Stalling pipeline to fetch Instruction at Addr: %h", dut.pc_f);
            end else begin
                $display("  [I-CACHE HIT]  Instruction fetched: %h", dut.instr_f);
            end

            if (dut.dcache_stall) begin
                $display("  [D-CACHE MISS/BUSY] Stalling pipeline to process Data at Addr: %h", dut.alu_result_m);
            end else if (dut.mem_write_m || dut.mem_read_m) begin 
                $display("  [D-CACHE HIT]  Data successfully accessed at Addr: %h", dut.alu_result_m);
            end
            
            $display("--------------------------------------------------");
        end
    end

    // =========================================================
    // GRACEFUL EXIT & RV32M VERIFICATION (CHECK RESULTS)
    // =========================================================
    always @(posedge clk) begin
        // Dừng mô phỏng và Test kết quả khi gặp ECALL
        if (dut.instr_f === 32'h00000073 && !dut.icache_stall) begin
            #100;

            $display("\n========================================================");
            $display("                 RV32M VERIFICATION REPORT                 ");
            $display("========================================================");
            
            // 1. Test MUL (50 * 7 = 350)
            $write("1. MUL    (50 * 7)       : %0d \t(Expected: 350)", $signed(reg_x14));
            if ($signed(reg_x14) === 350) $display(" \t-> [PASS]"); else $display(" \t-> [FAIL]");

            // 2. Test MULH (-50 * 7 = -350 -> High 32 bits = 0xFFFFFFFF)
            $write("2. MULH   (-50 * 7)      : %h \t(Expected: ffffffff)", reg_x15);
            if (reg_x15 === 32'hffffffff) $display(" \t-> [PASS]"); else $display(" \t-> [FAIL]");

            // 3. Test DIV (50 / 7 = 7)
            $write("3. DIV    (50 / 7)       : %0d \t(Expected: 7)", $signed(reg_x16));
            if ($signed(reg_x16) === 7) $display(" \t\t-> [PASS]"); else $display(" \t\t-> [FAIL]");

            // 4. Test REM (50 % 7 = 1)
            $write("4. REM    (50 %% 7)       : %0d \t(Expected: 1)", $signed(reg_x17));
            if ($signed(reg_x17) === 1) $display(" \t\t-> [PASS]"); else $display(" \t\t-> [FAIL]");

            // 5. Test DIVU (unsigned -50 / 7)
            $write("5. DIVU   (-50 / 7)      : %h \t(Expected: 2492491d)", reg_x18);
            if (reg_x18 === 32'h2492491d) $display(" \t-> [PASS]"); else $display(" \t-> [FAIL]");

            // 6. Test Divide by Zero (50 / 0 = -1)
            $write("6. DIV by 0 (50 / 0)     : %h \t(Expected: ffffffff)", reg_x19);
            if (reg_x19 === 32'hffffffff) $display(" \t-> [PASS]"); else $display(" \t-> [FAIL]");

            // 7. Test Signed Overflow (INT_MIN / -1 = INT_MIN)
            $write("7. DIV Overflow          : %h \t(Expected: 80000000)", reg_x23);
            if (reg_x23 === 32'h80000000) $display(" \t-> [PASS]"); else $display(" \t-> [FAIL]");

            $display("========================================================\n");
            #20;
            $finish;
        end
    end

endmodule