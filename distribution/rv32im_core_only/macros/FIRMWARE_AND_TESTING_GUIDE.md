# 🔧 FIRMWARE LOADING AND POST-SYNTHESIS/P&R TESTING GUIDE

**Complete workflow from C code to post-P&R verification**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Firmware Compilation](#firmware-compilation)
3. [Loading Firmware Into Macros](#loading-firmware-into-macros)
4. [Post-Synthesis Testing](#post-synthesis-testing)
5. [Post-P&R Testing](#post-pr-testing)
6. [Full SoC Testing](#full-soc-testing)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### The Complete Flow

```
C Code → Compile → Binary → Convert → Memory Init → Simulation
  ↓         ↓         ↓        ↓           ↓            ↓
main.c   GCC+LD   main.bin  Python   imem.hex/vh   Testbench
                                                        ↓
                                                    Verify Results
```

### Three Testing Stages

1. **RTL Simulation** - Functional verification with your HDL code
2. **Post-Synthesis** - Gate-level simulation with synthesis netlist + timing
3. **Post-P&R** - Layout simulation with back-annotated delays from P&R

---

## Firmware Compilation

### Memory Map (From memory_map.h)

Your SoC has this memory layout:

```
0x00000000 - 0x00007FFF : ROM (32 KB) - Instruction memory
0x00010000 - 0x0001FFFF : RAM (64 KB) - Data memory
0x00020000 - 0x0002FFFF : Peripherals (PWM, ADC, UART, etc.)
```

### Step 1: Write Your C Program

Create your firmware (e.g., `blink_led.c`):

```c
#include "../memory_map.h"

// Entry point (no standard library)
void _start(void) __attribute__((section(".text.start"), naked, noreturn));

void _start(void) {
    // Initialize peripherals
    GPIO->DIR = 0xF;  // Set GPIO 0-3 as outputs

    while (1) {
        // Toggle LED
        GPIO->OUT ^= 0x1;

        // Simple delay
        for (volatile int i = 0; i < 100000; i++);
    }
}
```

### Step 2: Compile with RISC-V GCC

**Requirements:**

- RISC-V GCC toolchain installed
- Linker script for your memory map

**Compile command:**

```bash
cd /home/furka/RV32IMZ/firmware/examples

# Simple program (inline assembly, no functions)
riscv32-unknown-elf-gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -nostartfiles \
    -O2 \
    -T ../application.ld \
    -o blink_led.elf \
    blink_led.c

# Complex program (with functions, libraries)
riscv32-unknown-elf-gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -T ../application.ld \
    -I.. \
    -O2 \
    -fno-inline \
    -o my_firmware.elf \
    my_firmware.c ../startup.S
```

**Linker script** (`application.ld`):

```ld
MEMORY {
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K
}

SECTIONS {
    .text : {
        *(.text.start)  /* Entry point first */
        *(.text*)
    } > ROM

    .data : {
        *(.data*)
    } > RAM AT > ROM

    .bss : {
        *(.bss*)
    } > RAM
}
```

### Step 3: Extract Binary

```bash
# Convert ELF to raw binary
riscv32-unknown-elf-objcopy \
    -O binary \
    blink_led.elf \
    blink_led.bin

# Verify with disassembly
riscv32-unknown-elf-objdump -d blink_led.elf > blink_led.dis
```

**Check the disassembly:**

- Entry point at 0x00000000
- Only RV32IM instructions
- No unexpected library calls

---

## Loading Firmware Into Macros

### Understanding Memory in Your Design

Your memory is in the **memory_macro** using **real SRAM instances**:

- 16 banks × 2KB = 32KB ROM
- 32 banks × 2KB = 64KB RAM
- Each bank is a `sky130_sram_2kbyte_1rw1r_32x512_8` hard macro

### Option 1: For Behavioral Simulation (Pre-Synthesis)

**Convert binary to Verilog hex format:**

```bash
cd /home/furka/RV32IMZ/programs

# Using bin2verilog.py (inline initialization)
python3 bin2verilog.py blink_led.bin -o blink_led_imem.vh

# Using bin2hex.py (readmemh format)
python3 ../sim/bin2hex.py blink_led.bin blink_led.hex
```

**In your testbench:**

```verilog
// Method 1: Inline initialization (for small programs)
initial begin
    `include "../../programs/blink_led_imem.vh"

    // Fill rest with NOPs
    for (i = NUM_INSTRUCTIONS; i < 8192; i = i + 1) begin
        rom_mem[i] = 32'h00000013;  // ADDI x0, x0, 0 (NOP)
    end
end

// Method 2: $readmemh (for larger programs)
initial begin
    $readmemh("../../programs/blink_led.hex", rom_mem);
end
```

### Option 2: For Post-Synthesis/P&R Simulation

**Problem:** Real SRAM macros are black boxes - you can't initialize them with `initial` blocks!

**Solution:** Use memory backdoor access or preload mechanism:

#### Method A: Backdoor Access (Modelsim/VCS)

```verilog
// In your testbench
initial begin
    // Wait for reset
    @(posedge rst_n);
    #100;

    // Backdoor write to SRAM instances
    // Path depends on hierarchy
    force dut.u_memory_macro.rom_bank_0.mem[0] = 32'h00000013;
    force dut.u_memory_macro.rom_bank_0.mem[1] = 32'h00100093;
    // ... etc
    #10;
    release dut.u_memory_macro.rom_bank_0.mem[0];
    release dut.u_memory_macro.rom_bank_0.mem[1];
end
```

#### Method B: Initialization through Wishbone Bus

```verilog
// Write firmware to ROM before starting execution
task load_firmware;
    input [255:0] filename;
    reg [31:0] data;
    integer file, i;

    file = $fopen(filename, "r");
    i = 0;

    while (!$feof(file)) begin
        $fscanf(file, "%h\n", data);

        // Write through Wishbone bus
        write_wishbone(ROM_BASE + (i * 4), data);
        i = i + 1;
    end

    $fclose(file);
    $display("Loaded %0d words from %s", i, filename);
endtask
```

#### Method C: Boot from External Source

Add a bootloader that loads firmware from:

- UART (serial upload)
- SPI flash
- Test interface

### Option 3: For Silicon/FPGA

Your memory needs to be **programmed before power-on** or have a **bootloader in ROM**.

**For FPGA:**

```bash
# Generate .mem file for Xilinx BRAM initialization
python3 bin2hex.py firmware.bin firmware.mem

# In Vivado, set INIT parameter for BRAM
# Or use COE file format
```

**For ASIC:**

```bash
# ROM mask programming (done at fab)
# 1. Generate hex/bin file
# 2. Foundry programs ROM during manufacturing
# 3. Cannot be changed after fabrication!

# For EEPROM/Flash (if you have it):
# Program through JTAG/SPI after chip arrives
```

---

## Post-Synthesis Testing

### What is Post-Synthesis Simulation?

**Goal:** Verify your design works with **gates** instead of RTL behavioral code.

**What you're testing:**

- Synthesis tool didn't introduce bugs
- Timing paths are reasonable
- Gate-level functionality matches RTL

### Step 1: Run Synthesis (Already Done)

Your macros are already synthesized:

```bash
# Synthesis outputs from build_complete_proven_package.sh
core_macro/netlist/core_macro_syn.v          # Gate-level netlist
memory_macro/netlist/memory_macro_syn.v
# ... etc
```

### Step 2: Create Post-Synthesis Testbench

```verilog
`timescale 1ns/1ps

module tb_post_synthesis;
    // Same signals as RTL testbench
    reg clk, rst_n;
    wire [31:0] gpio_out;
    wire uart_tx;

    // Instantiate SYNTHESIZED netlist (not RTL!)
    core_macro u_core (
        .clk(clk),
        .rst_n(rst_n),
        // ... connect all ports
    );

    // Need to also include PDK library cells
    // (sky130_fd_sc_hd__* primitives used in netlist)

    // Load firmware (same methods as before)
    initial begin
        $readmemh("firmware.hex", u_memory.rom_mem);
    end

    // Same test stimulus as RTL testbench
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    initial begin
        rst_n = 0;
        #100 rst_n = 1;

        #1000000;  // Run for 1ms

        if (gpio_out[0] == 1'b1) begin
            $display("PASS: LED is ON");
        end else begin
            $display("FAIL: LED should be ON");
        end

        $finish;
    end
endmodule
```

### Step 3: Run Post-Synthesis Simulation

```bash
cd /home/furka/RV32IMZ/sim

# Compile with synthesized netlist + PDK cells
iverilog \
    -g2012 \
    -I../pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog \
    -o sim_post_syn \
    tb_post_synthesis.v \
    ../distribution/rv32im_core_only/macros/core_macro/netlist/core_macro_syn.v \
    ../pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v \
    ../pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# Run simulation
vvp sim_post_syn

# View waveforms
gtkwave tb_post_synthesis.vcd
```

**Common issues:**

- Missing library cells → include all PDK verilog files
- X propagation → some flip-flops not initialized
- Timing violations → add SDF annotation (see next section)

### Step 4: Add SDF Timing (Optional)

```bash
# SDF file generated by synthesis (if available)
ls core_macro/outputs/core_macro_syn.sdf

# In testbench, add:
initial begin
    $sdf_annotate("../core_macro/outputs/core_macro_syn.sdf", u_core);
end
```

This adds **gate delays** to simulation for more accurate timing.

---

## Post-P&R Testing

### What is Post-P&R Simulation?

**Goal:** Verify chip works with **real layout**, including:

- Wire delays (interconnect RC)
- Placement-dependent delays
- Clock tree delays
- Power grid IR drop effects

**This is your FINAL verification before tapeout!**

### Step 1: Extract Netlist and Timing from P&R

After running Innovus P&R, you should have:

```bash
# Check outputs exist
ls core_macro/outputs/core_macro.v           # Post-P&R netlist
ls core_macro/outputs/core_macro.sdf         # Back-annotated delays
ls core_macro/outputs/core_macro.spef        # Parasitic extraction
```

**If missing, extract from Innovus:**

```tcl
# In Innovus (after routing)
saveNetlist core_macro.v -excludeLeafCell
write_sdf core_macro.sdf
rcOut -spef core_macro.spef
```

### Step 2: Create Post-P&R Testbench

```verilog
`timescale 1ns/1ps

module tb_post_pr;
    reg clk, rst_n;
    wire uart_tx;
    wire [7:0] gpio;

    // Instantiate POST-P&R netlist
    core_macro u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .gpio(gpio)
    );

    // CRITICAL: Annotate SDF delays
    initial begin
        $sdf_annotate(
            "../outputs/core_macro.sdf",
            u_core,
            , // Optional: specify corner
            "MAXIMUM", // MAXIMUM, TYPICAL, or MINIMUM
            , // Module instance
            , // Scale factors
            "FROM_MTM" // Timing check
        );
    end

    // Load firmware
    initial begin
        $readmemh("blink_led.hex", u_core.u_memory_macro.rom_mem);
    end

    // Clock (must account for P&R timing!)
    initial begin
        clk = 0;
        // Use slightly slower clock if timing violations
        forever #6 clk = ~clk;  // 83 MHz instead of 100 MHz
    end

    // Test stimulus
    initial begin
        rst_n = 0;
        #200 rst_n = 1;

        // Wait longer - post-P&R is MUCH slower to simulate!
        #10_000_000;  // 10ms

        // Check results
        if (gpio[0] == 1'b1) begin
            $display("✅ POST-P&R PASS: Firmware executed correctly");
        end else begin
            $display("❌ POST-P&R FAIL: GPIO not set");
        end

        $finish;
    end

    // Monitor for timing violations
    initial begin
        $timeformat(-9, 2, " ns", 10);
        forever begin
            @(posedge clk);
            if ($time > 1000) begin  // After reset
                // Check setup/hold violations
                if ($setup_violation || $hold_violation) begin
                    $display("⚠️  TIMING VIOLATION at %t", $time);
                end
            end
        end
    end
endmodule
```

### Step 3: Run Post-P&R Simulation

```bash
cd /home/furka/RV32IMZ/sim

# Commercial simulator recommended (ModelSim/VCS)
# Icarus Verilog has limited SDF support

# Using VCS (Synopsys)
vcs \
    -full64 \
    -sverilog \
    +v2k \
    -timescale=1ns/1ps \
    +define+SDF_ANNOTATE \
    -I ../pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog \
    tb_post_pr.v \
    ../distribution/rv32im_core_only/macros/core_macro/outputs/core_macro.v \
    ../pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v \
    -o simv_post_pr

./simv_post_pr

# Using Modelsim
vlog -sv tb_post_pr.v
vlog ../distribution/rv32im_core_only/macros/core_macro/outputs/core_macro.v
vsim -sdfmax /u_core=../outputs/core_macro.sdf tb_post_pr
run -all
```

**Warning:** Post-P&R simulation is **100-1000x slower** than RTL!

- Simulate only critical sections
- Use shorter test vectors
- Dump waveforms selectively

### Step 4: Analyze Timing Reports

```bash
# Check timing from Innovus reports
cat core_macro/reports/core_macro_timing.rpt

# Look for:
# - Setup violations (should be 0)
# - Hold violations (should be 0)
# - Worst negative slack (WNS) > 0
# - Total negative slack (TNS) = 0
```

**If timing violations exist:**

```tcl
# In Innovus, fix before extracting netlist
optDesign -postRoute
ecoRoute -fix_drc
```

---

## Full SoC Testing

### After All Macros Pass Individual Tests

```bash
# 1. Build complete SoC
cd /home/furka/RV32IMZ/distribution/rv32im_core_only/macros
./run_soc_complete.sh

# 2. Post-P&R netlist is at:
ls soc_integration/outputs/soc_complete.v
ls soc_integration/outputs/soc_complete.sdf
```

### SoC-Level Testbench

```verilog
module tb_soc_complete;
    reg clk_100mhz, rst_n;
    wire uart_tx, uart_rx;
    wire [7:0] pwm_out;
    wire [3:0] gpio;

    // Full SoC
    soc_complete u_soc (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .pwm_out(pwm_out),
        .gpio(gpio)
    );

    // SDF annotation for full chip
    initial begin
        $sdf_annotate(
            "../soc_integration/outputs/soc_complete.sdf",
            u_soc
        );
    end

    // Test comprehensive firmware
    initial begin
        // Test all peripherals
        // - GPIO toggle
        // - PWM generation
        // - UART communication
        // - ADC reading
        // - Timer interrupts
    end
endmodule
```

---

## Troubleshooting

### Firmware Won't Load

**Problem:** `$readmemh` fails or memory stays at X

**Solutions:**

1. Check file path is correct
2. Verify hex file format (one 32-bit word per line)
3. Check memory hierarchy path in testbench
4. For SRAM macros, use backdoor access instead

### Simulation Hangs

**Problem:** Simulation runs forever, no output

**Solutions:**

1. Add `$display` statements to track execution
2. Check PC (program counter) - is it incrementing?
3. Verify clock is toggling
4. Check reset sequence (active low vs active high)
5. Add timeout:

```verilog
initial begin
    #100_000_000;  // 100ms timeout
    $display("TIMEOUT - simulation stuck");
    $finish;
end
```

### X Propagation

**Problem:** Signals show X (unknown) in post-synthesis

**Solutions:**

1. Initialize all flip-flops in testbench:

```verilog
initial begin
    force u_core.pc = 32'h0;
    #10 release u_core.pc;
end
```

2. Check reset reaches all registers
3. Use `+define+RANDOM_INIT` to initialize to random values

### Timing Violations in Post-P&R

**Problem:** Setup/hold violations in SDF simulation

**Solutions:**

1. Slow down clock in testbench
2. Fix in Innovus:

```tcl
optDesign -postRoute -setup
optDesign -postRoute -hold
```

3. Relax timing constraints if needed
4. Check critical paths in timing report

### Memory Initialization Doesn't Work

**Problem:** SRAM macros can't be initialized with `initial` blocks

**Solutions:**

1. Use testbench to write through Wishbone bus
2. Add bootloader that loads from UART/SPI
3. For simulation only: use `force`/`release` backdoor access
4. Check if PDK provides initialization mechanism for SRAM

---

## Quick Reference Commands

### Compile Firmware

```bash
riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -T app.ld -o fw.elf fw.c
riscv32-unknown-elf-objcopy -O binary fw.elf fw.bin
python3 bin2hex.py fw.bin fw.hex
```

### RTL Simulation

```bash
iverilog -o sim tb.v core.v memory.v
vvp sim
gtkwave waveform.vcd
```

### Post-Synthesis Simulation

```bash
iverilog -I$PDK/verilog -o sim_syn tb.v core_syn.v primitives.v
vvp sim_syn
```

### Post-P&R Simulation

```bash
vcs +define+SDF_ANNOTATE -I$PDK/verilog tb_pr.v core_pr.v -o simv_pr
./simv_pr +sdf_verbose
```

### Check Timing

```bash
grep "slack" macros/*/reports/*_timing.rpt
grep "violation" macros/*/reports/*_timing.rpt
```

---

## Additional Resources

- **Programs directory:** `/home/furka/RV32IMZ/programs/` - Example firmware
- **Firmware directory:** `/home/furka/RV32IMZ/firmware/` - Bootloader & examples
- **Simulation scripts:** `/home/furka/RV32IMZ/sim/` - Testbenches
- **Memory map:** `/home/furka/RV32IMZ/firmware/memory_map.h` - Peripheral addresses

**For more help:**

- Check `programs/README.md` for firmware compilation details
- See `sim/QUICK_START_TESTING.md` for simulation workflows
- Review Innovus user guide for SDF/SPEF extraction

**Good luck with your testing! 🚀**
