// ============================================================
// File: riscv_monitor.sv
// Description: UVM Monitor - Phiên bản Hoàn hảo (Bản cuối cùng)
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_seq_item.sv"
`ifndef RISCV_MONITOR_SV
`define RISCV_MONITOR_SV

class riscv_monitor extends uvm_monitor;
    `uvm_component_utils(riscv_monitor)

    virtual riscv_if.monitor_mp vif;

    uvm_analysis_port #(riscv_seq_item) ap_regwrite;
    uvm_analysis_port #(riscv_seq_item) ap_memaccess;
    uvm_analysis_port #(riscv_seq_item) ap_branch;
    uvm_analysis_port #(riscv_seq_item) ap_instr;

    int unsigned instr_count;
    int unsigned stall_count;
    int unsigned branch_taken_count;
    int unsigned mem_write_count;
    int unsigned mem_read_count;

    function new(string name = "riscv_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual riscv_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Cannot get virtual interface from config_db")

        ap_regwrite  = new("ap_regwrite",  this);
        ap_memaccess = new("ap_memaccess", this);
        ap_branch    = new("ap_branch",    this);
        ap_instr     = new("ap_instr",     this);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_regwrites();
            monitor_memaccesses();
            monitor_branches();
            monitor_all_instrs();
        join_none
    endtask

    // ========================================================
    // Thread 1: Monitor register file write-backs (WB stage)
    // ========================================================
    task automatic monitor_regwrites();
        riscv_seq_item item;
        logic [31:0] instr_queue[$];
        logic [31:0] pc_queue[$];

        forever begin
            @(vif.monitor_cb);
            
            if (vif.monitor_cb.rst !== 1'b1) begin
                instr_queue.delete();
                pc_queue.delete();
            end 
            else begin
                // PUSH: Lưu các lệnh hợp lệ ở tầng Decode
                if (!vif.monitor_cb.stall_f && 
                    !vif.monitor_cb.flush_d && 
                    vif.monitor_cb.reg_write_d === 1'b1 && 
                    vif.monitor_cb.rd_d !== 5'h0 && 
                    !$isunknown(vif.monitor_cb.instr_d)) 
                begin
                    instr_queue.push_back(vif.monitor_cb.instr_d);
                    pc_queue.push_back(vif.monitor_cb.pc_d);
                end

                // POP: Tầng WB chỉ bị đóng băng khi D-Cache Stall (SRAM đang bận)
                if (!vif.monitor_cb.dcache_stall && 
                    vif.monitor_cb.reg_write_w === 1'b1 &&
                    vif.monitor_cb.rd_w !== 5'h0 &&
                    !$isunknown(vif.monitor_cb.result_w)) 
                begin
                    
                    // SELF-HEALING: Tự động loại bỏ các lệnh bị nuốt bởi flush_e
                    while (instr_queue.size() > 0 && instr_queue[0][11:7] !== vif.monitor_cb.rd_w) begin
                        instr_queue.pop_front();
                        pc_queue.pop_front();
                    end

                    item = riscv_seq_item::type_id::create("regwrite_item");
                    item.trans_type  = riscv_seq_item::TRANS_REG_WRITE;
                    item.rd          = vif.monitor_cb.rd_w;
                    item.result      = vif.monitor_cb.result_w;
                    item.stall_seen  = vif.monitor_cb.stall_f | vif.monitor_cb.icache_stall | vif.monitor_cb.dcache_stall;
                    item.timestamp   = $time;

                    if (instr_queue.size() > 0) begin
                        item.pc = pc_queue.pop_front();
                        item.decode_instr(instr_queue.pop_front());
                    end else begin
                        item.pc = 32'h0;
                    end

                    instr_count++;
                    `uvm_info("MONITOR", item.convert2string(), UVM_HIGH)
                    ap_regwrite.write(item);
                end

                if (vif.monitor_cb.stall_f === 1'b1 ||
                    vif.monitor_cb.icache_stall === 1'b1 ||
                    vif.monitor_cb.dcache_stall === 1'b1) begin
                    stall_count++;
                end
            end
        end
    endtask

    // ========================================================
    // Thread 2: Monitor memory accesses (MEM stage)
    // ========================================================
    task automatic monitor_memaccesses();
        riscv_seq_item item;
        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.rst !== 1'b1) continue;

            // CHỈ CHẶN D-CACHE STALL
            if (!vif.monitor_cb.dcache_stall && 
                vif.monitor_cb.mem_write_m === 1'b1 && 
                !$isunknown(vif.monitor_cb.alu_result_m))
            begin
                item = riscv_seq_item::type_id::create("memwr_item");
                item.trans_type = riscv_seq_item::TRANS_MEM_WRITE;
                item.pc         = vif.monitor_cb.pc_m;
                item.mem_addr   = vif.monitor_cb.alu_result_m;
                item.mem_wdata  = vif.monitor_cb.write_data_m;
                item.funct3     = vif.monitor_cb.funct3_m;
                item.stall_seen = vif.monitor_cb.dcache_stall;
                item.timestamp  = $time;

                case (item.funct3)
                    3'b000: item.instr_type = riscv_seq_item::INSTR_SB;
                    3'b001: item.instr_type = riscv_seq_item::INSTR_SH;
                    3'b010: item.instr_type = riscv_seq_item::INSTR_SW;
                    default: item.instr_type = riscv_seq_item::INSTR_NOP;
                endcase

                mem_write_count++;
                `uvm_info("MONITOR", item.convert2string(), UVM_HIGH)
                ap_memaccess.write(item);
            end
            else if (!vif.monitor_cb.dcache_stall && vif.monitor_cb.result_src_m === 3'b001) begin 
                item = riscv_seq_item::type_id::create("memrd_item");
                item.trans_type = riscv_seq_item::TRANS_MEM_READ;
                item.pc         = vif.monitor_cb.pc_m;
                item.mem_addr   = vif.monitor_cb.alu_result_m;
                item.mem_rdata  = vif.monitor_cb.read_data_m;
                item.funct3     = vif.monitor_cb.funct3_m;
                item.stall_seen = vif.monitor_cb.dcache_stall;
                item.timestamp  = $time;

                case (item.funct3)
                    3'b000: item.instr_type = riscv_seq_item::INSTR_LB;
                    3'b001: item.instr_type = riscv_seq_item::INSTR_LH;
                    3'b010: item.instr_type = riscv_seq_item::INSTR_LW;
                    3'b100: item.instr_type = riscv_seq_item::INSTR_LBU;
                    3'b101: item.instr_type = riscv_seq_item::INSTR_LHU;
                    default: item.instr_type = riscv_seq_item::INSTR_NOP;
                endcase

                mem_read_count++;
                `uvm_info("MONITOR", item.convert2string(), UVM_HIGH)
                ap_memaccess.write(item);
            end
        end
    endtask

    // ========================================================
    // Thread 3: Monitor branches and jumps (EX stage)
    // ========================================================
    task automatic monitor_branches();
        riscv_seq_item item;
        logic [31:0] instr_e_reg;
        logic        is_branch_e_reg;
        logic        is_jump_e_reg;

        is_branch_e_reg = 1'b0;
        is_jump_e_reg   = 1'b0;
        instr_e_reg     = 32'h0;

        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.rst !== 1'b1) begin
                is_branch_e_reg = 1'b0;
                is_jump_e_reg   = 1'b0;
                continue;
            end

            // CHỈ CHẶN D-CACHE STALL để không bỏ lỡ Branch
            if (!vif.monitor_cb.dcache_stall && (is_branch_e_reg || is_jump_e_reg)) begin
                item = riscv_seq_item::type_id::create("branch_item");
                item.trans_type    = riscv_seq_item::TRANS_BRANCH_TAKEN;
                item.pc            = vif.monitor_cb.pc_e;         
                item.branch_taken  = vif.monitor_cb.pc_src_e;
                item.branch_target = vif.monitor_cb.pc_target_e;  
                item.stall_seen    = vif.monitor_cb.dcache_stall;
                item.decode_instr(instr_e_reg);
                item.timestamp     = $time;

                branch_taken_count++;
                `uvm_info("MONITOR", item.convert2string(), UVM_MEDIUM)
                ap_branch.write(item);
            end

            if (!vif.monitor_cb.dcache_stall) begin
                // Nếu tầng Decode bị stall (do load-use), flush, hoặc tín hiệu rác 
                // -> Tầng E sẽ nhận một bong bóng (bubble), không phải branch
                if (vif.monitor_cb.stall_f || vif.monitor_cb.flush_d || $isunknown(vif.monitor_cb.instr_d)) begin
                    is_branch_e_reg = 1'b0;
                    is_jump_e_reg   = 1'b0;
                end else begin
                    // Nếu hợp lệ, đẩy thông tin lệnh từ D sang E để chu kỳ sau xử lý
                    instr_e_reg     = vif.monitor_cb.instr_d;
                    is_branch_e_reg = vif.monitor_cb.branch_d;
                    is_jump_e_reg   = vif.monitor_cb.jump_d;
                end
            end
        end
    endtask

    // ========================================================
    // Thread 4: Snapshot every decoded instruction
    // ========================================================
    task automatic monitor_all_instrs();
        riscv_seq_item item;
        logic [31:0]   last_instr;

        last_instr = 32'hDEADBEEF;

        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.rst !== 1'b1) continue;
            if (vif.monitor_cb.flush_d === 1'b1) continue;
            if ($isunknown(vif.monitor_cb.instr_d)) continue;
            if (vif.monitor_cb.instr_d === last_instr) continue;

            item = riscv_seq_item::type_id::create("instr_item");
            item.trans_type = riscv_seq_item::TRANS_WAIT_CYCLES;
            item.pc         = vif.monitor_cb.pc_d;
            item.stall_seen = vif.monitor_cb.stall_f |
                              vif.monitor_cb.icache_stall |
                              vif.monitor_cb.dcache_stall;
            item.timestamp  = $time;
            item.decode_instr(vif.monitor_cb.instr_d);

            last_instr = vif.monitor_cb.instr_d;
            ap_instr.write(item);
        end
    endtask

    // ========================================================
    // report_phase: print statistics
    // ========================================================
    function void report_phase(uvm_phase phase);
        string msg;
        msg = "\n=== Monitor Statistics ===\n";
        msg = {msg, $sformatf("  Instruction commits : %0d\n", instr_count)};
        msg = {msg, $sformatf("  Stall cycles        : %0d\n", stall_count)};
        msg = {msg, $sformatf("  Branches taken      : %0d\n", branch_taken_count)};
        msg = {msg, $sformatf("  Memory writes       : %0d\n", mem_write_count)};
        msg = {msg, $sformatf("  Memory reads        : %0d",   mem_read_count)};
        `uvm_info("MONITOR", msg, UVM_NONE)
    endfunction

endclass : riscv_monitor

`endif // RISCV_MONITOR_SV