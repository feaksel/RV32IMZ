#!/usr/bin/env python3
"""
add_padding.py - Add padding to binary file for ROM initialization

Pads binary file to specified size and converts to hex format
"""

import sys
import argparse

def add_padding_and_hex(input_file, output_file, target_size):
    """Add padding to binary and convert to hex format"""
    
    with open(input_file, 'rb') as f:
        data = f.read()
    
    print(f"Input size: {len(data)} bytes")
    
    if len(data) > target_size:
        print(f"ERROR: Input file ({len(data)} bytes) is larger than target size ({target_size} bytes)")
        return False
    
    # Pad with zeros
    padding_needed = target_size - len(data)
    data += b'\x00' * padding_needed
    
    print(f"Padded to: {len(data)} bytes")
    
    # Convert to hex words (32-bit little endian)
    hex_lines = []
    for i in range(0, len(data), 4):
        if i + 3 < len(data):
            word = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
            hex_lines.append(f"{word:08x}")
        else:
            # Handle incomplete word at end
            word = 0
            for j in range(4):
                if i + j < len(data):
                    word |= data[i + j] << (j * 8)
            hex_lines.append(f"{word:08x}")
    
    with open(output_file, 'w') as f:
        f.write('\n'.join(hex_lines))
    
    print(f"Generated {output_file} with {len(hex_lines)} words")
    return True

def main():
    if len(sys.argv) != 4:
        print("Usage: add_padding.py <input.bin> <output.hex> <target_size>")
        print("Example: add_padding.py app.bin app.hex 16384")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    target_size = int(sys.argv[3])
    
    if not add_padding_and_hex(input_file, output_file, target_size):
        sys.exit(1)

if __name__ == '__main__':
    main()