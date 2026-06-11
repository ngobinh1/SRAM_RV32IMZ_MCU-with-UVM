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
//  7. riscv_smode_test    - Supervisor mode test
//  8. riscv_mmu_test      - MMU address translation test
//  9. riscv_random_test   – randomised stress test
//  10. riscv_smode_mmu_random_test – randomised S-Mode + MMU test
//  11. riscv_custom_hex_test – run any custom hex file with plusarg overrides
//  12. riscv_interrupt_test – test external and timer interrupts
//
//  Run with:
//   +UVM_TESTNAME=riscv_alu_test
//   +UVM_TESTNAME=riscv_full_test
//   +UVM_TESTNAME=riscv_smode_test
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
// Test 7: Supervisor Mode Test
// ============================================================
class riscv_smode_test extends riscv_base_test;
    `uvm_component_utils(riscv_smode_test)

    function new(string name = "riscv_smode_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "smode_test.hex";
        timeout_cycles = 10_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_smode_test_seq seq;
        seq = riscv_smode_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(500);
    endtask

endclass : riscv_smode_test

// ============================================================
// Test 8: MMU Translation Test
// ============================================================
class riscv_mmu_test extends riscv_base_test;
    `uvm_component_utils(riscv_mmu_test)

    function new(string name = "riscv_mmu_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "mmu_test.hex";
        timeout_cycles = 10_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_mmu_test_seq seq;
        seq = riscv_mmu_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(500);
    endtask

endclass : riscv_mmu_test

// ============================================================
// Test 9: Randomised Stress Test
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
// S-Mode and MMU Random Test
// ============================================================
class riscv_smode_mmu_random_test extends riscv_base_test;
    `uvm_component_utils(riscv_smode_mmu_random_test)

    function new(string name = "riscv_smode_mmu_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_body(uvm_phase phase);
        riscv_smode_mmu_random_seq seq;
        seq = riscv_smode_mmu_random_seq::type_id::create("seq");
        if (!seq.randomize()) `uvm_fatal("RANDOM_TEST", "Randomization failed")
        seq.start(get_sequencer());
    endtask

endclass : riscv_smode_mmu_random_test

// ============================================================
// Custom Hex Test
// ============================================================
class riscv_custom_hex_test extends riscv_base_test;
    `uvm_component_utils(riscv_custom_hex_test)

    int unsigned test_timeout;

    function new(string name = "riscv_custom_hex_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        test_timeout = timeout_cycles;
        // Increase the watchdog timer to give test_timeout cycles enough time to run
        timeout_cycles = test_timeout + 1000;
    endfunction

    virtual task run_test_body(uvm_phase phase);
        riscv_load_program_seq load_seq;
        `uvm_info("CUSTOM_HEX_TEST", $sformatf("Starting custom hex test with file: %0s, timeout: %0d", hex_file, test_timeout), UVM_LOW)
        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = hex_file;
        load_seq.start(get_sequencer());
        vif.wait_clks(test_timeout);
    endtask

endclass : riscv_custom_hex_test

class riscv_interrupt_test extends riscv_base_test;
    `uvm_component_utils(riscv_interrupt_test)

    function new(string name = "riscv_interrupt_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file = "int_exc_test.hex";
        timeout_cycles = 15_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_load_program_seq load_seq;
        load_seq = riscv_load_program_seq::type_id::create("load_seq");
        load_seq.hex_file = hex_file;
        load_seq.start(get_sequencer());
        
        vif.wait_clks(2000);

        `uvm_info("INT_TEST", "Asserting Machine Timer Interrupt (MTIP)", UVM_NONE)
        vif.mtip = 1'b1;
        vif.wait_clks(20);
        vif.mtip = 1'b0; 
        vif.wait_clks(500);

        `uvm_info("INT_TEST", "Asserting Machine External Interrupt (MEIP)", UVM_NONE)
        vif.meip = 1'b1;
        vif.wait_clks(20);
        vif.meip = 1'b0;
        vif.wait_clks(500);
    endtask
endclass

// ============================================================
// Store Buffer Forwarding Test
// ============================================================
class riscv_sb_fwd_test extends riscv_base_test;
    `uvm_component_utils(riscv_sb_fwd_test)

    function new(string name = "riscv_sb_fwd_test", uvm_component parent = null);
        super.new(name, parent);
        hex_file       = "sb_fwd_test.hex";
        timeout_cycles = 3_000;
    endfunction

    task run_test_body(uvm_phase phase);
        riscv_sb_fwd_test_seq seq;
        seq = riscv_sb_fwd_test_seq::type_id::create("seq");
        seq.start(get_sequencer());
        vif.wait_clks(200);
    endtask

endclass : riscv_sb_fwd_test

`endif // RISCV_TESTS_SV