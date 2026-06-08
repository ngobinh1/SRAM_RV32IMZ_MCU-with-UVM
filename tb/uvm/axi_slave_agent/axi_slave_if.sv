interface axi_slave_if #(parameter DATA_WIDTH = 32, parameter ADDR_WIDTH = 32, parameter ID_WIDTH = 4) (input clk, input rst_n);
    // Write Address Channel
    logic [ID_WIDTH-1:0] awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;
    logic awvalid;
    logic awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic wlast;
    logic wvalid;
    logic wready;

    // Write Response Channel
    logic [ID_WIDTH-1:0] bid;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;

    // Read Address Channel
    logic [ID_WIDTH-1:0] arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0] arlen;
    logic [2:0] arsize;
    logic [1:0] arburst;
    logic arvalid;
    logic arready;

    // Read Data Channel
    logic [ID_WIDTH-1:0] rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rlast;
    logic rvalid;
    logic rready;

    // Shared memory array for the AXI Slave Driver
    bit [31:0] memory[bit [31:0]];

    task automatic load_mem(string hex_file);
        // We load into a temporary array and copy, because $readmemh doesn't support associative arrays directly
        bit [31:0] temp_mem [0:4095];
        for (int i=0; i<4096; i++) temp_mem[i] = 32'h0;
        $readmemh(hex_file, temp_mem);
        memory.delete();
        for (int i=0; i<4096; i++) begin
            if (temp_mem[i] != 32'h0) begin
                memory[i*4] = temp_mem[i];
            end
        end
        $display("AXI SLAVE IF: Loaded %s into memory", hex_file);
    endtask

    modport slave (
        input clk, rst_n,
        input awid, awaddr, awlen, awsize, awburst, awvalid,
        output awready,
        input wdata, wstrb, wlast, wvalid,
        output wready,
        output bid, bresp, bvalid,
        input bready,
        input arid, araddr, arlen, arsize, arburst, arvalid,
        output arready,
        output rid, rdata, rresp, rlast, rvalid,
        input rready
    );
endinterface
