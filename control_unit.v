module control_unit(
    input  [6:0] op, funct7,
    input  [2:0] funct3,
    input  [11:0] imm12,
    output  reg_write, mem_write, alu_src, jump, branch, jalr,
    output  [2:0] result_src, 
    output  [2:0] imm_src, 
    output  [3:0] alu_control,
    output csr_we, is_ecall, is_mret
);
    wire [1:0] alu_op;
    wire reg_write_raw;
    // Generate synthetic funct3 for LUI and AUIPC to distinguish them
    wire [2:0] funct3_modified;

    // CSR and EXCEPTION handling
    wire is_system = (op == 7'b1110011);

    // ecall and mret detection
    // ecall: opcode=1110011, funct3=000, imm12=0 | ebreak : opcode=1110011, funct3=000, imm12=1
    // mret: opcode=1110011, funct3=000, imm12=0x302
    assign is_ecall = is_system && (funct3 == 3'b000) && (imm12 == 12'b000000000000);
    assign is_mret  = is_system && (funct3 == 3'b000) && (imm12 == 12'b001100000010);

    // CSR write enable: only for system instructions that are not ecall or mret
    assign csr_we = is_system && (funct3 != 3'b000);

    // ecall, ebreak, and mret should not write to registers or memory
    assign reg_write = reg_write_raw && !(is_ecall | is_mret);
    
    // For LUI (0110111), use funct3=001
    // For AUIPC (0010111), use funct3=000
    assign funct3_modified = (op == 7'b0110111) ? 3'b001 :  // LUI
                            (op == 7'b0010111) ? 3'b000 :  // AUIPC
                            funct3;                         // Normal instructions

    main_decoder main_decoder(
        .op(op),
        .result_src(result_src),
        .imm_src(imm_src),
        .alu_op(alu_op),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write_raw),
        .jump(jump),
        .branch(branch),
        .jalr(jalr)
    );

    alu_decoder alu_decoder(
        .alu_op(alu_op),
        .funct3(funct3_modified),
        .funct7(funct7),
        .op(op),
        .alu_control(alu_control)
    );
endmodule