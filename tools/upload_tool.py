#!/usr/bin/env python3
"""
upload_tool.py - Firmware upload tool for RISC-V bootloader

Upload firmware to embedded device via UART bootloader protocol.

Usage:
    python3 upload_tool.py <port> <firmware.bin> [version]

Examples:
    python3 upload_tool.py /dev/ttyUSB0 app.bin
    python3 upload_tool.py /dev/ttyUSB0 app.bin 1.2.3
    python3 upload_tool.py COM3 firmware_with_header.bin
"""

import serial
import struct
import time
import sys
from pathlib import Path

# Protocol constants
BOOT_MAGIC = 0xB007ABCD
BAUDRATE = 115200
TIMEOUT = 30  # seconds

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

def wait_for_bootloader(ser, timeout=10):
    """Wait for bootloader to be ready"""
    print("Waiting for bootloader...")
    start_time = time.time()
    
    while (time.time() - start_time) < timeout:
        # Send update command
        ser.write(b'U')
        time.sleep(0.1)
        
        # Check for bootloader response
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            if b'Update mode' in response or b'Waiting for' in response:
                print("Bootloader ready!")
                return True
                
        time.sleep(0.5)
    
    return False

def upload_firmware(port, filename, version=(1, 0, 0)):
    """Upload firmware to device via UART"""
    
    # Validate inputs
    if not Path(filename).exists():
        print(f"ERROR: File '{filename}' not found")
        return False
    
    # Read firmware file
    print(f"Reading {filename}...")
    try:
        with open(filename, 'rb') as f:
            firmware_data = f.read()
    except Exception as e:
        print(f"ERROR: Failed to read file: {e}")
        return False
    
    if len(firmware_data) == 0:
        print("ERROR: File is empty")
        return False
    
    print(f"Firmware size: {len(firmware_data)} bytes")
    
    # Check if file already has header
    has_header = False
    if len(firmware_data) >= 20:
        header_magic = struct.unpack('<I', firmware_data[:4])[0]
        if header_magic == BOOT_MAGIC:
            print("Firmware already has bootloader header")
            has_header = True
    
    # If no header, add one
    if not has_header:
        print("Adding bootloader header...")
        # Calculate CRC of firmware data
        crc = crc32(firmware_data)
        print(f"CRC32: 0x{crc:08X}")
        
        # Build header
        version_u32 = (version[0] << 16) | (version[1] << 8) | version[2]
        header = struct.pack('<IIIII', 
                           BOOT_MAGIC, 
                           version_u32, 
                           len(firmware_data), 
                           crc,
                           0)  # Reserved
        
        # Prepend header to firmware
        firmware_data = header + firmware_data
        print(f"Total size with header: {len(firmware_data)} bytes")
    
    # Open serial port
    print(f"Opening {port} @ {BAUDRATE} baud...")
    try:
        ser = serial.Serial(port, BAUDRATE, timeout=1, 
                          bytesize=8, parity='N', stopbits=1,
                          xonxoff=False, rtscts=False, dsrdtr=False)
        time.sleep(0.1)
    except Exception as e:
        print(f"ERROR: Failed to open serial port: {e}")
        return False
    
    try:
        # Wait for bootloader
        if not wait_for_bootloader(ser, TIMEOUT):
            print("ERROR: Bootloader not responding")
            ser.close()
            return False
        
        # Clear any remaining data
        time.sleep(0.5)
        if ser.in_waiting > 0:
            ser.read(ser.in_waiting)
        
        # Send firmware data
        print("Uploading firmware...")
        chunk_size = 128
        sent = 0
        start_time = time.time()
        
        while sent < len(firmware_data):
            chunk = firmware_data[sent:sent + chunk_size]
            
            # Send chunk
            bytes_written = ser.write(chunk)
            if bytes_written != len(chunk):
                print(f"\nERROR: Write failed at byte {sent}")
                return False
            
            sent += len(chunk)
            
            # Progress indicator
            percent = (sent * 100) // len(firmware_data)
            elapsed = time.time() - start_time
            if elapsed > 0:
                speed = sent / elapsed
                eta = (len(firmware_data) - sent) / speed if speed > 0 else 0
                print(f"\r  Progress: {percent:3d}% ({sent}/{len(firmware_data)} bytes) "
                      f"Speed: {speed/1024:.1f} KB/s ETA: {eta:.1f}s", end='', flush=True)
            
            # Small delay between chunks
            time.sleep(0.01)
        
        print("\nUpload completed, waiting for verification...")
        
        # Wait for bootloader messages
        verification_timeout = 10
        start_time = time.time()
        success = False
        
        while (time.time() - start_time) < verification_timeout:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"  {line}")
                    
                    # Check for success/failure keywords
                    if any(word in line.lower() for word in ['successful', 'verified ok', 'update successful']):
                        success = True
                    elif any(word in line.lower() for word in ['error', 'failed', 'mismatch']):
                        print("ERROR: Upload failed!")
                        return False
            else:
                time.sleep(0.1)
        
        if success:
            print("Upload completed successfully!")
            
            # Wait a bit longer for any final messages
            time.sleep(2)
            while ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"  {line}")
            
            return True
        else:
            print("WARNING: Upload status unclear (no confirmation received)")
            return False
            
    except KeyboardInterrupt:
        print("\nUpload cancelled by user")
        return False
    except Exception as e:
        print(f"\nERROR: Upload failed: {e}")
        return False
    finally:
        ser.close()

def main():
    if len(sys.argv) < 3:
        print("RISC-V Bootloader Upload Tool")
        print("Usage: upload_tool.py <port> <firmware.bin> [version]")
        print()
        print("Examples:")
        print("  upload_tool.py /dev/ttyUSB0 app.bin")
        print("  upload_tool.py /dev/ttyUSB0 app.bin 1.2.3")
        print("  upload_tool.py COM3 firmware.bin")
        print()
        print("Supported formats:")
        print("  - Raw binary files")
        print("  - Binary files with bootloader header")
        print("  - Automatic header generation if needed")
        sys.exit(1)
    
    port = sys.argv[1]
    filename = sys.argv[2]
    
    # Parse version if provided
    version = (1, 0, 0)
    if len(sys.argv) > 3:
        try:
            version = tuple(map(int, sys.argv[3].split('.')))
            if len(version) != 3:
                raise ValueError()
        except:
            print(f"ERROR: Invalid version format '{sys.argv[3]}'. Use X.Y.Z format.")
            sys.exit(1)
    
    # Perform upload
    if upload_firmware(port, filename, version):
        print("\n✅ Upload successful!")
        sys.exit(0)
    else:
        print("\n❌ Upload failed!")
        sys.exit(1)

if __name__ == '__main__':
    main()