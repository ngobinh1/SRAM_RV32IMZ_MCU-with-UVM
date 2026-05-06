// ============================================================
// File: riscv_agent.sv
// Description: UVM Agent – bundles sequencer, driver, and
//              monitor into a reusable verification component.
//              Analysis ports are forwarded upward to the env.
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_seq_item.sv"
`include "riscv_driver.sv"      
`include "riscv_monitor.sv"
`include "riscv_scoreboard.sv"
`include "riscv_coverage.sv"
`ifndef RISCV_AGENT_SV
`define RISCV_AGENT_SV

class riscv_agent extends uvm_agent;
    `uvm_component_utils(riscv_agent)

    // Sub-components
    riscv_sequencer sequencer;
    riscv_driver    driver;
    riscv_monitor   monitor;

    // Analysis ports forwarded from monitor
    uvm_analysis_port #(riscv_seq_item) ap_regwrite;
    uvm_analysis_port #(riscv_seq_item) ap_memaccess;
    uvm_analysis_port #(riscv_seq_item) ap_branch;
    uvm_analysis_port #(riscv_seq_item) ap_instr;

    function new(string name = "riscv_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer = riscv_sequencer::type_id::create("sequencer", this);
        driver    = riscv_driver::type_id::create("driver",       this);
        monitor   = riscv_monitor::type_id::create("monitor",     this);

        // Create forwarding ports
        ap_regwrite  = new("ap_regwrite",  this);
        ap_memaccess = new("ap_memaccess", this);
        ap_branch    = new("ap_branch",    this);
        ap_instr     = new("ap_instr",     this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Connect driver to sequencer
        driver.seq_item_port.connect(sequencer.seq_item_export);

        // Forward monitor analysis ports up to agent level
        monitor.ap_regwrite.connect(ap_regwrite);
        monitor.ap_memaccess.connect(ap_memaccess);
        monitor.ap_branch.connect(ap_branch);
        monitor.ap_instr.connect(ap_instr);
    endfunction

endclass : riscv_agent

`endif // RISCV_AGENT_SV


// ============================================================
// File: riscv_env.sv
// Description: UVM Environment – top-level container that
//              instantiates the agent, scoreboard, and
//              coverage collector and wires them together.
// ============================================================

`ifndef RISCV_ENV_SV
`define RISCV_ENV_SV

class riscv_env extends uvm_env;
    `uvm_component_utils(riscv_env)

    // Sub-components
    riscv_agent       agent;
    riscv_scoreboard  scoreboard;
    riscv_coverage    coverage;

    function new(string name = "riscv_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = riscv_agent::type_id::create("agent",      this);
        scoreboard = riscv_scoreboard::type_id::create("scoreboard", this);
        coverage   = riscv_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Connect agent analysis ports to scoreboard exports
        agent.ap_regwrite.connect(scoreboard.ae_regwrite);
        agent.ap_memaccess.connect(scoreboard.ae_memaccess);
        agent.ap_branch.connect(scoreboard.ae_branch);

        // Connect agent instruction port to coverage subscriber
        agent.ap_instr.connect(coverage.analysis_export);

        // Also feed reg-writes to coverage (for register usage)
        agent.ap_regwrite.connect(coverage.analysis_export);
    endfunction

endclass : riscv_env

`endif // RISCV_ENV_SV


// ============================================================
// File: riscv_base_test.sv
// Description: Base UVM Test – provides common setup,
//              timeout, and the virtual interface. Extend
//              this class to create specific test scenarios.
// ============================================================

`ifndef RISCV_BASE_TEST_SV
`define RISCV_BASE_TEST_SV

class riscv_base_test extends uvm_test;
    `uvm_component_utils(riscv_base_test)

    // Environment
    riscv_env env;
    virtual riscv_if vif;

    // Configuration parameters
    int unsigned timeout_cycles = 10_000; // Max sim cycles
    string       hex_file       = "full_test.hex";

    function new(string name = "riscv_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // --------------------------------------------------------
    // build_phase: create env and push interface into config_db
    // --------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Read test-level plusargs
        if ($test$plusargs("TIMEOUT"))
            void'($value$plusargs("TIMEOUT=%d", timeout_cycles));
        if ($test$plusargs("HEX"))
            void'($value$plusargs("HEX=%s", hex_file));
        if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif))
            `uvm_fatal("TEST", "Can't take vif from config_db")

        env = riscv_env::type_id::create("env", this);

        `uvm_info("BASE_TEST",
            $sformatf("Build complete. hex=%0s timeout=%0d cycles",
                      hex_file, timeout_cycles), UVM_MEDIUM)
    endfunction

    // --------------------------------------------------------
    // run_phase: apply timeout watchdog
    // --------------------------------------------------------
    task run_phase(uvm_phase phase);
        phase.raise_objection(this, "base_test running");

        fork
            begin
                run_test_body(phase);
            end
            begin
                // Watchdog timer
                #(timeout_cycles * 10ns); // Assumes 10 ns period
                `uvm_fatal("TIMEOUT",
                    $sformatf("Simulation timeout after %0d cycles", timeout_cycles))
            end
        join_any
        disable fork;

        phase.drop_objection(this, "base_test done");
    endtask

    // --------------------------------------------------------
    // Overridable: subclasses implement test body here
    // --------------------------------------------------------
    virtual task run_test_body(uvm_phase phase);
        `uvm_info("BASE_TEST", "run_test_body() – override in subclass", UVM_MEDIUM)
    endtask

    // --------------------------------------------------------
    // Helper: get shortcut to agent sequencer
    // --------------------------------------------------------
    function riscv_sequencer get_sequencer();
        return env.agent.sequencer;
    endfunction

    // --------------------------------------------------------
    // report_phase
    // --------------------------------------------------------
    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_FATAL) +
            svr.get_severity_count(UVM_ERROR) > 0)
            `uvm_info("BASE_TEST", "TEST FAILED", UVM_NONE)
        else
            `uvm_info("BASE_TEST", "TEST PASSED", UVM_NONE)
    endfunction

endclass : riscv_base_test

`endif // RISCV_BASE_TEST_SV