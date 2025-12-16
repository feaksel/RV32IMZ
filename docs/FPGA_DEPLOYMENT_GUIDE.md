# FPGA Deployment Guide for RV32IMZ 5-Level CHB Inverter SoC

## Complete Workflow: Post-Synthesis Testing and Program Loading for Basys3 FPGA

### Overview

This guide provides a complete workflow for deploying your RV32IMZ SoC to a Basys3 FPGA board, including:

1. Post-synthesis verification
2. FPGA synthesis and implementation
3. Bootloader setup and program loading
4. Testing your 5-level CHB inverter control application

---

## 1. Post-Synthesis Verification

### Step 1.1: Gate-Level Simulation

After running synthesis, perform gate-level simulation to verify the synthesized netlist:

```bash
# Run complete SoC synthesis
./synthesize_soc.sh

# Extract gate-level netlist for simulation
cd synthesis/soc_results
```

### Step 1.2: Timing Analysis

Verify that your design meets timing requirements:

```bash
# Check synthesis reports
cat synthesis/soc_results/timing_report.txt
cat synthesis/soc_results/utilization_report.txt
```

Expected timing for Basys3 (100MHz → 50MHz internal):

- **Target Frequency**: 50 MHz (20ns period)
- **Setup Slack**: Should be positive
- **Hold Slack**: Should be positive
- **Critical Path**: Typically through ALU or memory interface

---

## 2. FPGA Implementation for Basys3

### Step 2.1: Vivado Project Setup

Create a Vivado project for Basys3:

```tcl
# Create Vivado project (run in Vivado TCL console)
create_project rv32imz_soc ./vivado_project -part xc7a35tcpg236-1

# Add source files
add_files [glob rtl/soc/*.v]
add_files [glob rtl/core/*.v]
add_files [glob rtl/memory/*.v]
add_files [glob rtl/peripherals/*.v]

# Add constraints
add_files -fileset constrs_1 constraints/basys3.xdc
add_files -fileset constrs_1 constraints/rv32imz_timing.xdc

# Set top module
set_property top soc_simple [current_fileset]

# Add firmware
add_files firmware/firmware.hex
set_property file_type {Memory Initialization Files} [get_files firmware/firmware.hex]
```

### Step 2.2: Implementation Flow

Run the complete implementation flow:

```tcl
# Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

### Step 2.3: Resource Utilization

Expected resource usage on Basys3 (XC7A35T):

| Resource | Used  | Available | Utilization |
| -------- | ----- | --------- | ----------- |
| LUTs     | ~8000 | 20,800    | ~38%        |
| FFs      | ~4000 | 41,600    | ~10%        |
| BRAM     | 32    | 50        | 64%         |
| DSPs     | 8     | 90        | 9%          |

---

## 3. Bootloader Implementation

### Step 3.1: Bootloader Features

Your SoC includes a comprehensive UART bootloader with these features:

- **Memory Layout**:

  - `0x00000000 - 0x00003FFF`: Bootloader (16KB)
  - `0x00004000 - 0x0000FFFF`: Application Space (48KB)
  - `0x00010000 - 0x0001FFFF`: RAM (64KB)

- **Update Protocol**:
  - UART-based firmware upload
  - CRC32 verification
  - Automatic application verification
  - Safe rollback on corruption

### Step 3.2: Bootloader Operation

The bootloader follows this sequence:

1. **Power-on**: Display banner and version
2. **Update Check**: 3-second window to press 'U' for update mode
3. **Application Verification**: Check CRC32 and magic number
4. **Jump to Application**: Transfer control to your CHB controller

**Sample Bootloader Output**:

```
================================
  RISC-V Bootloader v1.0
  5-Level Inverter Controller
================================

Press 'U' for update mode (3s timeout)...
...
Application verified OK
Jumping to application...
```

---

## 4. Programming the FPGA

### Step 4.1: Initial FPGA Programming

Program the bitstream with embedded bootloader:

```bash
# Method 1: Vivado Hardware Manager
# Open Hardware Manager → Connect to target → Program device

# Method 2: Command line (if Vivado installed)
vivado -mode batch -source program_fpga.tcl

# Method 3: OpenOCD (alternative)
openocd -f interface/digilent-hs2.cfg -f board/digilent_basys3.cfg \
        -c "program_fpga soc_with_bootloader.bit" -c shutdown
```

### Step 4.2: UART Connection Setup

Connect USB-UART adapter to Basys3 Pmod headers:

| Pmod Pin | UART Signal | USB-UART Wire |
| -------- | ----------- | ------------- |
| JC1      | uart_tx     | RX            |
| JC2      | uart_rx     | TX            |
| JC3      | GND         | GND           |

**UART Settings**: 115200 baud, 8N1, no flow control

---

## 5. Loading Your CHB Control Application

### Step 5.1: Compile Your Application

Compile your 5-level CHB control program:

```bash
cd firmware/examples

# Compile CHB control application
riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 \
    -T ../application.ld \
    -O2 -Wall \
    -o chb_5level_control.elf \
    chb_5level_control.c ../startup.S

# Generate binary with bootloader header
riscv32-unknown-elf-objcopy -O binary chb_5level_control.elf chb_5level_control.bin

# Add bootloader header
python3 ../../tools/add_bootloader_header.py \
    chb_5level_control.bin \
    chb_5level_control_with_header.bin \
    --version 1.0.0
```

### Step 5.2: Upload via Bootloader

Use the UART bootloader to upload your application:

```bash
# Reset the FPGA (press reset button)
# Connect terminal to monitor bootloader messages
screen /dev/ttyUSB0 115200

# In another terminal, upload firmware
python3 ../../tools/upload_tool.py /dev/ttyUSB0 chb_5level_control_with_header.bin
```

**Expected Upload Sequence**:

```
# Terminal 1 (monitoring):
================================
  RISC-V Bootloader v1.0
  5-Level Inverter Controller
================================
Press 'U' for update mode (3s timeout)...

# Terminal 2 (upload):
$ python3 upload_tool.py /dev/ttyUSB0 chb_5level_control_with_header.bin
Reading chb_5level_control_with_header.bin...
Firmware size: 8456 bytes
CRC32: 0x12345678
Opening /dev/ttyUSB0 @ 115200 baud...
Waiting for bootloader...
Sending header...
Sending firmware data...
  Progress: 100% (8456/8456 bytes)
Verification...
Upload complete!

# Terminal 1 (result):
>>> Update mode <<<
Waiting for firmware image...
Firmware version: 1.0.0
Size: 8456 bytes
Programming............ done
CRC verified OK
Update successful!
Rebooting in 2 seconds...

================================
  RISC-V Bootloader v1.0
  5-Level Inverter Controller
================================
Application verified OK
Jumping to application...

CHB 5-Level Inverter Controller v1.0.0
======================================
Initializing system...
PWM Accelerator: OK
ADC Interface: OK
Protection System: OK
Starting 10 kHz control loop...
```

---

## 6. Testing Your Application

### Step 6.1: PWM Output Verification

Connect oscilloscope to PWM outputs on Pmod headers:

| PWM Signal | Pmod Pin | H-Bridge Connection |
| ---------- | -------- | ------------------- |
| pwm_out[0] | JA1      | S1 (H1 High-side)   |
| pwm_out[1] | JA2      | S1' (H1 Low-side)   |
| pwm_out[2] | JA3      | S3 (H1 High-side)   |
| pwm_out[3] | JA4      | S3' (H1 Low-side)   |
| pwm_out[4] | JB1      | S5 (H2 High-side)   |
| pwm_out[5] | JB2      | S5' (H2 Low-side)   |
| pwm_out[6] | JB3      | S7 (H2 High-side)   |
| pwm_out[7] | JB4      | S7' (H2 Low-side)   |

**Expected PWM Characteristics**:

- **Frequency**: 5 kHz (200 μs period)
- **Dead Time**: 2 μs between complementary signals
- **5-Level Pattern**: Variable duty cycle for each H-bridge

### Step 6.2: UART Debug Interface

Monitor system status via UART:

```bash
screen /dev/ttyUSB0 115200
```

**Expected Debug Output**:

```
CHB 5-Level Inverter Controller v1.0.0
======================================

System Status:
- PWM Frequency: 5000 Hz
- Control Loop: 10000 Hz
- Output Voltage: 120.5 V RMS
- Output Current: 8.2 A RMS
- DC Bus: 311.0 V
- Temperature: 45.2°C

Protection Status: OK
- Overcurrent: OK (Limit: 15.0A)
- Overvoltage: OK (Limit: 350V)
- Temperature: OK (Limit: 85°C)

Control Loop Performance:
- PI Controller: Active
- Resonant Controller: Active
- THD: 2.3%
- Tracking Error: 0.8V RMS
```

### Step 6.3: Performance Verification

Verify timing requirements are met:

1. **Control Loop**: 10 kHz (100 μs period)
2. **PWM Update**: 5 kHz (200 μs period)
3. **Output Frequency**: 50 Hz (20 ms period)
4. **CPU Utilization**: <80% for stable operation

---

## 7. Advanced Features

### Step 7.1: Real-time Debugging

Access CPU registers and memory via UART debug interface:

```bash
# In UART terminal, type debug commands:
> reg         # Show CPU registers
> mem 0x20000 # Show memory at address
> pwm         # Show PWM accelerator status
> adc         # Show ADC readings
> temp        # Show temperature sensor
```

### Step 7.2: Parameter Tuning

Modify control parameters in real-time:

```bash
> set kp 0.5      # Set proportional gain
> set ki 0.1      # Set integral gain
> set kr 2.0      # Set resonant gain
> set freq 60     # Set output frequency to 60Hz
> save            # Save parameters to flash
```

---

## 8. Troubleshooting

### Common Issues:

1. **FPGA doesn't program**: Check Vivado license, USB drivers, board connections
2. **Bootloader doesn't respond**: Verify UART wiring, baud rate, power supply
3. **Application upload fails**: Check CRC, timeout settings, serial port permissions
4. **PWM not working**: Verify constraints file, check for timing violations
5. **Control loop unstable**: Reduce gains, check ADC calibration, verify timing

### Debug Steps:

1. **Check Vivado Implementation**: Look for timing violations, routing issues
2. **Verify UART**: Test with simple echo program first
3. **Monitor Power**: Ensure stable 3.3V supply to FPGA
4. **Check Clocks**: Verify 100MHz input clock, 50MHz internal clock
5. **Temperature**: Ensure FPGA doesn't overheat during operation

---

## Summary

You now have a complete workflow for:
✅ **Post-synthesis verification** of your RV32IMZ SoC  
✅ **FPGA implementation** on Basys3 board  
✅ **Bootloader-based program loading** via UART  
✅ **Testing and debugging** your 5-level CHB inverter controller

Your SoC is perfectly suited for this application with its 98% RISC-V compliance, dedicated PWM accelerator, and comprehensive peripheral set. The 50MHz operation provides ample performance for 10kHz control loops with <80% CPU utilization.
