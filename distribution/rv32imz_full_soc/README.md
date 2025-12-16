# RV32IMZ SoC - Complete Processor System with Cadence Academic Flow

This package contains the **full SoC** version of the RV32IMZ RISC-V processor - a complete standalone processor system with bootloader, memory, peripherals, and **complete Cadence academic synthesis flow**.

## Features

### Core Features

- **RV32I Base ISA**: 40 instructions
- **M Extension**: 8 multiply/divide instructions
- **Zicsr Extension**: CSR access for system control
- **3-stage pipeline**: Optimized for 50 MHz operation
- **98% RISC-V compliance**: Passes most official compliance tests

### System Features

- **Dual ROM Architecture**: 16KB bootloader + 16KB application space
- **64KB System RAM**: BRAM-based for fast access
- **UART Bootloader**: Upload firmware via serial interface with CRC32 verification
- **Complete Peripherals**: UART, PWM, Sigma-Delta ADC, LED/Switch controller
- **Memory Protection**: Bootloader cannot be overwritten by applications

### Academic Flow Features ⭐

- **Complete Cadence Flow**: Genus + Innovus RTL-to-GDSII
- **Sky130 PDK**: Industry-standard open PDK with SRAM macros
- **Automated Scripts**: One-command synthesis and place & route
- **Academic-Ready**: Designed for university Cadence environments

### Memory Map

```
0x0000_0000 - 0x0000_3FFF: Bootloader ROM (16KB) - Protected
0x0000_4000 - 0x0000_7FFF: Application ROM (16KB) - User code
0x1000_0000 - 0x1000_FFFF: System RAM (64KB) - Data/Stack
0x2000_0000 - 0x2000_00FF: UART Controller - 115200 baud
0x2000_0100 - 0x2000_01FF: PWM Generator - 8-bit resolution
0x2000_0200 - 0x2000_02FF: Sigma-Delta ADC - Temperature monitoring
0x2000_0300 - 0x2000_03FF: LED/Switch Controller - GPIO
```

## Quick Start Options

### Option 1: Open Source Flow (Yosys)

```bash
./synthesize_soc.sh
```

### Option 2: Cadence Academic Flow ⭐ NEW

```bash
cd synthesis/cadence
./run_cadence_flow.sh
```

## Cadence Academic Flow

### What's Included

- **Genus Synthesis Script** (`synthesis/cadence/synthesis.tcl`)
- **Innovus Place & Route** (`synthesis/cadence/place_route.tcl`)
- **SRAM Macro Placement** (`synthesis/cadence/macro_placement.cfg`)
- **Multi-corner Analysis** (`synthesis/cadence/mmmc.tcl`)
- **Complete Sky130 PDK** with SRAM macros
- **Automated Flow Script** (`synthesis/cadence/run_cadence_flow.sh`)

### Expected Results

```
Standard Cells: ~30,000-35,000
SRAM Macros: 2-3 instances
Total Area: ~0.5-1.0 mm²
Max Frequency: 50 MHz target
Final Output: GDSII layout ready for fabrication
```

### Academic Integration

- **Course**: Digital VLSI Design, Computer Architecture
- **Tools**: Cadence Genus, Innovus (university licenses)
- **PDK**: SkyWater Sky130 (open source)
- **Output**: Complete RTL-to-GDSII flow experience

## Traditional Synthesis (Yosys/Vivado)

### Build Bootloader & Test Application

```bash
# Build bootloader
cd firmware/bootloader
make clean && make

# Build test application
cd ../examples
make chb_test_simple.hex
```

### FPGA Programming (Basys3)

```bash
# Generate bitstream (Vivado required)
vivado -mode batch -source program_fpga.tcl

# Upload to FPGA
python3 tools/fpga_programmer.py synthesized_soc.bit
```

### Upload Firmware via UART

```bash
# Connect to UART (115200 baud)
screen /dev/ttyUSB0 115200

# Upload application (3-second window after reset)
python3 firmware/tools/upload_firmware.py firmware/examples/chb_test_simple.hex
```

## Resource Usage

### FPGA Results (Basys3 XC7A35T)

```
Total Cells: 32,440
Logic LUTs: 19,467 (93.6% utilization)
Registers: 2,538 (6.1% utilization)
DSP Blocks: 18 (20% utilization)
Block RAM: 8 (16% utilization)
Max Frequency: 50 MHz
```

### ASIC Results (Sky130, Estimated)

```
Standard Cells: ~30,000-35,000
Area: 0.5-1.0 mm²
Power: ~50-100 mW @ 50 MHz
Frequency: 50 MHz (constrained by memory timing)
Technology: 130nm Sky130 PDK
```

## Files Included

