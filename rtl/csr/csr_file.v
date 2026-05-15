module csr_file (
    input wire clk,
    input wire rst,
    
    // --- Communication with CSR Instructions (from Datapath) ---
    input wire [11:0] csr_raddr,   // Read address from Decode
    input wire [11:0] csr_waddr,   // Write address from Writeback
    input wire csr_we,            // Write Enable signal from Control Unit
    input wire [31:0] csr_wd,     // Data to be written to CSR
    output [31:0] csr_rd,     // Data read from CSR (transferred to rd register)

    // --- Communication with Exception/Trap Handler Block ---
    input wire is_exception,      // Exception flag signal (e.g., ecall instruction encountered)
    input wire [31:0] pc,         // Current PC of the instruction causing the exception
    input wire [31:0] cause,      // Exception cause code (e.g., ecall from M-mode is 11)
    
    output wire [31:0] epc,       // Send mepc to PC multiplexer (to return with mret instruction)
    output wire [31:0] trap_vec   // Send mtvec to PC multiplexer (to jump to trap handler)
);

    // Declaration of common CSR registers in Machine Mode
    reg [31:0] mstatus;  // Address 0x300: Machine status (contains global interrupt enable flag)
    reg [31:0] mtvec;    // Address 0x305: Base address of trap handler (Trap Vector)
    reg [31:0] mscratch; // Address 0x340: Scratch register for OS
    reg [31:0] mepc;     // Address 0x341: Save PC of interrupted instruction to return later
    reg [31:0] mcause;   // Address 0x342: Save cause of interrupt/exception

    // Read Logic with Internal Bypassing
    assign csr_rd = (csr_we && (csr_raddr == csr_waddr)) ? csr_wd :
                    (csr_raddr == 12'h300) ? mstatus :
                    (csr_raddr == 12'h305) ? mtvec   :
                    (csr_raddr == 12'h340) ? mscratch:
                    (csr_raddr == 12'h341) ? mepc    :
                    (csr_raddr == 12'h342) ? mcause  : 32'd0;

    // ---------------- CSR WRITE LOGIC (Sequential) ----------------
    always @(posedge clk) begin
        if (!rst) begin
            // Reset all CSR to 0
            mstatus  <= 32'd0;
            mtvec    <= 32'd0; 
            mscratch <= 32'd0;
            mepc     <= 32'd0;
            mcause   <= 32'd0;
        end else begin  
            // 1. WRITE VIA NORMAL INSTRUCTIONS (csrrw, csrrs, csrrc,...)
            if (csr_we) begin
                case(csr_waddr)
                    12'h300: mstatus  <= csr_wd;
                    12'h305: mtvec    <= csr_wd;
                    12'h340: mscratch <= csr_wd;
                    12'h341: mepc     <= csr_wd;
                    12'h342: mcause   <= csr_wd;
                endcase
            end
            
            // 2. WRITE VIA HARDWARE AUTO-UPDATE ON EXCEPTION (priority higher than instructions)
            if (is_exception) begin
                mepc   <= pc;     // Save the current PC being executed
                mcause <= cause;  // Save error code (e.g., cause is ecall)
                // (In practice, mstatus is also updated here to disable interrupts, but we simplify for now)
            end
        end
    end

    // Push signals out for Datapath to use for PC redirection
    assign epc = mepc;
    assign trap_vec = mtvec;

endmodule