#!/usr/bin/env python3
"""
Convert binary firmware to 32-bit word hex format for Verilog $readmemh
"""
import sys

if len(sys.argv) != 3:
    print("Usage: bin2hex.py input.bin output.hex")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, "rb") as f:
    data = f.read()

# Pad to word boundary
while len(data) % 4 != 0:
    data += b'\x00'

# Convert to 32-bit words (little-endian) and write to hex file
with open(output_file, "w") as f:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], 'little')
        f.write(f"{word:08x}\n")

print(f"Converted {len(data)} bytes to {len(data)//4} words")
