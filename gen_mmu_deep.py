import os
import subprocess

asm_code = """
.section .text.init
.globl _start

# We place the entry point at 0x0.
# This instruction is BOTH executed on reset AND used as a PTE by the MMU!
# As a PTE, 0x0010006F means: PPN = 0x400, Flags = 0x6F (V=1, R=1, W=1, X=1, A=1, G=1, U=0, D=0).
# This creates a Megapage mapping VA 0x00000000 to PA 0x400000 (which wraps to SRAM 0x00000000).
_start:
    .word 0x0010006F    # j 0x800

    .org 0x800
main:
    # 1. Setup delegation and trap vector
    la t0, trap_handler
    csrw stvec, t0
    
    # 2. Setup Page Table Base Register (satp) for Sv32
    li t0, 0x80000000
    csrw satp, t0
    sfence.vma

    # --- S-Mode & MMU Deep Test Begins ---
    
    # Test 1: Simple read/write through MMU
    li t1, 0x00000A00
    li t2, 0xCAFEBABE
    sw t2, 0(t1)
    lw t3, 0(t1)
    
    # Check if correct
    li t4, 0xCAFEBABE
    bne t3, t4, fail_loop

    # Test 2: Arithmetic loop (hit D-Cache and I-Cache multiple times)
    li t1, 0x00000A04
    li t2, 0
    li t3, 10
loop_start:
    sw t2, 0(t1)       # Store to 0xA04
    addi t2, t2, 1
    blt t2, t3, loop_start
    
    # Check loop result
    lw t4, 0(t1)       # Should be 9
    li t5, 9
    bne t4, t5, fail_loop

    # Test 3: Cause an intentional Page Fault!
    # Our PTE at 0x0 allows Supervisor Read/Write/Execute (U=0).
    # If we switch to User Mode, reading/writing should cause a Page Fault!
    
    # Setup mstatus/sstatus to switch to User Mode on sret
    # S-Mode sstatus: SPP=0 (User), SPIE=1
    li t0, 0x00000020
    csrs sstatus, t0
    
    # Set sepc to user_mode_start
    la t0, user_mode_start
    csrw sepc, t0
    
    # SRET to User Mode
    sret

user_mode_start:
    # We are now in User Mode.
    # We will attempt to read from 0x00000A00.
    # The PTE does not have the U bit set (U=0).
    # This should trigger a Load Page Fault (Exception Cause 13 in standard, 5 in our custom handler)
    li t1, 0x00000A00
    lw t2, 0(t1)
    
    # If we get here, the page fault didn't happen! FAIL.
    j fail_loop

    .align 4
trap_handler:
    # Trap handler entry
    csrr t5, scause
    csrr t6, sepc
    
    # We expect a Load Page Fault. Our custom CPU uses cause 5 for mmu_load_fault.
    li t0, 5
    bne t5, t0, fail_loop
    
    # The fault was expected! We passed!
success_loop:
    j success_loop

fail_loop:
    j fail_loop
"""

with open("mmu_deep_test.S", "w") as f:
    f.write(asm_code)

# Compile
print("Compiling assembly...")
os.system("riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -nostdlib -Ttext=0x0 mmu_deep_test.S -o mmu_deep_test.elf")
os.system("riscv64-unknown-elf-objcopy -O binary mmu_deep_test.elf mmu_deep_test.bin")

# Convert to hex
print("Converting to hex...")
with open("mmu_deep_test.bin", "rb") as f:
    bin_data = f.read()

hex_data = []
for i in range(0, len(bin_data), 4):
    word = bin_data[i:i+4]
    word = word.ljust(4, b'\x00')
    hex_word = f"{word[3]:02x}{word[2]:02x}{word[1]:02x}{word[0]:02x}"
    hex_data.append(hex_word)

with open("sim/hex/mmu_deep_test.hex", "w") as f:
    for word in hex_data:
        f.write(word + "\n")
    # Pad to 1024 words
    for _ in range(len(hex_data), 1024):
        f.write("00000000\n")

print("Done. Hex file written to sim/hex/mmu_deep_test.hex")
