`ifndef AXI_SLAVE_AGENT_SV
`define AXI_SLAVE_AGENT_SV

class axi_slave_agent extends uvm_agent;
    `uvm_component_utils(axi_slave_agent)

    axi_slave_sequencer sqr;
    axi_slave_driver drv;
    axi_slave_monitor mon;

    function new(string name = "axi_slave_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = axi_slave_sequencer::type_id::create("sqr", this);
        drv = axi_slave_driver::type_id::create("drv", this);
        mon = axi_slave_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

`endif
