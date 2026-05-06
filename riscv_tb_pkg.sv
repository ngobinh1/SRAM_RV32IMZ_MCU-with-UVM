// ============================================================
// File: riscv_tb_pkg.sv
// Description: Package that imports all UVM components in the
//              correct order. Include this package in tb_top.
// ============================================================
`ifndef RISCV_PKG_SV
`define RISCV_PKG_SV
package riscv_tb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Include all testbench files in dependency order
    `include "riscv_seq_item.sv"
    `include "riscv_driver.sv"      // includes riscv_sequencer
    `include "riscv_monitor.sv"
    `include "riscv_scoreboard.sv"
    `include "riscv_coverage.sv"
    `include "riscv_agent_env_test.sv"  // agent + env + base_test
    `include "riscv_sequences.sv"
    `include "riscv_tests.sv"

endpackage : riscv_tb_pkg
`endif