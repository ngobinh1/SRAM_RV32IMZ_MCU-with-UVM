module csr_file (
    input wire clk,
    input wire rst,
    
    // --- Communication with CSR Instructions (from Datapath) ---
    input wire [11:0] csr_raddr,   // Read address from Decode
    input wire [11:0] csr_waddr,   // Write address from Writeback
    input wire csr_we,            // Write Enable signal from Control Unit
    input wire [31:0] csr_wd,     // Data to be written to CSR
    output reg [31:0] csr_rd,     // Data read from CSR (transferred to rd register)

    // --- Communication with Exception/Trap Handler Block ---
    input wire is_exception,      // Exception flag signal
    input wire [31:0] pc,         // Current PC of the instruction causing the exception
    input wire [31:0] cause,      // Exception cause code
    input wire is_mret,           // mret instruction
    input wire is_sret,           // sret instruction
    
    output wire [31:0] epc,       // Send mepc/sepc to PC multiplexer
    output wire [31:0] trap_vec,  // Send mtvec/stvec to PC multiplexer
    output wire [1:0] current_prv, // Current privilege level
    output wire [31:0] satp_out,   // SATP for MMU
    output wire [31:0] mstatus_out // MSTATUS for MMU (contains SUM, MXR)
);

    // Privilege modes
    localparam PRV_U = 2'b00;
    localparam PRV_S = 2'b01;
    localparam PRV_M = 2'b11;

    reg [1:0] prv;

    // Machine Mode CSRs
    reg [31:0] mstatus;
    reg [31:0] mtvec; 
    reg [31:0] mscratch;
    reg [31:0] mepc;  
    reg [31:0] mcause;
    reg [31:0] medeleg;
    reg [31:0] mideleg;

    // Supervisor Mode CSRs
    reg [31:0] stvec;
    reg [31:0] sscratch;
    reg [31:0] sepc;
    reg [31:0] scause;
    reg [31:0] satp;

    // sstatus is a restricted view of mstatus
    wire [31:0] sstatus = mstatus & 32'h000DE122; // Mask for SPP, SPIE, SIE, etc.

    assign current_prv = prv;
    assign satp_out = satp;
    assign mstatus_out = mstatus;

    // Exception delegation logic (simplified)
    // If the cause bit in medeleg is set, and we are in S or U mode, delegate to S mode.
    wire delegate_to_s = (prv <= PRV_S) && (medeleg[cause[4:0]]);

    // Trap PC logic
    assign trap_vec = delegate_to_s ? stvec : mtvec;
    assign epc = is_mret ? mepc : (is_sret ? sepc : 32'h0);

    // Read Logic
    always @(*) begin
        if (csr_we && (csr_raddr == csr_waddr)) begin
            csr_rd = csr_wd;
        end else begin
            case (csr_raddr)
                // Machine Mode
                12'h300: csr_rd = mstatus;
                12'h302: csr_rd = medeleg;
                12'h303: csr_rd = mideleg;
                12'h305: csr_rd = mtvec;
                12'h340: csr_rd = mscratch;
                12'h341: csr_rd = mepc;
                12'h342: csr_rd = mcause;
                // Supervisor Mode
                12'h100: csr_rd = sstatus;
                12'h105: csr_rd = stvec;
                12'h140: csr_rd = sscratch;
                12'h141: csr_rd = sepc;
                12'h142: csr_rd = scause;
                12'h180: csr_rd = satp;
                default: csr_rd = 32'd0;
            endcase
        end
    end

    // Write Logic
    always @(posedge clk) begin
        if (!rst) begin
            mstatus  <= 32'd0;
            medeleg  <= 32'd0;
            mideleg  <= 32'd0;
            mtvec    <= 32'd0; 
            mscratch <= 32'd0;
            mepc     <= 32'd0;
            mcause   <= 32'd0;
            stvec    <= 32'd0;
            sscratch <= 32'd0;
            sepc     <= 32'd0;
            scause   <= 32'd0;
            satp     <= 32'd0;
            prv      <= PRV_M; // Start in Machine mode
        end else begin  
            // 1. Hardware Exception Handling
            if (is_exception) begin
                if (delegate_to_s) begin
                    sepc   <= pc;
                    scause <= cause;
                    // Update sstatus (SPP, SPIE, SIE) inside mstatus
                    mstatus[8] <= prv[0]; // SPP = prv (bit 0 since S=1, U=0)
                    mstatus[5] <= mstatus[1]; // SPIE = SIE
                    mstatus[1] <= 1'b0; // SIE = 0
                    prv <= PRV_S;
                end else begin
                    mepc   <= pc;
                    mcause <= cause;
                    // Update mstatus (MPP, MPIE, MIE)
                    mstatus[12:11] <= prv; // MPP = prv
                    mstatus[7] <= mstatus[3]; // MPIE = MIE
                    mstatus[3] <= 1'b0; // MIE = 0
                    prv <= PRV_M;
                end
            end 
            else if (is_mret) begin
                prv <= mstatus[12:11]; // prv = MPP
                mstatus[3] <= mstatus[7]; // MIE = MPIE
                mstatus[12:11] <= PRV_U; // MPP = U
            end
            else if (is_sret) begin
                prv <= {1'b0, mstatus[8]}; // prv = SPP (0 or 1)
                mstatus[1] <= mstatus[5]; // SIE = SPIE
                mstatus[8] <= 1'b0; // SPP = U
            end
            // 2. Normal CSR Write (csrrw, etc.)
            else if (csr_we) begin
                case(csr_waddr)
                    12'h300: mstatus  <= csr_wd;
                    12'h302: medeleg  <= csr_wd;
                    12'h303: mideleg  <= csr_wd;
                    12'h305: mtvec    <= csr_wd;
                    12'h340: mscratch <= csr_wd;
                    12'h341: mepc     <= csr_wd;
                    12'h342: mcause   <= csr_wd;
                    12'h100: mstatus  <= (mstatus & ~32'h000DE122) | (csr_wd & 32'h000DE122);
                    12'h105: stvec    <= csr_wd;
                    12'h140: sscratch <= csr_wd;
                    12'h141: sepc     <= csr_wd;
                    12'h142: scause   <= csr_wd;
                    12'h180: satp     <= csr_wd;
                endcase
            end
        end
    end

endmodule