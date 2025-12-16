#!/usr/bin/env python3
"""
add_bootloader_header.py - Add bootloader header to firmware binary

Usage:
    python3 add_bootloader_header.py input.bin output.bin --version 1.0.0
"""

import struct
import sys
import argparse
from pathlib import Path

# Bootloader constants
BOOT_MAGIC = 0xB007ABCD

def crc32(data):
    """Calculate CRC32 (same algorithm as bootloader)"""
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return (~crc) & 0xFFFFFFFF

def add_bootloader_header(input_file, output_file, version_str="1.0.0"):
    """Add bootloader header to firmware binary"""
    
    # Parse version string
    try:
        version_parts = [int(x) for x in version_str.split('.')]
        if len(version_parts) != 3:
            raise ValueError("Version must be in format X.Y.Z")
        version_u32 = (version_parts[0] << 16) | (version_parts[1] << 8) | version_parts[2]
    except:
        print(f"ERROR: Invalid version format '{version_str}'. Use X.Y.Z format.")
        return False
    
    # Read input binary
    try:
        with open(input_file, 'rb') as f:
            firmware_data = f.read()
    except FileNotFoundError:
        print(f"ERROR: Input file '{input_file}' not found.")
        return False
    
    print(f"Input file: {input_file}")
    print(f"Firmware size: {len(firmware_data)} bytes")
    
    # Calculate CRC32
    crc = crc32(firmware_data)
    print(f"CRC32: 0x{crc:08X}")
    
    # Create header (20 bytes total)
    header = struct.pack('<IIIII', 
                        BOOT_MAGIC,      # Magic number
                        version_u32,     # Version
                        len(firmware_data),  # Size
                        crc,             # CRC32
                        0)               # Reserved
    
    # Write output file
    try:
        with open(output_file, 'wb') as f:
            f.write(header)
            f.write(firmware_data)
        print(f"Output file: {output_file}")
        print(f"Total size: {len(header) + len(firmware_data)} bytes")
        print("Header added successfully!")
        return True
    except Exception as e:
        print(f"ERROR: Failed to write output file: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Add bootloader header to firmware binary')
    parser.add_argument('input', help='Input binary file')
    parser.add_argument('output', help='Output binary file with header')
    parser.add_argument('--version', default='1.0.0', help='Firmware version (X.Y.Z format)')
    
    args = parser.parse_args()
    
    if not add_bootloader_header(args.input, args.output, args.version):
        sys.exit(1)

if __name__ == '__main__':
    main()