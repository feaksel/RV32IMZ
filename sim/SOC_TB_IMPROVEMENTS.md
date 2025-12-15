# SoC Top Testbench Improvements

## Summary

The SoC top testbench (`tb_soc_top.v`) has been significantly improved with better UART verification, comprehensive monitoring, and automated build/test infrastructure.

## What Was Improved

### 1. Testbench Enhancements ([tb_soc_top.v](testbench/tb_soc_top.v))

#### Removed SystemVerilog Dependencies
- **Before**: Used SystemVerilog `string` type (incompatible with iverilog)
- **After**: Uses standard Verilog arrays `reg [7:0] expected_msg [0:12]`
- **Benefit**: Better compatibility with open-source simulators

#### Fixed UART Bit Sampling
- **Before**: Sampled bits at incorrect timing, potentially missing data
- **After**: Properly samples in the middle of each bit period
  ```verilog
  #(UART_BIT_PERIOD / 2);  // Move to center of start bit
  for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
      #(UART_BIT_PERIOD);   // Move to next bit center
      byte_received[bit_count] = uart_tx;
  end
  ```
- **Benefit**: Accurate UART reception with proper timing margins

#### Added Waveform Dumping
```verilog
initial begin
    $dumpfile("tb_soc_top.vcd");
    $dumpvars(0, tb_soc_top);
end
```
- **Benefit**: Enables debugging with GTKWave

#### Enhanced Diagnostics
- Character-by-character verification with detailed logging
- Printable character display (e.g., `0x48 'H'`)
- Non-printable character handling (e.g., `0x0A`)
- Clear PASS/FAIL reporting with timestamps
- Framing error detection (start bit and stop bit verification)

#### Added Signal Monitoring
- **PWM Monitoring**: Detects and logs PWM output changes
- **LED Monitoring**: Tracks LED state transitions
- **Timeout Watchdog**: 10ms timeout with clear error message

### 2. Firmware Bug Fix ([firmware/test_soc/test_soc.S](../firmware/test_soc/test_soc.S))

#### Fixed UART Write Bug
- **Before**:
  ```asm
  sb t0, 0(s1)  # Bug: writes to string address!
  ```
- **After**:
  ```asm
  li t1, UART_TX_DATA  # Load UART TX address (0x00020500)
  sw t0, 0(t1)         # Write character to UART
  ```
- **Impact**: Firmware will now actually transmit via UART

### 3. Build Automation

#### Shell Script ([run_soc_top_test.sh](run_soc_top_test.sh))
Complete automated build and test script with:
- ✅ Firmware compilation (RISC-V assembly → ELF → HEX)
- ✅ Automatic disassembly generation
- ✅ RTL compilation (all modules)
- ✅ Simulation execution
- ✅ PASS/FAIL reporting with color output
- ✅ Error handling and validation
- ✅ Helpful diagnostics

**Usage**:
```bash
./run_soc_top_test.sh
```

#### Makefile ([Makefile.soc_top](Makefile.soc_top))
Comprehensive Makefile with targets:
- `make -f Makefile.soc_top all` - Build and run (default)
- `make -f Makefile.soc_top build` - Build only
- `make -f Makefile.soc_top sim` - Simulate only
- `make -f Makefile.soc_top wave` - View waveforms
- `make -f Makefile.soc_top clean` - Clean build artifacts
- `make -f Makefile.soc_top help` - Show help

### 4. Documentation ([README_SOC_TOP.md](README_SOC_TOP.md))

Comprehensive documentation including:
- 📋 Overview and feature list
- 🚀 Quick start guide
- 🔧 Troubleshooting section
- 📊 Expected output examples
- 🗺️ Memory map reference
- 🛠️ Manual simulation instructions
- 📝 Future enhancement roadmap

## File Changes Summary

| File | Status | Description |
|------|--------|-------------|
| `testbench/tb_soc_top.v` | ✅ Modified | Enhanced testbench with better UART RX and monitoring |
| `../firmware/test_soc/test_soc.S` | ✅ Fixed | Corrected UART write bug |
| `run_soc_top_test.sh` | ✅ New | Automated build and test script |
| `Makefile.soc_top` | ✅ New | Makefile for build automation |
| `README_SOC_TOP.md` | ✅ New | Comprehensive documentation |
| `SOC_TB_IMPROVEMENTS.md` | ✅ New | This summary document |

## Key Improvements at a Glance

| Aspect | Before | After |
|--------|--------|-------|
| UART Sampling | Incorrect timing | Proper mid-bit sampling |
| Compatibility | SystemVerilog only | Standard Verilog |
| Debugging | No waveforms | VCD dump enabled |
| Diagnostics | Basic errors | Detailed char-by-char logging |
| Build Process | Manual | Fully automated |
| Documentation | Minimal comments | Complete README |
| Firmware | Buggy (no TX) | Fixed and working |
| Monitoring | UART only | UART + PWM + LED + timeout |

## Testing the Improvements

### Quick Test
```bash
cd /home/furka/5level-inverter/02-embedded/riscv/sim
./run_soc_top_test.sh
```

### Expected Console Output
```
========================================
SoC Top Testbench Build and Run
========================================
Step 1: Compiling test_soc firmware...
Firmware compiled successfully!
  ELF: .../build/test_soc.elf
  HEX: .../firmware/firmware.hex
  DIS: .../build/test_soc.dis

Step 2: Compiling RTL modules...
RTL compilation successful!

Step 3: Running simulation...
========================================
========================================
INFO: Starting SoC Top Testbench
========================================
INFO: CLK_100MHZ_PERIOD = 10 ns
INFO: UART_BAUD = 115200
INFO: UART_BIT_PERIOD = 8680 ns
INFO: Reset released at time 200
...
INFO: [00] Received 0x48 'H' - OK
INFO: [01] Received 0x65 'e' - OK
...
INFO: [12] Received 0x0a - OK
========================================
PASS: Successfully received 'Hello World!' via UART
========================================
========================================
✓ TESTBENCH PASSED!
========================================
Waveforms saved to: tb_soc_top.vcd
View with: gtkwave tb_soc_top.vcd
```

## Debugging Tips

### View Waveforms
```bash
gtkwave tb_soc_top.vcd
```

**Key signals to inspect**:
- `dut.clk` - System clock
- `dut.uart_tx` - UART transmission
- `dut.cpu.ibus_addr` - Instruction address
- `dut.cpu.dbus_addr` - Data address
- `dut.rom_stb` - ROM access strobe
- `dut.led[3:0]` - Status LEDs

### View Disassembly
```bash
cat build/test_soc.dis
```

This shows the assembled firmware instructions.

### Check Simulation Log
```bash
cat build/simulation.log
```

## Future Work

Potential enhancements:
- [ ] Test other peripherals (PWM, ADC, Timer)
- [ ] Add interrupt testing
- [ ] Test exception handling
- [ ] Verify RAM read/write
- [ ] Test bus arbitration
- [ ] Add performance metrics
- [ ] Create more complex test programs

## Integration with Project

This testbench integrates with the 5-level inverter project as part of:
- **Stage 4**: RISC-V Implementation (Custom soft-core processor)

The SoC provides a complete embedded control system that can:
1. Execute real-time control algorithms
2. Interface with PWM hardware accelerators
3. Sample ADC data via Sigma-Delta converters
4. Handle protection faults and emergency stops
5. Communicate via UART for debugging

---

**Date**: 2025-12-13
**Author**: Claude Code
**Version**: 1.0
