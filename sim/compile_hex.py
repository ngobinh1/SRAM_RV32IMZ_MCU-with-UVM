#!/usr/bin/env python3
import sys
import os
import subprocess
import tempfile

def compile_asm(input_s, output_hex):
    # Create temporary files for elf and bin
    with tempfile.NamedTemporaryFile(suffix='.elf', delete=False) as tmp_elf, \
         tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as tmp_bin:
        
        tmp_elf_path = tmp_elf.name
        tmp_bin_path = tmp_bin.name

    try:
        # 1. Compile assembly to ELF
        gcc_cmd = [
            "riscv64-unknown-elf-gcc",
            "-march=rv32im",
            "-mabi=ilp32",
            "-nostdlib",
            "-Ttext", "0x0",
            "-o", tmp_elf_path,
            input_s
        ]
        print(f"Running: {' '.join(gcc_cmd)}")
        subprocess.check_call(gcc_cmd)

        # 2. Extract raw binary from ELF
        objcopy_cmd = [
            "riscv64-unknown-elf-objcopy",
            "-O", "binary",
            tmp_elf_path,
            tmp_bin_path
        ]
        print(f"Running: {' '.join(objcopy_cmd)}")
        subprocess.check_call(objcopy_cmd)

        # 3. Read bin and write hex
        with open(tmp_bin_path, "rb") as f_bin:
            binary_data = f_bin.read()

        # Ensure we have a multiple of 4 bytes
        if len(binary_data) % 4 != 0:
            # Pad with zeros
            binary_data += b'\x00' * (4 - (len(binary_data) % 4))

        hex_words = []
        for i in range(0, len(binary_data), 4):
            word_bytes = binary_data[i:i+4]
            # Convert to little-endian 32-bit integer
            word = int.from_bytes(word_bytes, byteorder='little')
            # Format as 8-digit big-endian hex string
            hex_words.append(f"{word:08x}")

        # Ensure target output directory exists
        os.makedirs(os.path.dirname(os.path.abspath(output_hex)), exist_ok=True)
        
        with open(output_hex, "w") as f_hex:
            for hw in hex_words:
                f_hex.write(hw + "\n")
        
        print(f"Successfully compiled {input_s} to {output_hex}")

    finally:
        # Clean up temporary files
        if os.path.exists(tmp_elf_path):
            os.remove(tmp_elf_path)
        if os.path.exists(tmp_bin_path):
            os.remove(tmp_bin_path)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: compile_hex.py <input.S> <output.hex>")
        sys.argv = ["sim/custom_tests/test_simple.S", "sim/hex/test_simple.hex"]
        sys.exit(1)
    
    compile_asm(sys.argv[1], sys.argv[2])
