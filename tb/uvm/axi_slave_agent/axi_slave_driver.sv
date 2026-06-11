`ifndef AXI_SLAVE_DRIVER_SV
`define AXI_SLAVE_DRIVER_SV

class axi_slave_driver extends uvm_driver #(axi_slave_item);
    `uvm_component_utils(axi_slave_driver)
    
    virtual axi_slave_if vif;

    function new(string name = "axi_slave_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_slave_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    endfunction

    task run_phase(uvm_phase phase);
        vif.awready <= 0;
        vif.wready <= 0;
        vif.bvalid <= 0;
        vif.arready <= 0;
        vif.rvalid <= 0;
        
        
        fork
            handle_write();
            handle_read();
        join
    endtask

    task handle_write();
        bit [31:0] waddr;
        bit [7:0] wlen;
        bit [3:0] wid;
        int count;
        forever begin
            @(posedge vif.clk);
            if (vif.awvalid) begin
                repeat($urandom_range(0, 3)) @(posedge vif.clk);
                vif.awready <= 1;
                waddr = vif.awaddr;
                wlen = vif.awlen;
                wid = vif.awid;
                @(posedge vif.clk);
                vif.awready <= 0;
                
                count = 0;
                while (count <= wlen) begin
                    vif.wready <= 0;
                    repeat($urandom_range(0, 3)) @(posedge vif.clk);
                    vif.wready <= 1;
                    @(posedge vif.clk);
                    if (vif.wvalid) begin
                        vif.memory[waddr + count*4] = vif.wdata;
                        if (vif.wlast && count == wlen) begin
                            vif.wready <= 0;
                            break;
                        end
                        count++;
                    end else begin
                        vif.wready <= 0;
                        @(posedge vif.clk iff vif.wvalid);
                        continue;
                    end
                end
                vif.wready <= 0;
                
                repeat($urandom_range(0, 3)) @(posedge vif.clk);
                vif.bvalid <= 1;
                vif.bid <= wid;
                vif.bresp <= 2'b00;
                @(posedge vif.clk iff vif.bready);
                vif.bvalid <= 0;
            end
        end
    endtask

    task handle_read();
        bit [31:0] raddr;
        bit [7:0] rlen;
        bit [3:0] rid;
        int count;
        forever begin
            @(posedge vif.clk);
            if (vif.arvalid) begin
                repeat($urandom_range(0, 3)) @(posedge vif.clk);
                vif.arready <= 1;
                raddr = vif.araddr;
                rlen = vif.arlen;
                rid = vif.arid;
                @(posedge vif.clk);
                vif.arready <= 0;
                
                count = 0;
                while (count <= rlen) begin
                    vif.rvalid <= 0;
                    vif.rlast <= 0;
                    repeat($urandom_range(0, 3)) @(posedge vif.clk);
                    vif.rvalid <= 1;
                    vif.rid <= rid;
                    if (vif.memory.exists(raddr + count*4))
                        vif.rdata <= vif.memory[raddr + count*4];
                    else
                        vif.rdata <= 32'h00000013; // nop instead of deadbeef
                    vif.rresp <= 2'b00;
                    vif.rlast <= (count == rlen);
                    @(posedge vif.clk iff vif.rready);
                    count++;
                end
                vif.rvalid <= 0;
                vif.rlast <= 0;
                vif.rlast <= 0;
            end
        end
    endtask
endclass

`endif
