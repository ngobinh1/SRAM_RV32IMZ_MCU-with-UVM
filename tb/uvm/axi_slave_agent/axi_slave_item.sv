`ifndef AXI_SLAVE_ITEM_SV
`define AXI_SLAVE_ITEM_SV

class axi_slave_item extends uvm_sequence_item;
    typedef enum {READ, WRITE} req_type_e;
    rand req_type_e req_type;
    rand bit [31:0] addr;
    rand bit [7:0] len;
    rand bit [31:0] data[];
    rand bit [3:0] strb[];
    rand bit [3:0] id;
    
    `uvm_object_utils_begin(axi_slave_item)
        `uvm_field_enum(req_type_e, req_type, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(len, UVM_ALL_ON)
        `uvm_field_array_int(data, UVM_ALL_ON)
        `uvm_field_array_int(strb, UVM_ALL_ON)
        `uvm_field_int(id, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_slave_item");
        super.new(name);
    endfunction
endclass

`endif
