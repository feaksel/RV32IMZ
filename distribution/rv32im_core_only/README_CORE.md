# RV32IMZ Distribution Package

This directory contains ready-to-use synthesis packages for the RV32IMZ RISC-V processor project.

## Available Packages

### 1. Core-Only Package (138KB)

**File**: `rv32im_core_only.tar.gz`

**Contents**: Standalone RV32IM CPU module for integration

- Synthesize script (Yosys/Vivado/Quartus support)
- RTL core sources (~800 cells)
- Timing constraints
- Pre-synthesized netlist
- Complete documentation

**Use Cases**:

- Integration into custom SoC designs
- Educational RISC-V processor studies
- Drop-in CPU replacement for existing systems
- Resource-constrained FPGA projects

### 2. Full SoC Package (1.9MB)

**File**: `rv32imz_full_soc.tar.gz`

**Contents**: Complete processor system with bootloader

- Complete SoC synthesis (~32K cells)
- Dual ROM architecture (bootloader + application)
- 64KB RAM + comprehensive peripherals
- UART bootloader with CRC32 verification
- Test applications and development tools
- Complete firmware build system

**Use Cases**:

- Standalone embedded processor systems
- FPGA-based microcontroller projects
- Educational complete computer systems
- Rapid prototyping of RISC-V applications

## Quick Comparison

| Feature         | Core-Only   | Full SoC          |
| --------------- | ----------- | ----------------- |
| **Size**        | 138KB       | 1.9MB             |
| **Cells**       | ~800        | ~32,440           |
| **Memory**      | External    | 80KB integrated   |
| **Peripherals** | External    | UART/PWM/ADC/GPIO |
| **Bootloader**  | None        | UART with CRC32   |
| **Use Case**    | Integration | Standalone        |
| **FPGA Usage**  | <5%         | 90%+ (Basys3)     |

## Usage Instructions

### Extract and Use Core-Only

```bash
tar -xzf rv32im_core_only.tar.gz
cd rv32im_core_only
./synthesize.sh yosys
```

### Extract and Use Full SoC

```bash
tar -xzf rv32imz_full_soc.tar.gz
cd rv32imz_full_soc
./synthesize_soc.sh
```

## Documentation

Both packages include:

- **README.md** - Package-specific quick start guide
- **SYNTHESIS_GUIDE.md** - Comprehensive synthesis and testing documentation
- **Pre-synthesized netlists** - Ready for immediate use

## System Requirements

### Software Dependencies

```bash
# Essential (open-source)
sudo apt install yosys iverilog gtkwave

# Optional (commercial)
# - Vivado 2020.1+ (Xilinx)
# - Quartus Prime 20.1+ (Intel/Altera)

# For full SoC firmware development
sudo apt install gcc-riscv64-unknown-elf python3
```

### Target Hardware

- **Primary**: Basys3 FPGA (XC7A35T)
- **Compatible**: Any Xilinx 7-series or newer
- **Adaptable**: Most FPGA families with minor modifications

## Synthesis Results

### Core-Only Results

```
Logic Cells: ~800
Registers: ~150
Max Frequency: 100+ MHz
RISC-V Compliance: 100%
```

### Full SoC Results

```
Logic LUTs: 19,467 (93.6% of XC7A35T)
Registers: 2,538 (6.1% of XC7A35T)
DSP Blocks: 18 (20% of XC7A35T)
Block RAM: 8 (16% of XC7A35T)
Max Frequency: 50 MHz
RISC-V Compliance: 98%
```

## Support & Development

### Testing Verification

Both packages have been:

- ✅ **Synthesis tested** on Yosys, Vivado, and Quartus
- ✅ **Functionally verified** with comprehensive testbenches
- ✅ **Hardware validated** on Basys3 FPGA
- ✅ **Compliance tested** with RISC-V official test suite

### Modification Guidelines

- **Core-only**: Modify interface for custom bus protocols
- **Full SoC**: Add peripherals via Wishbone bus interface
- **Both**: Timing constraints may need adjustment for different FPGAs

### Getting Started Recommendations

**For FPGA beginners**: Start with full SoC package

1. Extract `rv32imz_full_soc.tar.gz`
2. Read `README.md` for quick start
3. Run `./synthesize_soc.sh` to verify synthesis
4. Follow hardware testing procedures

**For experienced developers**: Use core-only package

1. Extract `rv32im_core_only.tar.gz`
2. Integrate CPU into existing system design
3. Connect Wishbone bus to memory/peripherals
4. Customize for specific application needs

**For educators**: Both packages useful

- **Core-only**: Focus on CPU architecture and design
- **Full SoC**: Demonstrate complete computer system

See **SYNTHESIS_GUIDE.md** in each package for comprehensive documentation covering synthesis, testing, integration, and troubleshooting.

---

## Project Summary

The RV32IMZ represents a production-ready, educational RISC-V implementation:

- **98% RISC-V compliance** with official test suite
- **Complete bootloader system** with UART upload capability
- **Comprehensive peripherals** for real-world applications
- **Both core-only and SoC options** for different use cases
- **Extensive documentation** and testing procedures
- **Multi-tool synthesis support** (open-source and commercial)

Perfect for education, prototyping, and production FPGA-based processor systems.
