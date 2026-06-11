// ============================================================
// File: riscv_sequences.sv
// Description: Library of UVM Sequences for the RISC-V
//              pipeline testbench.
//
//  Sequences provided:
//  1.  riscv_reset_seq          – assert/deassert reset
//  2.  riscv_load_program_seq   – load a hex file + release reset
//  3.  riscv_run_seq            – wait N cycles after program load
//  4.  riscv_alu_test_seq       – load ALU-focused test program
//  5.  riscv_mem_test_seq       – load memory-access test program
//  6.  riscv_branch_test_seq    – load branch/jump test program
//  7.  riscv_hazard_test_seq    – load load-use hazard test
//  8.  riscv_csr_test_seq       – load CSR/ecall test program
//  9.
//  10.
//  11.
//  12.  riscv_full_test_seq      – composite: runs all sub-tests
//  13. riscv_random_seq         – randomised program selection
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_seq_item.sv"
`ifndef RISCV_SEQUENCES_SV
`define RISCV_SEQUENCES_SV

// ============================================================
// Base sequence: common plumbing
// ============================================================
class riscv_base_seq extends uvm_sequence #(riscv_seq_item);
    `uvm_object_utils(riscv_base_seq)

    function new(string name = "riscv_base_seq");
        super.new(name);
    endfunction

    // Helper: create and send a RESET transaction
    task do_reset(bit rst_val);
        riscv_seq_item item;
        item = riscv_seq_item::type_id::create("reset_item");
        start_item(item);
        item.trans_type = riscv_seq_item::TRANS_RESET;
        item.rst_val    = rst_val;
        finish_item(item);
    endtask

    // Helper: create and send a LOAD_PROGRAM transaction
    task do_load(string hex_file);
        riscv_seq_item item;
        item = riscv_seq_item::type_id::create("load_item");
        start_item(item);
        item.trans_type      = riscv_seq_item::TRANS_LOAD_PROGRAM;
        item.program_hex_file = hex_file;
        finish_item(item);
    endtask

    // Helper: create and send a WAIT_CYCLES transaction
    task do_wait(int unsigned n_cycles);
        riscv_seq_item item;
        item = riscv_seq_item::type_id::create("wait_item");
        start_item(item);
        item.trans_type  = riscv_seq_item::TRANS_WAIT_CYCLES;
        item.wait_cycles = n_cycles;
        finish_item(item);
    endtask

endclass : riscv_base_seq


// ============================================================
// 1. Reset Sequence
//    Assert reset for 20 cycles, then deassert
// ============================================================
class riscv_reset_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_reset_seq)

    int unsigned hold_cycles = 20;

    function new(string name = "riscv_reset_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("RESET_SEQ", "Asserting reset", UVM_MEDIUM)
        do_reset(1'b0);            // Assert reset (active-low)
        do_wait(hold_cycles);
        `uvm_info("RESET_SEQ", "Deasserting reset", UVM_MEDIUM)
        do_reset(1'b1);            // Deassert reset
        do_wait(5);                // Pipeline fill delay
    endtask

endclass : riscv_reset_seq


// ============================================================
// 2. Load Program Sequence
//    Assert reset → load hex → deassert reset
// ============================================================
class riscv_load_program_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_load_program_seq)

    string hex_file = "full_test.hex";

    function new(string name = "riscv_load_program_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("LOAD_SEQ", $sformatf("Loading: %0s", hex_file), UVM_MEDIUM)
        do_reset(1'b0);    // Assert reset (memory safe to write)
        do_load(hex_file); // Load program into IMEM
        do_wait(5);
        do_reset(1'b1);    // Deassert reset → pipeline starts
        do_wait(10);       // Allow pipeline to fill
    endtask

endclass : riscv_load_program_seq


// ============================================================
// 3. Run Sequence – waits for program execution to complete
// ============================================================
class riscv_run_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_run_seq)

    int unsigned run_cycles = 1000;

    function new(string name = "riscv_run_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("RUN_SEQ", $sformatf("Running for %0d cycles", run_cycles), UVM_MEDIUM)
        do_wait(run_cycles);
    endtask

endclass : riscv_run_seq


// ============================================================
// 4. ALU Test Sequence
//    Tests all R-type and I-type ALU operations
//    Expected hex file exercises: ADD SUB AND OR XOR
//    SLT SLTU SLL SRL SRA + all immediate variants
// ============================================================
class riscv_alu_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_alu_test_seq)

    function new(string name = "riscv_alu_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("ALU_TEST", "Starting ALU test sequence", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "alu_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("ALU_TEST", "ALU test sequence complete", UVM_MEDIUM)
    endtask

endclass : riscv_alu_test_seq


// ============================================================
// 5. Memory Test Sequence
//    Tests LW/LH/LB/LHU/LBU, SW/SH/SB with various offsets
// ============================================================
class riscv_mem_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_mem_test_seq)

    function new(string name = "riscv_mem_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("MEM_TEST", "Starting memory access test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "mem_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("MEM_TEST", "Memory test complete", UVM_MEDIUM)
    endtask

endclass : riscv_mem_test_seq


// ============================================================
// 6. Branch Test Sequence
//    Tests BEQ/BNE/BLT/BGE/BLTU/BGEU taken + not-taken
//    Also tests JAL and JALR
// ============================================================
class riscv_branch_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_branch_test_seq)

    function new(string name = "riscv_branch_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("BRANCH_TEST", "Starting branch/jump test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "branch_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("BRANCH_TEST", "Branch test complete", UVM_MEDIUM)
    endtask

endclass : riscv_branch_test_seq


// ============================================================
// 7. Load-Use Hazard Test Sequence
//    Exercises load-use stalls: LW followed immediately by
//    instruction that uses the loaded value
// ============================================================
class riscv_hazard_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_hazard_test_seq)

    function new(string name = "riscv_hazard_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("HAZARD_TEST", "Starting load-use hazard test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "hazard_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("HAZARD_TEST", "Hazard test complete", UVM_MEDIUM)
    endtask

endclass : riscv_hazard_test_seq


// ============================================================
// 8. CSR / ECALL Test Sequence
//    Tests CSRRW/CSRRS/CSRRC and ecall trap + mret
// ============================================================
class riscv_csr_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_csr_test_seq)

    function new(string name = "riscv_csr_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("CSR_TEST", "Starting CSR/ecall test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "csr_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("CSR_TEST", "CSR test complete", UVM_MEDIUM)
    endtask

endclass : riscv_csr_test_seq

// ============================================================
// 9. Extra coverage Test Sequence
// ============================================================
class riscv_extra_coverage_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_extra_coverage_seq)
    function new(string name = "riscv_extra_coverage_seq");
        super.new(name);
    endfunction
    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;
        `uvm_info("EXTRA_COV", "Starting Extra Coverage test", UVM_MEDIUM)
        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "extra_coverage.hex";
        load_seq.start(m_sequencer);
        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);
    endtask
endclass : riscv_extra_coverage_seq

// ============================================================
// 10. Mul/Div Test Sequence
// ============================================================
class riscv_muldiv_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_muldiv_test_seq)

    function new(string name = "riscv_muldiv_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("MULDIV_TEST", "Starting Mul/Div test sequence", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "muldiv_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("MULDIV_TEST", "Mul/Div test sequence complete", UVM_MEDIUM)
    endtask

endclass : riscv_muldiv_test_seq

// ============================================================
// 11. Interrupt Test Sequence
// ============================================================
class riscv_interrupt_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_interrupt_test_seq)

    function new(string name = "riscv_interrupt_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("INTERRUPT_TEST", "Starting interrupt test sequence", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "int_exc_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        `uvm_info("INTERRUPT_TEST", "Interrupt test sequence complete", UVM_MEDIUM)
    endtask

endclass : riscv_interrupt_test_seq

// ============================================================
// 12. Full Test Sequence
//    Composite: runs ALL sub-test sequences back-to-back.
//    Each sub-test applies its own reset + load.
// ============================================================
class riscv_full_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_full_test_seq)

    function new(string name = "riscv_full_test_seq");
        super.new(name);
    endfunction

    task body();
        // ----------------------------------------------------
        // VARIABLE DECLARATION (All must be here)
        // ----------------------------------------------------
        riscv_load_program_seq   full_load_seq; // Rename to match
        riscv_run_seq            run_seq;       // Move to top
        
        riscv_alu_test_seq       alu_seq;
        riscv_mem_test_seq       mem_seq;
        riscv_branch_test_seq    brnch_seq;
        riscv_hazard_test_seq    haz_seq;
        riscv_csr_test_seq       csr_seq;
        riscv_extra_coverage_seq extra_seq;
        riscv_muldiv_test_seq    muldiv_seq;
        riscv_interrupt_test_seq int_exc_seq;

        `uvm_info("FULL_TEST", "=== Starting full regression ===", UVM_NONE)

        alu_seq       = riscv_alu_test_seq::type_id::create("alu_seq");
        mem_seq       = riscv_mem_test_seq::type_id::create("mem_seq");
        brnch_seq     = riscv_branch_test_seq::type_id::create("brnch_seq");
        haz_seq       = riscv_hazard_test_seq::type_id::create("haz_seq");
        csr_seq       = riscv_csr_test_seq::type_id::create("csr_seq");
        extra_seq     = riscv_extra_coverage_seq::type_id::create("extra_seq");
        muldiv_seq    = riscv_muldiv_test_seq::type_id::create("muldiv_seq");
        int_exc_seq   = riscv_interrupt_test_seq::type_id::create("int_exc_seq");
        full_load_seq = riscv_load_program_seq::type_id::create("full_load_seq");
        run_seq       = riscv_run_seq::type_id::create("run_seq");

        full_load_seq.hex_file = "full_test.hex";
        full_load_seq.start(m_sequencer);

        run_seq.run_cycles = 2000;
        run_seq.start(m_sequencer);

        alu_seq.start(m_sequencer);
        mem_seq.start(m_sequencer);
        brnch_seq.start(m_sequencer);
        haz_seq.start(m_sequencer);
        csr_seq.start(m_sequencer);
        extra_seq.start(m_sequencer);
        muldiv_seq.start(m_sequencer);
        int_exc_seq.start(m_sequencer);

        `uvm_info("FULL_TEST", "=== Full regression complete ===", UVM_NONE)
    endtask

endclass : riscv_full_test_seq


// ============================================================
// 13. Randomised Sequence
//     Randomly selects one of the available test programs
//     and a random run duration – useful for stress testing
// ============================================================
class riscv_random_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_random_seq)

    rand int unsigned iterations;
    rand int unsigned run_cycles_per_iter;

    // Array of available hex programs
    string hex_programs[] = '{
        "alu_test.hex",
        "mem_test.hex",
        "branch_test.hex",
        "hazard_test.hex",
        "csr_test.hex",
        "full_test.hex",
        "extra_coverage.hex",
        "muldiv_test.hex",
        "smode_test.hex",
        "mmu_test.hex"
    };

    constraint c_iters  { iterations inside {[1:5]}; }
    constraint c_cycles { run_cycles_per_iter inside {[200:2000]}; }

    function new(string name = "riscv_random_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;
        int unsigned           prog_idx;

        `uvm_info("RANDOM_SEQ",
            $sformatf("Random test: %0d iterations, %0d cycles each",
                      iterations, run_cycles_per_iter), UVM_MEDIUM)

        for (int i = 0; i < int'(iterations); i++) begin
            prog_idx = $urandom_range(0, hex_programs.size()-1);

            `uvm_info("RANDOM_SEQ",
                $sformatf("Iter %0d: program=%0s", i, hex_programs[prog_idx]),
                UVM_MEDIUM)

            load_seq = riscv_load_program_seq::type_id::create("load_seq");
            load_seq.hex_file = hex_programs[prog_idx];
            load_seq.start(m_sequencer);

            run_seq = riscv_run_seq::type_id::create("run_seq");
            run_seq.run_cycles = run_cycles_per_iter;
            run_seq.start(m_sequencer);
        end
    endtask

endclass : riscv_random_seq

// ============================================================
// 11. S-Mode Test Sequence
// ============================================================
class riscv_smode_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_smode_test_seq)

    function new(string name = "riscv_smode_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("SMODE_TEST", "Starting S-Mode test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "smode_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 1000;
        run_seq.start(m_sequencer);

        `uvm_info("SMODE_TEST", "S-Mode test complete", UVM_MEDIUM)
    endtask

endclass : riscv_smode_test_seq

// ============================================================
// 12. MMU Test Sequence
// ============================================================
class riscv_mmu_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_mmu_test_seq)

    function new(string name = "riscv_mmu_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("MMU_TEST", "Starting MMU Page Table Walker test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "mmu_deep_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 1000;
        run_seq.start(m_sequencer);

        `uvm_info("MMU_TEST", "MMU test complete", UVM_MEDIUM)
    endtask

endclass : riscv_mmu_test_seq


// ============================================================
// 13. S-Mode and MMU Random Test Sequence
// ============================================================
class riscv_smode_mmu_random_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_smode_mmu_random_seq)

    rand int unsigned iterations;
    rand int unsigned run_cycles_per_iter;

    string hex_programs[] = '{
        "smode_test.hex",
        "mmu_test.hex",
        "mmu_deep_test.hex"
    };

    constraint c_iters  { iterations inside {[2:5]}; }
    constraint c_cycles { run_cycles_per_iter inside {[500:2000]}; }

    function new(string name = "riscv_smode_mmu_random_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;
        int unsigned           prog_idx;

        `uvm_info("SMODE_MMU_RAND_SEQ",
            $sformatf("Random test: %0d iterations, %0d cycles each",
                      iterations, run_cycles_per_iter), UVM_MEDIUM)

        for (int i = 0; i < int'(iterations); i++) begin
            prog_idx = $urandom_range(0, hex_programs.size()-1);

            `uvm_info("SMODE_MMU_RAND_SEQ",
                $sformatf("Iter %0d: program=%0s", i, hex_programs[prog_idx]),
                UVM_MEDIUM)

            load_seq = riscv_load_program_seq::type_id::create("load_seq");
            load_seq.hex_file = hex_programs[prog_idx];
            load_seq.start(m_sequencer);

            run_seq = riscv_run_seq::type_id::create("run_seq");
            run_seq.run_cycles = run_cycles_per_iter;
            run_seq.start(m_sequencer);
        end
    endtask
endclass : riscv_smode_mmu_random_seq

// ============================================================
// 14. Store Buffer Forwarding Test Sequence
// ============================================================
class riscv_sb_fwd_test_seq extends riscv_base_seq;
    `uvm_object_utils(riscv_sb_fwd_test_seq)

    function new(string name = "riscv_sb_fwd_test_seq");
        super.new(name);
    endfunction

    task body();
        riscv_load_program_seq load_seq;
        riscv_run_seq          run_seq;

        `uvm_info("SB_FWD_TEST", "Starting Store Buffer Forwarding test", UVM_MEDIUM)

        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = "sb_fwd_test.hex";
        load_seq.start(m_sequencer);

        run_seq = riscv_run_seq::type_id::create("run_seq");
        run_seq.run_cycles = 1000;
        run_seq.start(m_sequencer);

        `uvm_info("SB_FWD_TEST", "Store Buffer Forwarding test complete", UVM_MEDIUM)
    endtask

endclass : riscv_sb_fwd_test_seq

`endif // RISCV_SEQUENCES_SV
