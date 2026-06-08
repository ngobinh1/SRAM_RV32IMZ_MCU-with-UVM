// ============================================================
// File: riscv_sequencer.sv
// Description: UVM Sequencer – routes sequence items from
//              sequences to the driver.
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "riscv_seq_item.sv"
`ifndef RISCV_SEQUENCER_SV
`define RISCV_SEQUENCER_SV

class riscv_sequencer extends uvm_sequencer #(riscv_seq_item);
    `uvm_component_utils(riscv_sequencer)

    function new(string name = "riscv_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : riscv_sequencer

`endif // RISCV_SEQUENCER_SV


// ============================================================
// File: riscv_driver.sv
// Description: UVM Driver – drives stimulus onto the DUT via
//              the interface.  Handles:
//              1. Reset assertion / deassertion
//              2. Program loading (writes hex into IMEM)
//              3. Clock-cycle waiting
// ============================================================

`ifndef RISCV_DRIVER_SV
`define RISCV_DRIVER_SV

class riscv_driver extends uvm_driver #(riscv_seq_item);
    `uvm_component_utils(riscv_driver)

    // Virtual interface handle
    virtual riscv_if.driver_mp vif;

    // --------------------------------------------------------
    // Constructor
    // --------------------------------------------------------
    function new(string name = "riscv_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // --------------------------------------------------------
    // build_phase: retrieve interface from config_db
    // --------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual riscv_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRIVER", "Cannot get virtual interface from config_db")
    endfunction

    // --------------------------------------------------------
    // run_phase: main driver loop
    // --------------------------------------------------------
    task run_phase(uvm_phase phase);
        riscv_seq_item req;

        // Always start in reset
        drive_reset(1'b0);

        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("DRIVER", $sformatf("Driving: %0s", req.convert2string()), UVM_HIGH)

            case (req.trans_type)
                riscv_seq_item::TRANS_RESET:
                    drive_reset(req.rst_val);

                riscv_seq_item::TRANS_LOAD_PROGRAM:
                    load_program(req.program_hex_file);

                riscv_seq_item::TRANS_WAIT_CYCLES:
                    wait_n_cycles(req.wait_cycles);

                default:
                    `uvm_warning("DRIVER", $sformatf("Unknown trans_type %0s – skipping",
                                 req.trans_type.name()))
            endcase

            seq_item_port.item_done();
        end
    endtask

    // --------------------------------------------------------
    // Task: drive_reset
    //   rst=0 → assert (pipeline in reset)
    //   rst=1 → deassert (pipeline runs)
    // --------------------------------------------------------
    task automatic drive_reset(logic rst_val);
        @(vif.driver_cb);
        vif.driver_cb.rst <= rst_val;
        `uvm_info("DRIVER", $sformatf("RST driven to %0b", rst_val), UVM_MEDIUM)

        if (rst_val == 1'b0) begin
            // Hold reset for at least 10 cycles
            repeat (10) @(vif.driver_cb);
        end else begin
            // After deassert, wait a few cycles for pipeline to fill
            repeat (5) @(vif.driver_cb);
        end
    endtask

    // --------------------------------------------------------
    // Task: load_program
    //   Uses $readmemh() via a DPI/task call into the DUT's
    //   instruction memory. Since IMEM is inside the hierarchy,
    //   we use a hierarchical force or a dedicated task.
    //   In simulation, $readmemh writes directly to the mem array.
    // --------------------------------------------------------
    task automatic load_program(string hex_file);
        // Ensure DUT is in reset while loading
        vif.driver_cb.rst <= 1'b0;
        repeat (3) @(vif.driver_cb);

        // Load program into instruction memory (hierarchical reference)
        // The DUT path: tb_top.dut.fetch_stage.instruction_memory.mem
        `uvm_info("DRIVER", $sformatf("Loading program via VIF: %0s", hex_file), UVM_MEDIUM)
        vif.clear_dmem();
        vif.load_imem(hex_file); 
        @(vif.driver_cb);
    endtask

    // --------------------------------------------------------
    // Task: wait_n_cycles
    // --------------------------------------------------------
    task automatic wait_n_cycles(int n);
        repeat (n) @(vif.driver_cb);
    endtask

endclass : riscv_driver

`endif // RISCV_DRIVER_SV