### Synthesis Options

- `synthesize_soc.sh` - Open source SoC synthesis (Yosys)
- `synthesis/cadence/` - **Complete Cadence academic flow**
- `synthesis/opensource/` - Yosys + OpenROAD alternative
- `synthesized_soc.v` - Pre-synthesized netlist
- `synthesis_report.txt` - Resource usage analysis

### RTL Sources

- `rtl/core/` - RV32IM processor core
- `rtl/memory/` - Dual ROM + RAM controllers
- `rtl/peripherals/` - UART, PWM, ADC, GPIO
- `rtl/soc/` - System integration and bus fabric

### Technology Files

- `pdk/sky130A/` - **Complete Sky130 PDK**
- `pdk/sky130A/libs.ref/sky130_sram_macros/` - **SRAM macros for Cadence**
- Standard cell libraries (3 corners: SS, TT, FF)
- LEF files for place & route

### Firmware & Software

- `firmware/bootloader/` - UART bootloader with CRC32
- `firmware/examples/` - Test applications
- `firmware/tools/` - Upload utilities, hex converters

### Constraints & Config

- `constraints/soc_timing.sdc` - Timing constraints for 50 MHz
- `constraints/basys3.xdc` - Basys3 FPGA pin assignments

## Testing Procedures

### 1. Cadence Flow Verification

```bash
cd synthesis/cadence
./run_cadence_flow.sh

# Check results
ls outputs/
# Should contain: soc_simple_final.gds, timing_report.txt, etc.
```

### 2. Pre-Synthesis Simulation

```bash
# Complete SoC functional test
./sim/run_soc_top_test.sh

# UART communication test
./sim/run_single_char_test.sh
```

### 3. Post-Synthesis Verification

```bash
# Generate post-synthesis testbench
python3 verify_post_synthesis.py

# Run verification
make verify_post_synth
```

## Academic Usage

### For Instructors

- **Lecture Topics**: RTL-to-GDSII flow, physical design, timing closure
- **Lab Exercises**: Synthesis optimization, layout analysis, power estimation
- **Course Integration**: Digital VLSI, Computer Architecture, ASIC Design
- **Assessment**: Timing reports, area optimization, layout visualization

### For Students

- **Learning Outcomes**: Industry tool experience, physical design understanding
- **Hands-on Skills**: Constraint writing, floorplanning, timing analysis
- **Design Flow**: Complete ASIC methodology from RTL to fabrication files
- **Real Project**: Working RISC-V processor suitable for academic research

### Prerequisites

- **Software**: Cadence Genus, Innovus (university license)
- **Knowledge**: Digital design, Verilog, basic VLSI concepts
- **Hardware**: Linux workstation (recommended: 16GB RAM, 100GB storage)

## Advanced Features

### Multi-Corner Optimization

```bash
# Synthesis with 3 corners (SS, TT, FF)
# Automatic timing optimization across PVT
cd synthesis/cadence
# Edit mmmc.tcl for additional corners
```

### Custom Constraints

```sdc
# Add your timing constraints
create_clock -period 20.0 [get_ports clk]
set_input_delay 2.0 [all_inputs] -clock clk
set_output_delay 2.0 [all_outputs] -clock clk
```

### Power Analysis

```bash
# Enable power analysis in Innovus
# Modify place_route.tcl to include power optimization
```

## Documentation

### Complete Guides

- **SYNTHESIS_GUIDE.md** - Comprehensive synthesis documentation
- **synthesis/cadence/README.md** - Cadence-specific instructions
- **docs/** - Detailed technical documentation

### Quick References

- Timing closure procedures
- SRAM macro integration
- Physical design best practices
- Troubleshooting common issues

## Next Steps

### For Academic Use

1. Run `cd synthesis/cadence && ./run_cadence_flow.sh`
2. Analyze timing and area reports
3. View GDSII layout in Virtuoso or other viewer
4. Modify constraints for optimization exercises

### For FPGA Deployment

1. Run `./synthesize_soc.sh` for FPGA synthesis
2. Build and test bootloader applications
3. Deploy to Basys3 FPGA for hardware validation

### For Research Projects

1. Use as baseline RISC-V implementation
2. Add custom instructions or accelerators
3. Explore advanced synthesis optimizations
4. Generate fabrication-ready GDSII

## Support

**Academic Institutions**: Complete flow is designed for university Cadence environments with standard EDA licenses.

**Documentation**: Comprehensive guides included for both instructors and students.

**Customization**: Easy to modify for different PDKs, constraints, or design variations.

---

**This package provides everything needed for a complete academic ASIC design experience, from RTL to fabrication-ready GDSII, using industry-standard Cadence tools and open-source Sky130 technology.**
