# Complete RV32IMZ Synthesis Guide

This guide covers synthesis for both **core-only** and **full SoC** configurations of the RV32IMZ RISC-V processor, including comprehensive testing procedures.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core-Only Synthesis](#core-only-synthesis)
3. [Full SoC Synthesis](#full-soc-synthesis)
4. [Testing Procedures](#testing-procedures)
5. [Resource Analysis](#resource-analysis)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites

```bash
# Required tools
sudo apt install yosys iverilog gtkwave
# Optional: Vivado, Quartus for commercial synthesis
```

### Directory Structure

```
RV32IMZ/
├── synthesize.sh          # Core-only synthesis
├── synthesize_soc.sh      # Full SoC synthesis
├── rtl/                   # RTL sources
│   ├── core/             # Core modules
│   ├── memory/           # Memory controllers
│   ├── peripherals/      # UART, PWM, etc.
│   └── soc/             # System integration
├── constraints/          # Timing constraints
├── firmware/            # Bootloader & test apps
└── synthesized_*.v      # Synthesis outputs
```

### Core vs SoC Overview

| Feature            | Core-Only                       | Full SoC                                |
| ------------------ | ------------------------------- | --------------------------------------- |
| **Size**           | ~800 cells                      | ~32,440 cells                           |
| **Components**     | CPU + basic I/O                 | CPU + Memory + Peripherals + Bootloader |
| **Use Case**       | Integration into larger systems | Standalone processor system             |
| **Synthesis Time** | ~5 seconds                      | ~30 seconds                             |
| **Target**         | Drop-in CPU module              | Complete FPGA implementation            |

---

## Core-Only Synthesis

### Overview

The core-only synthesis creates a **standalone RV32IM CPU** that can be integrated into larger designs.

### Components Included

- **3-stage pipelined CPU** (Fetch, Decode+Execute, Writeback)
- **RV32I Base ISA** (40 instructions)
- **M Extension** (Multiply/Divide - 8 instructions)
- **Zicsr Extension** (CSR access)
- **Exception handling** (traps, interrupts)
- **Wishbone B4 interface** (standard bus protocol)

### Synthesis Commands

#### Option 1: Yosys (Open Source) - Default

```bash
# Quick synthesis
./synthesize.sh yosys

# Output files
ls synthesized_core.v synthesized_core.json
```

#### Option 2: Vivado (Xilinx)

```bash
# Generate Vivado project
./synthesize.sh vivado

# Run generated script
vivado -mode batch -source vivado_synth.tcl

# Results in vivado_project/
```

#### Option 3: Quartus (Intel/Altera)

```bash
# Generate Quartus project
./synthesize.sh quartus

# Compile project
quartus_sh --flow compile rv32im
```

#### Option 4: Cadence Academic Flow (GDS Output)

```bash
# Navigate to Cadence synthesis directory
cd synthesis_cadence

# Run complete RTL-to-GDSII flow
./run_cadence_flow.sh

# Outputs:
# - outputs/core_final.gds (GDS layout)
# - outputs/core_netlist.v (gate-level netlist) 
# - reports/ (timing, area, power)
```

### Core Resource Usage

```
=== Core Statistics (Yosys) ===
Total Cells: 802
Logic Elements: ~600-800
Registers: ~120-150
Memory: 1 ROM block (for instruction decoding)
Max Frequency: 50-100 MHz
```

### Integration Example

```verilog
// Integrating the core into your design
module my_system (
    input  wire        clk,
    input  wire        rst_n,
    // ... other system signals
);

// Instantiate RV32IM core
custom_riscv_core cpu (
    .clk(clk),
    .rst_n(rst_n),

    // Wishbone instruction bus
    .iwb_cyc_o(iwb_cyc),
    .iwb_stb_o(iwb_stb),
    .iwb_adr_o(iwb_adr),
    .iwb_dat_i(iwb_dat_i),
    .iwb_ack_i(iwb_ack),

    // Wishbone data bus
    .dwb_cyc_o(dwb_cyc),
    .dwb_stb_o(dwb_stb),
    .dwb_we_o(dwb_we),
    .dwb_adr_o(dwb_adr),
    .dwb_dat_o(dwb_dat_o),
    .dwb_dat_i(dwb_dat_i),
    .dwb_sel_o(dwb_sel),
    .dwb_ack_i(dwb_ack),

    // Interrupts & debug
    .ext_interrupt(ext_irq),
    .timer_interrupt(timer_irq),
    .software_interrupt(sw_irq)
);

// Connect to your memory system, peripherals, etc.
endmodule
```

---

## Full SoC Synthesis

### Overview

The full SoC synthesis creates a **complete processor system** with bootloader, memory, and peripherals ready for FPGA deployment.

### Components Included

- **RV32IM Core** (same as core-only)
- **Dual ROM Architecture**: 16KB bootloader + 16KB application
- **64KB System RAM** (BRAM-based)
- **UART Controller** (115200 baud)
- **PWM Generator** (8-bit resolution)
- **Sigma-Delta ADC** (temperature monitoring)
- **LED & switch controllers**
- **UART Bootloader** with CRC32 verification

### Synthesis Command

```bash
# Complete SoC synthesis
./synthesize_soc.sh

# Outputs
ls synthesized_soc.v synthesized_soc.json
ls synthesis/soc_results/synthesis_report.txt
```

### SoC Resource Usage

```
=== SoC Statistics ===
Total Cells: 32,440
Logic LUTs: 19,467 (93.6% of XC7A35T)
Registers: 2,538 (6.1% of XC7A35T)
DSP Blocks: 18 (20% of XC7A35T)
Block RAM: 8 (16% of XC7A35T)
Max Frequency: 50 MHz (20ns period)
RISC-V Compliance: 98%
```

### Memory Map

```
0x0000_0000 - 0x0000_3FFF: Bootloader ROM (16KB)
0x0000_4000 - 0x0000_7FFF: Application ROM (16KB)
0x1000_0000 - 0x1000_FFFF: System RAM (64KB)
0x2000_0000 - 0x2000_00FF: UART Controller
0x2000_0100 - 0x2000_01FF: PWM Generator
0x2000_0200 - 0x2000_02FF: Sigma-Delta ADC
0x2000_0300 - 0x2000_03FF: LED/Switch Controller
```

### Boot Process

1. **Power-on**: CPU starts at 0x0000_0000 (bootloader)
2. **3-second window**: Wait for UART upload command
3. **No command**: Jump to application at 0x0000_4000
4. **Upload mode**: Receive new application via UART with CRC32

---

## Testing Procedures

### Core-Only Testing

#### 1. Functional Verification

```bash
# Basic instruction tests
cd sim
make test_core

# Run comprehensive testbench
iverilog -o test_core tb_comprehensive.v ../rtl/core/*.v
vvp test_core
gtkwave test_core.vcd
```

#### 2. Instruction Coverage

```bash
# Test specific instruction categories
make test_alu      # Arithmetic/Logic
make test_memory   # Load/Store
make test_branch   # Control flow
make test_csr      # System instructions
```

### Full SoC Testing

#### 1. Pre-Synthesis Simulation

```bash
# Complete SoC functional test
./sim/run_soc_top_test.sh

# UART communication test
./sim/run_single_char_test.sh

# Bootloader verification
cd firmware/bootloader && make test
```

#### 2. Build Test Applications

```bash
# Build bootloader
cd firmware/bootloader
make clean && make

# Build test application
cd ../examples
make chb_test_simple.hex

# Upload test (requires hardware)
../tools/upload_firmware.py chb_test_simple.hex
```

#### 3. Post-Synthesis Verification

```bash
# Generate post-synthesis testbench
python3 verify_post_synthesis.py

# Run post-synthesis simulation
iverilog -o post_synth_test tb_post_synthesis.v synthesized_soc.v
vvp post_synth_test
```

### Hardware Testing (FPGA)

#### 1. FPGA Programming

```bash
# Generate bitstream (Vivado)
vivado -mode batch -source program_fpga.tcl

# Upload to Basys3 FPGA
python3 tools/fpga_programmer.py synthesized_soc.bit
```

#### 2. Bootloader Test

```bash
# Connect UART (115200 baud)
screen /dev/ttyUSB0 115200

# Upload test application
python3 firmware/tools/upload_firmware.py firmware/examples/chb_test_simple.hex

# Expected output:
# "Bootloader v1.0 Ready"
# "Application uploaded successfully"
# "CHB Test Application Started"
# "LED Pattern: 0x55"
```

#### 3. System Verification

```bash
# Monitor system status
python3 tools/system_monitor.py

# Check all peripherals
python3 tools/peripheral_test.py

# Performance analysis
python3 tools/benchmark.py
```

---

## Resource Analysis

### Target FPGA: Basys3 (XC7A35T-1CPG236C)

| Resource      | Available | Core-Only   | Full SoC     | SoC Usage |
| ------------- | --------- | ----------- | ------------ | --------- |
| **LUTs**      | 20,800    | ~800 (4%)   | 19,467 (94%) | Very High |
| **Registers** | 41,600    | ~150 (0.3%) | 2,538 (6%)   | Low       |
| **DSP48**     | 90        | 9 (10%)     | 18 (20%)     | Low       |
| **BRAM**      | 50        | 1 (2%)      | 8 (16%)      | Low       |

### Performance Analysis

| Metric                | Core-Only | Full SoC | Notes                     |
| --------------------- | --------- | -------- | ------------------------- |
| **Clock Frequency**   | 100+ MHz  | 50 MHz   | Limited by memory timing  |
| **RISC-V Compliance** | 100%      | 98%      | Timing-related edge cases |
| **DMIPS**             | ~0.8      | ~0.8     | Same core performance     |
| **Power**             | Low       | Medium   | More peripherals active   |

### Optimization Options

```bash
# High performance (core-only)
./synthesize.sh yosys -D HIGH_PERFORMANCE

# Low power (full SoC)
./synthesize_soc.sh -D LOW_POWER_MODE

# Minimal area (core-only)
./synthesize.sh yosys -D MINIMAL_AREA
```

---

## Troubleshooting

### Common Issues

#### 1. Synthesis Fails

```bash
# Check RTL syntax
iverilog -tnull -Wall rtl/core/*.v

# Verify all files present
ls rtl/core/ | grep -E "\.(v|vh)$"

# Check module hierarchy
yosys -p "read_verilog rtl/core/*.v; hierarchy -check"
```

#### 2. Timing Violations

```bash
# Check critical paths
grep -i "slack" synthesis_report.txt

# Reduce clock frequency in constraints
vim constraints/rv32imz_timing.sdc
# Change: create_clock -period 20.0 → create_clock -period 25.0
```

#### 3. Resource Overflow

```bash
# Check utilization
grep -A5 "Utilization" synthesis_report.txt

# Reduce SoC features
# Edit rtl/soc/soc_top.v, disable unused peripherals
```

#### 4. Simulation Mismatches

```bash
# Compare pre/post synthesis
diff sim_results_rtl.txt sim_results_synthesis.txt

# Check for synthesis optimization issues
grep -i warning synthesis.log
```

### Debug Techniques

#### 1. Waveform Analysis

```bash
# Generate detailed waveforms
iverilog -DDEBUG_MODE -o debug_sim tb_comprehensive.v rtl/core/*.v
vvp debug_sim
gtkwave debug_sim.vcd

# Key signals to watch:
# - clk, rst_n
# - pc, instruction
# - alu_result, reg_write_data
# - dwb_*, iwb_* (bus transactions)
```

#### 2. Printf Debugging

```verilog
// Add to RTL for simulation
`ifdef DEBUG_MODE
always @(posedge clk) begin
    if (instruction_valid) begin
        $display("PC: 0x%08x, Instr: 0x%08x", pc, instruction);
    end
end
`endif
```

#### 3. Synthesis Logs

```bash
# Analyze optimization steps
grep -E "(Removed|Optimizing|Warning)" synthesis.log | head -20

# Check resource inference
grep -E "(BRAM|DSP|LUT)" synthesis.log
```

### Getting Help

#### 1. Debug Information to Collect

```bash
# System information
./tools/collect_debug_info.sh

# Generates: debug_info.tar.gz containing:
# - All source files
# - Synthesis logs
# - Simulation outputs
# - Timing reports
```

#### 2. Test Minimal Cases

```bash
# Test core components individually
make test_regfile
make test_alu
make test_decoder
make test_mdu

# Isolate the failing component
```

#### 3. Version Compatibility

```bash
# Check tool versions
yosys --version     # Tested with 0.33+
iverilog -v         # Tested with 11.0+
python3 --version   # Tested with 3.8+
```

---

## Distribution Files

### Core-Only Package

```
rv32im_core.tar.gz contains:
├── synthesize.sh
├── rtl/core/
├── constraints/basic_timing.sdc
├── synthesized_core.v
├── synthesized_core.json
└── README_CORE.md
```

### Full SoC Package

```
rv32imz_soc.tar.gz contains:
├── synthesize_soc.sh
├── rtl/ (complete)
├── firmware/ (complete)
├── constraints/
├── synthesized_soc.v
├── synthesized_soc.json
├── synthesis_report.txt
└── README_SOC.md
```

### Usage

```bash
# Extract and use core
tar -xzf rv32im_core.tar.gz
cd rv32im_core
./synthesize.sh yosys

# Extract and use full SoC
tar -xzf rv32imz_soc.tar.gz
cd rv32imz_soc
./synthesize_soc.sh
```

---

## Conclusion

Both synthesis flows are production-ready:

- **Core-only**: Perfect for integration into custom SoCs
- **Full SoC**: Complete standalone processor system with bootloader

The core achieves 98% RISC-V compliance and synthesizes successfully on academic and commercial tools. The full SoC provides a complete embedded processor platform with UART bootloader for easy firmware updates.

**Next Steps**:

1. Choose synthesis flow based on your needs
2. Follow testing procedures to verify functionality
3. Deploy to target FPGA platform
4. Develop custom applications using provided bootloader
