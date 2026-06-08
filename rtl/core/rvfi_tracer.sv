// ============================================================
// File: rvfi_tracer.sv
// Description: RISC-V Formal Interface (RVFI) Tracer
//
//   Simulation-only module that captures retired instruction
//   metadata at the Writeback stage and writes a per-instruction
//   trace log compatible with RVFI / spike trace format.
//
//   The tracer tracks instruction and PC through the pipeline
//   using an internal delay chain (shadow pipeline) so that
//   the RTL pipeline registers do NOT need to be modified.
//
//   Output format (one line per retired instruction):
//     core 0: 3 0x00000008 (0x00200293) x5  0x00000002
//
//   Fields: core_id  seq_num  pc  (instruction)  rd  rd_wdata
// ============================================================
`timescale 1ns / 1ps

module rvfi_tracer (
    input  wire        clk,
    input  wire        rst_n,         // active-low reset

    // === Decode-stage inputs (sampled every cycle) ===
    input  wire [31:0] instr_d,       // instruction at decode
    input  wire [31:0] pc_d,          // PC at decode
    input  wire        reg_write_d,   // register write enable at decode
    input  wire        mem_write_d,   // memory write enable at decode
    input  wire [4:0]  rd_d,          // destination register at decode
    input  wire [2:0]  funct3_d,      // funct3 at decode

    // === Pipeline flow control ===
    input  wire        stall_f,       // fetch stall
    input  wire        flush_d,       // decode flush
    input  wire        flush_e,       // execute flush (from hazard or branch misprediction)
    input  wire        stall_e,       // execute stall
    input  wire        stall_m,       // memory stall
    input  wire        stall_w,       // writeback stall
    input  wire        issue_valid,   // issue stage has valid output

    // === Writeback-stage inputs (actual committed values) ===
    input  wire        reg_write_w,   // actual register write enable (includes MulDiv bypass)
    input  wire [4:0]  rd_w,          // actual destination register
    input  wire [31:0] result_w,      // actual write-back data

    // === Memory-stage inputs (for memory access tracing) ===
    input  wire        mem_write_m,   // memory write at MEM stage
    input  wire [31:0] alu_result_m,  // memory address at MEM stage
    input  wire [31:0] write_data_m,  // store data at MEM stage
    input  wire [2:0]  funct3_m,      // funct3 at MEM stage (load/store width)
    input  wire [2:0]  result_src_m,  // result source at MEM stage
    input  wire [31:0] read_data_m,   // load data at MEM stage

    // === CSR signals ===
    input  wire        csr_we_w,      // CSR write enable at WB
    input  wire [11:0] csr_addr_w,    // CSR address at WB
    input  wire [31:0] csr_wd_w       // CSR write data at WB
);

    // ================================================================
    // Shadow pipeline: track instr and PC from D → E → M → W
    // ================================================================
    // Stage E (Execute)
    reg [31:0] instr_e, pc_e;
    reg        valid_e;

    // Stage M (Memory)
    reg [31:0] instr_m, pc_m;
    reg        valid_m;

    // Stage W (Writeback)
    reg [31:0] instr_w, pc_w;
    reg        valid_w;

    // Instruction counter (sequence number)
    integer    rvfi_seq;

    // Trace file handle
    integer    trace_fd;

    // ================================================================
    // Initialization
    // ================================================================
    initial begin
        rvfi_seq = 0;
        instr_e = 32'h0; pc_e = 32'h0; valid_e = 1'b0;
        instr_m = 32'h0; pc_m = 32'h0; valid_m = 1'b0;
        instr_w = 32'h0; pc_w = 32'h0; valid_w = 1'b0;
        trace_fd = $fopen("sim/out/rvfi_trace.log", "w");
        if (trace_fd == 0) begin
            $display("[RVFI_TRACER] WARNING: Cannot open trace file, using stdout");
            trace_fd = 1; // stdout
        end else begin
            $display("[RVFI_TRACER] Trace file opened: sim/out/rvfi_trace.log");
        end
        $fwrite(trace_fd, "# RVFI Instruction Trace\n");
        $fwrite(trace_fd, "# Format: core <id>: <seq> 0x<pc> (0x<instr>) [rd=x<n> wdata=0x<val>] [mem] [csr]\n");
        $fwrite(trace_fd, "#---------------------------------------------------------------------------\n");
    end

    // ================================================================
    // Shadow pipeline advancement
    // ================================================================
    // Determine if decode stage is producing a valid instruction for Issue/Execute
    wire decode_to_issue_valid = rst_n && !stall_f && !flush_d && !$isunknown(instr_d) && (instr_d != 32'h0);

    // Determine if issue stage output is valid (instruction enters Execute)
    wire issue_to_exec_valid = decode_to_issue_valid && issue_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all shadow pipeline stages
            instr_e <= 32'h0; pc_e <= 32'h0; valid_e <= 1'b0;
            instr_m <= 32'h0; pc_m <= 32'h0; valid_m <= 1'b0;
            instr_w <= 32'h0; pc_w <= 32'h0; valid_w <= 1'b0;
        end else begin
            // --- D/Issue → E ---
            if (!stall_e) begin
                if (flush_e || !issue_valid) begin
                    valid_e <= 1'b0;
                    instr_e <= 32'h0;
                    pc_e    <= 32'h0;
                end else begin
                    valid_e <= decode_to_issue_valid;
                    instr_e <= instr_d;
                    pc_e    <= pc_d;
                end
            end

            // --- E → M ---
            if (!stall_m) begin
                valid_m <= valid_e & !stall_e;
                instr_m <= instr_e;
                pc_m    <= pc_e;
            end

            // --- M → W ---
            if (!stall_w) begin
                valid_w <= valid_m & !stall_m;
                instr_w <= instr_m;
                pc_w    <= pc_m;
            end
        end
    end

    // ================================================================
    // Instruction decode helper: get mnemonic string
    // ================================================================
    function automatic string get_mnemonic(input logic [31:0] instr);
        logic [6:0] opcode;
        logic [2:0] f3;
        logic [6:0] f7;
        opcode = instr[6:0];
        f3 = instr[14:12];
        f7 = instr[31:25];

        case (opcode)
            7'b0110111: return "lui";
            7'b0010111: return "auipc";
            7'b1101111: return "jal";
            7'b1100111: return "jalr";
            7'b1100011: begin // Branch
                case (f3)
                    3'b000: return "beq";
                    3'b001: return "bne";
                    3'b100: return "blt";
                    3'b101: return "bge";
                    3'b110: return "bltu";
                    3'b111: return "bgeu";
                    default: return "b???";
                endcase
            end
            7'b0000011: begin // Load
                case (f3)
                    3'b000: return "lb";
                    3'b001: return "lh";
                    3'b010: return "lw";
                    3'b100: return "lbu";
                    3'b101: return "lhu";
                    default: return "l???";
                endcase
            end
            7'b0100011: begin // Store
                case (f3)
                    3'b000: return "sb";
                    3'b001: return "sh";
                    3'b010: return "sw";
                    default: return "s???";
                endcase
            end
            7'b0010011: begin // I-type ALU
                case (f3)
                    3'b000: return "addi";
                    3'b010: return "slti";
                    3'b011: return "sltiu";
                    3'b100: return "xori";
                    3'b110: return "ori";
                    3'b111: return "andi";
                    3'b001: return "slli";
                    3'b101: return (f7[5]) ? "srai" : "srli";
                    default: return "i???";
                endcase
            end
            7'b0110011: begin // R-type ALU / M-extension
                if (f7 == 7'b0000001) begin // M-extension
                    case (f3)
                        3'b000: return "mul";
                        3'b001: return "mulh";
                        3'b010: return "mulhsu";
                        3'b011: return "mulhu";
                        3'b100: return "div";
                        3'b101: return "divu";
                        3'b110: return "rem";
                        3'b111: return "remu";
                        default: return "m???";
                    endcase
                end else begin
                    case (f3)
                        3'b000: return (f7[5]) ? "sub" : "add";
                        3'b001: return "sll";
                        3'b010: return "slt";
                        3'b011: return "sltu";
                        3'b100: return "xor";
                        3'b101: return (f7[5]) ? "sra" : "srl";
                        3'b110: return "or";
                        3'b111: return "and";
                        default: return "r???";
                    endcase
                end
            end
            7'b1110011: begin // System
                if (instr == 32'h00000073) return "ecall";
                if (instr == 32'h00100073) return "ebreak";
                if (instr == 32'h30200073) return "mret";
                case (f3)
                    3'b001: return "csrrw";
                    3'b010: return "csrrs";
                    3'b011: return "csrrc";
                    3'b101: return "csrrwi";
                    3'b110: return "csrrsi";
                    3'b111: return "csrrci";
                    default: return "sys???";
                endcase
            end
            7'b0001111: return "fence";
            default: return "???";
        endcase
    endfunction

    // ================================================================
    // ABI register name
    // ================================================================
    function automatic string get_abi_name(input logic [4:0] r);
        case (r)
            5'd0:  return "zero"; 5'd1:  return "ra";   5'd2:  return "sp";
            5'd3:  return "gp";   5'd4:  return "tp";   5'd5:  return "t0";
            5'd6:  return "t1";   5'd7:  return "t2";   5'd8:  return "s0";
            5'd9:  return "s1";   5'd10: return "a0";   5'd11: return "a1";
            5'd12: return "a2";   5'd13: return "a3";   5'd14: return "a4";
            5'd15: return "a5";   5'd16: return "a6";   5'd17: return "a7";
            5'd18: return "s2";   5'd19: return "s3";   5'd20: return "s4";
            5'd21: return "s5";   5'd22: return "s6";   5'd23: return "s7";
            5'd24: return "s8";   5'd25: return "s9";   5'd26: return "s10";
            5'd27: return "s11";  5'd28: return "t3";   5'd29: return "t4";
            5'd30: return "t5";   5'd31: return "t6";
            default: return "x??";
        endcase
    endfunction

    // ================================================================
    // RVFI output signals (directly observable in waveform viewers)
    // ================================================================
    reg        rvfi_valid;
    reg [31:0] rvfi_insn;
    reg [31:0] rvfi_pc_rdata;
    reg [4:0]  rvfi_rd_addr;
    reg [31:0] rvfi_rd_wdata;
    reg        rvfi_mem_wmask_nz; // non-zero memory write mask
    reg [31:0] rvfi_mem_addr;
    reg [31:0] rvfi_mem_wdata;
    reg [31:0] rvfi_mem_rdata;

    // ================================================================
    // Trace output on retirement
    // ================================================================
    always @(posedge clk) begin
        // Reset RVFI outputs by default
        rvfi_valid       <= 1'b0;
        rvfi_insn        <= 32'h0;
        rvfi_pc_rdata    <= 32'h0;
        rvfi_rd_addr     <= 5'h0;
        rvfi_rd_wdata    <= 32'h0;
        rvfi_mem_wmask_nz <= 1'b0;
        rvfi_mem_addr    <= 32'h0;
        rvfi_mem_wdata   <= 32'h0;
        rvfi_mem_rdata   <= 32'h0;

        if (rst_n && valid_w && !stall_w && !$isunknown(instr_w) && (instr_w != 32'h0)) begin
            rvfi_valid    <= 1'b1;
            rvfi_insn     <= instr_w;
            rvfi_pc_rdata <= pc_w;
            rvfi_rd_addr  <= rd_w;
            rvfi_rd_wdata <= result_w;

            rvfi_seq = rvfi_seq + 1;

            // Build trace line
            if (reg_write_w && rd_w != 5'h0) begin
                $fwrite(trace_fd, "core   0: %0d 0x%08h (0x%08h) x%-2d 0x%08h  %s\n",
                    rvfi_seq, pc_w, instr_w, rd_w, result_w, get_mnemonic(instr_w));
            end else begin
                $fwrite(trace_fd, "core   0: %0d 0x%08h (0x%08h)                %s\n",
                    rvfi_seq, pc_w, instr_w, get_mnemonic(instr_w));
            end

            // Memory access annotation
            if (mem_write_m) begin
                rvfi_mem_wmask_nz <= 1'b1;
                rvfi_mem_addr  <= alu_result_m;
                rvfi_mem_wdata <= write_data_m;
            end
            if (result_src_m == 3'b001) begin
                rvfi_mem_addr  <= alu_result_m;
                rvfi_mem_rdata <= read_data_m;
            end

            // CSR annotation
            if (csr_we_w) begin
                $fwrite(trace_fd, "          CSR  0x%03h <- 0x%08h\n", csr_addr_w, csr_wd_w);
            end
        end
    end

    // ================================================================
    // Close trace file at simulation end
    // ================================================================
    final begin
        $fwrite(trace_fd, "#---------------------------------------------------------------------------\n");
        $fwrite(trace_fd, "# Total instructions retired: %0d\n", rvfi_seq);
        $fclose(trace_fd);
        $display("[RVFI_TRACER] Trace complete. %0d instructions retired.", rvfi_seq);
    end

endmodule
