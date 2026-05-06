# =========================================================================
# PART 1: TEST DATA HAZARDS (EX-to-EX Data Forwarding)
# =========================================================================
# U-Type Instructions
lui x1, 0x12345        # x1 = 0x12345000
auipc x2, 0            # x2 = Current PC (0x00000004)

# I-Type ALU Instructions (Using negative numbers to test 2's complement)
addi x3, x0, -10       # x3 = -10 (0xFFFFFFF6)
xori x4, x3, 15        # x4 = -10 ^ 15 (EX-to-EX forwarding from x3)
ori x5, x0, 15         # x5 = 15
andi x6, x5, 15        # x6 = 15

# R-Type Instructions
add x7, x4, x3         # x7 = x4 + x3 (Forwarding from multiple stages)
sub x8, x4, x3         # x8 = x4 - x3
and x9, x7, x5         # x9 = x7 & x5
or x10, x6, x8         # x10 = x6 | x8
xor x11, x10, x8       # x11 = x10 ^ x8

# =========================================================================
# PART 2: TEST SHIFT AND COMPARE (Signed & Unsigned)
# =========================================================================
addi x12, x0, 2
slli x13, x12, 2       # SLLI: x13 = 2 << 2 = 8
slli x14, x7, 1        # Shift negative number: 0xFFFFFFFF << 1 = 0xFFFFFFFE (-2)
srli x15, x14, 1       # Logical shift right: Insert 0 into MSB (0x7FFFFFFF)
srai x16, x14, 1       # Arithmetic shift right: Keep MSB unchanged (0xFFFFFFFF)
sll x17, x12, x12      # SLL by register
srl x18, x15, x12      # SRL by register
sra x19, x16, x12      # SRA by register

slti x20, x8, 20       # SLTI: 19 < 20 -> x20 = 1
sltiu x21, x3, 20      # SLTIU: 0xFFFFFFF6 < 20 (Unsigned) -> x21 = 0
slt x22, x3, x8        # SLT: -10 < 19 -> x22 = 1
sltu x23, x3, x8       # SLTU: 0xFFFFFFF6 < 19 (Unsigned) -> x23 = 0

# =========================================================================
# PART 3: TEST LOAD-USE HAZARD (Pipeline Stall) AND MEMORY ACCESS
# =========================================================================
lui x24, 1             # Base address: x24 = 0x1000
sw x8, 0(x24)          # Store Word (19) to 0x1000
sh x13, 4(x24)         # Store Halfword (8) to 0x1004
sb x7, 6(x24)          # Store Byte (0xFF) to 0x1006

lw x25, 0(x24)         # Load Word: Read 19 into x25
add x26, x25, x0       # LETHAL HAZARD: ADD calls x25 right after LW. 
                       # Hazard Unit MUST stall the pipeline for 1 cycle!

lh x27, 4(x24)         # Load Halfword (Sign-extend)
lhu x28, 6(x24)        # Load Halfword Unsigned (Zero-extend)
lb x29, 6(x24)         # Load Byte (Will be extended to 0xFFFFFFFF since MSB = 1)
lbu x30, 6(x24)        # Load Byte Unsigned (Will be 0x000000FF)

# =========================================================================
# PART 4: TEST CONTROL HAZARDS (Control Flow & Pipeline Flush)
# =========================================================================
beq x25, x26, +8       # 19 == 19 -> Branch taken, flush 2 fetched instructions
addi x31, x0, -1       # TRAP (Will be skipped)
bne x25, x0, +8        # 19 != 0 -> Jump
addi x31, x0, -2       # TRAP
blt x3, x8, +8         # -10 < 19 -> Jump
addi x31, x0, -3       # TRAP
bge x8, x3, +8         # 19 >= -10 -> Jump
addi x31, x0, -4       # TRAP
bltu x8, x3, +8        # 19 < 0xFFFFFFF6 -> Jump
addi x31, x0, -5       # TRAP
bgeu x3, x8, +8        # 0xFFFFFFF6 >= 19 -> Jump
addi x31, x0, -6       # TRAP

jal x31, +12           # JAL: Jump over 2 instructions, save return PC to x31
addi x31, x0, -7       # TRAP
addi x31, x0, -8       # TRAP

auipc x5, 0            # Start testing JALR
addi x5, x5, 12        # x5 = Address of the instruction (addi x31, 1)
jalr x0, x5, 0         # Jump to x5
addi x31, x0, -9       # TRAP
addi x31, x0, -10      # TRAP

addi x31, x0, 1        # SUCCESS: If execution reaches here, x31 = 1
beq x0, x0, 0          # Infinite loop to end the program