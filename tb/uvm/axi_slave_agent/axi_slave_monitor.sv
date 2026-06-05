`ifndef AXI_SLAVE_MONITOR_SV
`define AXI_SLAVE_MONITOR_SV

class axi_slave_monitor extends uvm_monitor;
    `uvm_component_utils(axi_slave_monitor)
    
    virtual axi_slave_if vif;
    uvm_analysis_port #(axi_slave_item) ap;

    function new(string name = "axi_slave_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_slave_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    endfunction

    task run_phase(uvm_phase phase);
        // Implementation for monitor can be added here
        // For simplicity, it currently does nothing.
        // It could snoop the bus and broadcast items
    endtask
endclass

`endif
