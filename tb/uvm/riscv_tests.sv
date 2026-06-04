// ============================================================
// File: riscv_tests.sv
// Description: Concrete UVM Test classes – each extends
//              riscv_base_test and starts a specific sequence.
//
//  Tests:
//  1. riscv_alu_test      – full ALU instruction coverage
//  2. riscv_mem_test      – load/store width and alignment
//  3. riscv_branch_test   – branch taken/not-taken
//  4. riscv_hazard_test   – load-use stall detection
//  5. riscv_csr_test      – CSR instructions + ecall/mret
//  6. riscv_full_test     – full regression (all programs)
//  7. riscv_random_test   – randomised stress test
//
//  Run with:
//   +UVM_TESTNAME=riscv_alu_test
//   +UVM_TESTNAME=riscv_full_test
//   etc.
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_agent_env_test.sv" 
`include "riscv_sequences.sv"
`include "riscv_seq_item.sv"
`ifndef RISCV_TESTS_SV
`define RISCV_TESTS_SV

// ============================================================
// Test 1: ALU Test
// ============================================================
class riscv_alu_test extends riscv_base_test;
    `uvm_component_utils(riscv_alu_test)

    function new(string name = "riscv_alu_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "alu_test.hex";
        timeout_cycles = 5_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_alu_test_seq seq;
        seq = riscv_alu_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        do_wait_end(200); // Extra settling time
    endtask

    task do_wait_end(int n);
        vif.wait_clks(n);
    endtask

endclass : riscv_alu_test


// ============================================================
// Test 2: Memory Access Test
// ============================================================
class riscv_mem_test extends riscv_base_test;
    `uvm_component_utils(riscv_mem_test)

    function new(string name = "riscv_mem_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "mem_test.hex";
        timeout_cycles = 8_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_mem_test_seq seq;
        seq = riscv_mem_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(300);
    endtask

endclass : riscv_mem_test


// ============================================================
// Test 3: Branch / Jump Test
// ============================================================
class riscv_branch_test extends riscv_base_test;
    `uvm_component_utils(riscv_branch_test)

    function new(string name = "riscv_branch_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "branch_test.hex";
        timeout_cycles = 6_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_branch_test_seq seq;
        seq = riscv_branch_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(200);
    endtask

endclass : riscv_branch_test


// ============================================================
// Test 4: Load-Use Hazard Test
// ============================================================
class riscv_hazard_test extends riscv_base_test;
    `uvm_component_utils(riscv_hazard_test)

    function new(string name = "riscv_hazard_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "hazard_test.hex";
        timeout_cycles = 4_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_hazard_test_seq seq;
        seq = riscv_hazard_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(200);
    endtask

endclass : riscv_hazard_test


// ============================================================
// Test 5: CSR / Exception Test
// ============================================================
class riscv_csr_test extends riscv_base_test;
    `uvm_component_utils(riscv_csr_test)

    function new(string name = "riscv_csr_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "csr_test.hex";
        timeout_cycles = 3_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_csr_test_seq seq;
        seq = riscv_csr_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(200);
    endtask

endclass : riscv_csr_test

// ============================================================
// Test 6: Mul/Div Test
// ============================================================
class riscv_muldiv_test extends riscv_base_test;
    `uvm_component_utils(riscv_muldiv_test)

    function new(string name = "riscv_muldiv_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "muldiv_test.hex";
        timeout_cycles = 10_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_muldiv_test_seq seq;
        seq = riscv_muldiv_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(300);
    endtask

endclass : riscv_muldiv_test


// ============================================================
// Test 7: Full Regression Test
// ============================================================
class riscv_full_test extends riscv_base_test;
    `uvm_component_utils(riscv_full_test)

    function new(string name = "riscv_full_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "full_test.hex";
        timeout_cycles = 50_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_full_test_seq seq;
        seq = riscv_full_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(500);
    endtask

endclass : riscv_full_test


// ============================================================
// Test 8: Randomised Stress Test
// ============================================================
class riscv_random_test extends riscv_base_test;
    `uvm_component_utils(riscv_random_test)

    int unsigned num_iterations = 3;

    function new(string name = "riscv_random_test", uvm_component parent = null);
        super.new(name, parent);
        timeout_cycles = 100_000;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Allow plusarg override of iterations
        if ($test$plusargs("ITERS"))
            void'($value$plusargs("ITERS=%d", num_iterations));
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_random_seq seq;
        seq = riscv_random_seq::type_id::create("seq");
        assert(seq.randomize() with {
            iterations == local::num_iterations;
        }) else `uvm_fatal("RANDOM_TEST", "Randomization failed")
        seq.start(get_sequencer());
        vif.wait_clks(500);
    endtask

endclass : riscv_random_test

// ============================================================
// Test 9: S-Mode Test
// ============================================================
class riscv_smode_test extends riscv_base_test;
    `uvm_component_utils(riscv_smode_test)

    function new(string name = "riscv_smode_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "smode_test.hex";
        timeout_cycles = 3_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_smode_test_seq seq;
        seq = riscv_smode_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(200);
    endtask

endclass : riscv_smode_test

// ============================================================
// MMU Test
// ============================================================
class riscv_mmu_test extends riscv_base_test;
    `uvm_component_utils(riscv_mmu_test)

    function new(string name = "riscv_mmu_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_body(uvm_phase phase);
        riscv_mmu_test_seq seq;
        seq = riscv_mmu_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
    endtask

endclass : riscv_mmu_test

`endif // RISCV_TESTS_SV