// ============================================================
// File: riscv_agent.sv
// Description: UVM Agent – bundles sequencer, driver, and
//              monitor into a reusable verification component.
//              Analysis ports are forwarded upward to the env.
// ============================================================

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
`endif
