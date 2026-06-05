
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
    axi_slave_agent   axi_agent;

    function new(string name = "riscv_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = riscv_agent::type_id::create("agent",      this);
        scoreboard = riscv_scoreboard::type_id::create("scoreboard", this);
        coverage   = riscv_coverage::type_id::create("coverage", this);
        axi_agent  = axi_slave_agent::type_id::create("axi_agent", this);
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
        agent.ap_memaccess.connect(coverage.analysis_export);
        agent.ap_branch.connect(coverage.analysis_export);
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
    virtual axi_slave_if vif_axi;

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
        if (!uvm_config_db#(virtual axi_slave_if)::get(this, "", "vif", vif_axi))
            `uvm_fatal("TEST", "Can't take vif_axi from config_db")

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