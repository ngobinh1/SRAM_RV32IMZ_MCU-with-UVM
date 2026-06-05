`ifndef AXI_SLAVE_SEQUENCER_SV
`define AXI_SLAVE_SEQUENCER_SV

class axi_slave_sequencer extends uvm_sequencer #(axi_slave_item);
    `uvm_component_utils(axi_slave_sequencer)

    function new(string name = "axi_slave_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif
