# SoC Top Testbench

This directory contains the complete SoC top-level testbench that validates the entire RISC-V system integration.

## Overview

The `tb_soc_top` testbench validates:
- Custom RISC-V core (RV32IM)
- ROM and RAM subsystems
- Wishbone interconnect and arbiter
- UART peripheral
- PWM accelerator
- Sigma-Delta ADC
- Protection/fault peripheral
- Timer peripheral
- GPIO peripheral
- Complete firmware execution

## Quick Start

### Prerequisites

1. **Icarus Verilog** (iverilog) - for simulation
2. **RISC-V GNU Toolchain** - for firmware compilation
   - `riscv32-unknown-elf-gcc`
   - `riscv32-unknown-elf-objcopy`
   - `riscv32-unknown-elf-objdump`
3. **GTKWave** (optional) - for waveform viewing

### Running the Test

Simply run the provided script:

```bash
cd /home/furka/5level-inverter/02-embedded/riscv/sim
./run_soc_top_test.sh
```

This script will:
1. Compile the test firmware (`firmware/test_soc/test_soc.S`)
2. Generate `firmware.hex` file
3. Compile all RTL modules
4. Run the simulation
5. Report PASS/FAIL

### Expected Output

The testbench will:
- Reset the SoC
- Load firmware from ROM
- Execute the test program
- Monitor UART output for "Hello World!\n"
- Report success if the message is received correctly

Example output:
```
========================================
INFO: Starting SoC Top Testbench
========================================
INFO: CLK_100MHZ_PERIOD = 10 ns
INFO: UART_BAUD = 115200
INFO: UART_BIT_PERIOD = 8680 ns
INFO: Reset released at time 200
========================================
INFO: Waiting for UART transmission...
========================================
INFO: UART Start bit detected at time 12345
INFO: [00] Received 0x48 'H' - OK
INFO: [01] Received 0x65 'e' - OK
INFO: [02] Received 0x6c 'l' - OK
INFO: [03] Received 0x6c 'l' - OK
INFO: [04] Received 0x6f 'o' - OK
INFO: [05] Received 0x20 ' ' - OK
INFO: [06] Received 0x57 'W' - OK
INFO: [07] Received 0x6f 'o' - OK
INFO: [08] Received 0x72 'r' - OK
INFO: [09] Received 0x6c 'l' - OK
INFO: [10] Received 0x64 'd' - OK
INFO: [11] Received 0x21 '!' - OK
INFO: [12] Received 0x0a - OK
========================================
PASS: Successfully received 'Hello World!' via UART
========================================
```

## Testbench Features

### 1. UART Verification

The testbench includes a complete UART receiver that:
- Detects start bits correctly
- Samples data bits in the middle of each bit period
- Verifies stop bits
- Checks received data against expected message
- Reports detailed character-by-character results

### 2. Waveform Dumping

The testbench automatically generates `tb_soc_top.vcd` for debugging:

```bash
gtkwave tb_soc_top.vcd
```

Key signals to observe:
- `dut.clk` - System clock (50 MHz)
- `dut.rst_n_sync` - Synchronized reset
- `dut.uart_tx` - UART transmission
- `dut.cpu.ibus_addr` - Instruction bus address
- `dut.cpu.dbus_addr` - Data bus address
- `dut.led` - Status LEDs
- `dut.pwm_out` - PWM outputs

### 3. Signal Monitoring

The testbench monitors:
- **UART TX**: Complete protocol verification
- **PWM outputs**: Change detection and logging
- **LEDs**: Status indicator changes
- **Timeout**: 10ms watchdog timer

### 4. Detailed Diagnostics

For debugging failures:
- Character-by-character UART verification
- Timing information for all events
- Framing error detection
- Stop bit verification

## Test Firmware

The test firmware (`firmware/test_soc/test_soc.S`) is a simple program that:
1. Loads the address of "Hello World!\n" string
2. Loops through each character
3. Writes each character to the UART TX register (0x00020500)
4. Enters infinite loop when done

### Memory Map

- **ROM**: 0x00000000 - 0x00007FFF (32 KB)
- **RAM**: 0x00010000 - 0x0001FFFF (64 KB)
- **PWM**: 0x00020000 - 0x000200FF
- **ADC**: 0x00020100 - 0x000201FF
- **Protection**: 0x00020200 - 0x000202FF
- **Timer**: 0x00020300 - 0x000203FF
- **GPIO**: 0x00020400 - 0x000204FF
- **UART**: 0x00020500 - 0x000205FF

## Troubleshooting

### Compilation Errors

**Problem**: `RISC-V toolchain not found`

**Solution**: Install the RISC-V GNU toolchain or set `RISCV_PREFIX`:
```bash
export RISCV_PREFIX=/path/to/riscv/bin/riscv32-unknown-elf
```

**Problem**: `RTL file not found`

**Solution**: Ensure all RTL modules are present in `rtl/` directory structure.

### Simulation Failures

**Problem**: `Test timed out`

**Solution**:
- Check if firmware.hex is properly generated
- Verify ROM is loading firmware correctly
- Check CPU reset and clock signals in waveform

**Problem**: `UART framing error`

**Solution**:
- Verify UART baud rate matches testbench (115200)
- Check UART peripheral clock divider configuration
- Inspect UART TX signal timing in waveform

**Problem**: `UART data mismatch`

**Solution**:
- Verify firmware is writing to correct UART address (0x00020500)
- Check Wishbone interconnect routing
- Inspect firmware disassembly in `build/test_soc.dis`

## Manual Simulation

For manual control:

```bash
# Compile firmware manually
cd firmware/test_soc
riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
    -Wl,-Ttext=0x00000000 -o test_soc.elf test_soc.S
riscv32-unknown-elf-objcopy -O verilog test_soc.elf ../../sim/firmware/firmware.hex

# Compile RTL manually
cd ../../sim
iverilog -g2012 -Wall -DSIMULATION -o build/tb_soc_top.vvp \
    ../rtl/core/*.v \
    ../rtl/wishbone/*.v \
    ../rtl/peripherals/*.v \
    ../rtl/soc/soc_top.v \
    testbench/tb_soc_top.v

# Run simulation
vvp build/tb_soc_top.vvp

# View waveforms
gtkwave tb_soc_top.vcd
```

## Future Enhancements

Planned improvements to the testbench:
- [ ] Test all peripherals (PWM, ADC, Timer, GPIO)
- [ ] Test interrupt handling
- [ ] Test exception handling
- [ ] Test RAM read/write operations
- [ ] Test Wishbone bus arbitration
- [ ] Add performance counters
- [ ] Add code coverage analysis
- [ ] Test fault injection scenarios

## Related Files

- `testbench/tb_soc_top.v` - Main testbench file
- `firmware/test_soc/test_soc.S` - Test firmware
- `run_soc_top_test.sh` - Automated build and test script
- `../rtl/soc/soc_top.v` - SoC top-level module

## References

- [Wishbone B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf)
- [RISC-V Instruction Set Manual](https://riscv.org/technical/specifications/)
- [Icarus Verilog Documentation](http://iverilog.icarus.com/)
