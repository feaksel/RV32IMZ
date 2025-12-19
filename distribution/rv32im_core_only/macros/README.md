# RV32IM SoC 6-Macro Hierarchical Implementation

## Overview

This directory contains the complete hierarchical implementation of the RV32IM System-on-Chip (SoC) using a **6-macro approach** optimized for academic and professional ASIC design flows with Cadence Genus and Innovus using SKY130 PDK.

## Architecture

### 6-Macro Hierarchical Breakdown

The RV32IM SoC is divided into six carefully designed macros:

#### 1. CPU Core Macro (~11,000 gates)

- **Purpose:** Complete RV32IM processor with MDU integrated
- **Contents:**
  - 5-stage pipeline (Fetch, Decode, Execute, Memory, Writeback)
  - Register file (32x32-bit)
  - ALU and comparison logic
  - MDU (Multiplication/Division Unit) with Booth encoding
  - Branch prediction and control hazard detection
  - Data hazard detection and forwarding
  - Wishbone master interface
  - CSR (Control and Status Registers)

#### 2. Memory Macro (~10,000 gates + SRAM macros)

- **Purpose:** Manages 32KB ROM and 64KB RAM using **real SKY130 SRAM macros**
- **Contents:**
  - **ROM (32KB):** 16 banks of sky130_sram_2kbyte_1rw1r_32x512_8
    - Address mapping: `rom_addr[14:11]` selects bank (0-15)
    - Each bank: 2048 bytes (512 words × 32 bits)
  - **RAM (64KB):** 32 banks of sky130_sram_2kbyte_1rw1r_32x512_8
    - Address mapping: `ram_addr[15:11]` selects bank (0-31)
    - Each bank: 2048 bytes (512 words × 32 bits)
  - Banking mux logic with enable decode
  - Wishbone slave interface with data multiplexing
- **SRAM Integration:** Black-box synthesis with don't-touch constraints

#### 3. PWM Accelerator Macro (~3,000 gates)

- **Purpose:** Hardware PWM generation for motor control
- **Contents:**
  - 4 independent PWM channels
  - Configurable period and duty cycle registers
  - Phase offset control for advanced motor timing
  - Wishbone slave interface

#### 4. ADC Subsystem Macro (~4,000 gates)

- **Purpose:** Sigma-delta ADC with digital filtering
- **Contents:**
  - Sigma-delta modulator interface
  - Digital decimation filter (CIC + FIR)
  - Multi-channel ADC support (4 channels)
  - Sample rate control and sequencing
  - Wishbone slave interface with CDC

#### 5. Protection Macro (~1,000 gates)

- **Purpose:** System protection and thermal monitoring
- **Contents:**
  - Thermal sensor interface
  - Overheat detection with configurable thresholds
  - Watchdog timer with programmable timeout
  - System reset generation logic
  - Wishbone slave interface

#### 6. Communication Macro (~2,000 gates)

- **Purpose:** UART and SPI communication peripherals
- **Contents:**
  - UART: Configurable baud rate, TX/RX with FIFOs
  - SPI: Master/Slave modes, 8/16/32-bit transfers
  - Wishbone slave interface for register access

### Why This Breakdown?

1. **Modular Verification:** Each peripheral can be tested independently
2. **Reusability:** Swap or upgrade individual peripherals without redesigning entire SoC
3. **Physical Design:** Smaller macros are easier to floorplan and achieve timing closure
4. **Academic Value:** Students can study individual subsystems and understand macro integration
5. **Real SRAM Macros:** Memory implementation uses actual SKY130 SRAM macros (not behavioral) for realistic silicon design

## SRAM Macro Implementation Details

### Memory Banking Architecture

**ROM (32KB total = 16 banks × 2KB):**

```
Address: 0x0000_0000 - 0x0000_7FFF
Bank Selection: rom_addr[14:11] (bits 14-11 select 1 of 16 banks)
Bank Offset: rom_addr[10:2] (512 word addresses per bank)
```

**RAM (64KB total = 32 banks × 2KB):**

```
Address: 0x0001_0000 - 0x0001_FFFF
Bank Selection: ram_addr[15:11] (bits 15-11 select 1 of 32 banks)
Bank Offset: ram_addr[10:2] (512 word addresses per bank)
```

### SRAM Synthesis Handling

In synthesis scripts (`memory_macro/synthesis.tcl`):

```tcl
# Read SRAM macros as black boxes
read_verilog /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_sram_macros/verilog/sky130_sram_2kbyte_1rw1r_32x512_8.v

# Prevent optimization of SRAM instances
set_dont_touch [get_cells -hier -filter {ref_name =~ sky130_sram*}]
```

Timing constraints in `memory_macro.sdc`:

```sdc
# SRAM timing from datasheet (example values - verify with actual macro specs)
set sram_setup 0.5
set sram_hold 0.2
set_input_delay -clock clk_macro -max $sram_setup [get_pins sram_*/din*]
```

## Build Scripts Explained

### 1. build_complete_proven_package.sh ✅ **MAIN BUILD SCRIPT**

**Alternative:** `run_complete_macro_package.sh` does the same thing with more verbose logging

### build_complete_proven_package.sh

**Purpose:** Builds all 6 individual macros using proven working synthesis/P&R templates

**What it does:**

- Synthesizes each macro separately using Genus
- Place & Route each macro using Innovus
- Generates individual GDS files for each macro
- Creates LEF abstract views for hierarchical integration
- Produces timing and area reports

**When to use:**

- Building the complete macro library from scratch
- Rebuilding specific macros after RTL changes
- Generating individual macro GDS for inspection

**Outputs:**

```
core_macro/outputs/core_macro.gds + .lef
mdu_macro/outputs/mdu_macro.gds + .lef (if built separately)
memory_macro/outputs/memory_macro.gds + .lef
pwm_accelerator_macro/outputs/pwm_accelerator.gds + .lef
adc_subsystem_macro/outputs/adc_subsystem.gds + .lef
protection_macro/outputs/protection_macro.gds + .lef
communication_macro/outputs/communication_macro.gds + .lef
```

**Run it:**

```bash
cd /home/furka/RV32IMZ/distribution/rv32im_core_only/macros
./build_complete_proven_package.sh
```

### 2. COMPLETE_SETUP.sh ℹ️ **OPTIONAL VERIFICATION SCRIPT**

**Purpose:** Verifies setup and adds any missing error handling (CTS fallback, etc.)

**Status:** Optional - all fixes have been applied to the scripts already

**When to use:**

- If you want to double-check all scripts have proper error handling
- To verify SRAM macros are present
- Creates backup before any changes

**Note:** All necessary fixes are already in the P&R scripts, so this is optional.

### 3. run_hierarchical_flow.sh ⚠️ **DEPRECATED - DON'T USE**

**Purpose:** Old 2-macro approach (MDU + Core only) - replaced by 6-macro architecture

**Status:** Outdated, kept for historical reference

**Why not to use:**

- Implements old 2-macro breakdown
- Does not include peripherals (PWM, ADC, Protection, Communication)
- Does not use SRAM macros for memory
- Superseded by build_complete_proven_package.sh + run_soc_complete.sh

### 4. run_complete_macro_package.sh ✅ **ALTERNATIVE TO build_complete_proven_package.sh**

**Purpose:** Same as build_complete_proven_package.sh but with more verbose colored logging

**Difference:** More detailed progress output, better for monitoring long builds

**When to use:** If you prefer more detailed build status messages

### 5. run_soc_complete.sh ✅ **USE THIS FOR FINAL CHIP INTEGRATION**

**Purpose:** Integrates all 6 macros into final SoC and generates complete chip GDS

**What it does:**

- Uses pre-built macro LEF/GDS files from individual macro builds
- Synthesizes top-level SoC (Wishbone bus interconnect, glue logic)
- Places all 6 macros as black-box instances
- Routes top-level interconnections
- Generates final integrated `soc_complete.gds`

**Prerequisites:**

- Must run `build_complete_proven_package.sh` first to generate all macro GDS/LEF files

**When to use:**

- After all individual macros are built successfully
- For final chip tape-out preparation
- To verify full SoC integration

**Outputs:**

```
soc_integration/outputs/soc_complete.gds  ← FINAL CHIP GDS
soc_integration/outputs/soc_complete.lef
soc_integration/outputs/soc_complete_timing.rpt
soc_integration/outputs/soc_complete_area.rpt
```

**Run it:**

```bash
cd /home/furka/RV32IMZ/distribution/rv32im_core_only/macros
./run_soc_complete.sh
```

### Individual Macro Scripts

Some macros have their own dedicated build scripts:

- **core_macro/run_core_macro.sh** - Build just the core macro
- **mdu_macro/run_mdu_macro.sh** - Build just the MDU macro (if separate from core)

**Note:** Core macro includes MDU integrated, so mdu_macro is optional/historical.

For other macros (memory, PWM, ADC, protection, communication), use the main build script or run Genus/Innovus directly on their scripts.

## Recommended Build Flow (Step-by-Step)

### Step 1: Build All Individual Macros

```bash
cd /home/furka/RV32IMZ/distribution/rv32im_core_only/macros
./build_complete_proven_package.sh
```

Wait for completion (~3-4 hours depending on hardware). Verify outputs:

```bash
ls -lh core_macro/outputs/core_macro.gds
ls -lh memory_macro/outputs/memory_macro.gds
ls -lh pwm_accelerator_macro/outputs/pwm_accelerator.gds
ls -lh adc_subsystem_macro/outputs/adc_subsystem.gds
ls -lh protection_macro/outputs/protection_macro.gds
ls -lh communication_macro/outputs/communication_macro.gds
```

**Or build individual macros:**

```bash
# Core macro has its own script
cd core_macro && ./run_core_macro.sh

# MDU macro (if separate build needed)
cd mdu_macro && ./run_mdu_macro.sh

# Other macros - use Genus/Innovus directly
cd memory_macro
genus -batch -files scripts/memory_synthesis.tcl
innovus -batch -files scripts/memory_place_route.tcl
```

### Step 2: Integrate Into Final SoC

```bash
./run_soc_complete.sh
```

Wait for top-level integration (~10-20 minutes). Verify final output:

```bash
ls -lh soc_integration/outputs/soc_complete.gds
```

### Step 3: View Results (Optional)

```bash
# View individual macro
klayout core_macro/outputs/core_macro.gds

# View final integrated chip
klayout soc_integration/outputs/soc_complete.gds
```

## Output Locations Summary

| What                  | Where                                      |
| --------------------- | ------------------------------------------ |
| Individual Macro GDS  | `{macro_name}/outputs/{macro_name}.gds`    |
| Individual Macro LEF  | `{macro_name}/outputs/{macro_name}.lef`    |
| Final Integrated Chip | `soc_integration/outputs/soc_complete.gds` |
| Synthesis Logs        | `{macro_name}/logs/synthesis.log`          |
| P&R Logs              | `{macro_name}/logs/place_route.log`        |
| Timing Reports        | `{macro_name}/outputs/*_timing.rpt`        |
| Area Reports          | `{macro_name}/outputs/*_area.rpt`          |

## Prerequisites

### Software Requirements

- Cadence Genus (synthesis)
- Cadence Innovus (place & route)
- SKY130 PDK installed at `/home/furka/RV32IMZ/pdk/sky130A`

### Environment Setup

```bash
# Source Cadence environment before running scripts
source /path/to/cadence/setup.sh

# Verify environment
which genus
which innovus
```

### SKY130 SRAM Macros

Ensure SRAM macro files are available:

```bash
ls /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_sram_macros/verilog/sky130_sram_2kbyte_1rw1r_32x512_8.v
ls /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_sram_macros/lib/sky130_sram_2kbyte_1rw1r_32x512_8_*
ls /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_2kbyte_1rw1r_32x512_8.gds
```

## Design Methodology

### Proven Working Scripts

All synthesis and P&R scripts are based on the proven working templates:

- **synthesis.tcl:** Simple, reliable flow with single timing library (tt_025C_1v80)
- **place_route.tcl:** Robust MMMC flow with auto-generated constraints, proper CTS fallback, DRC fixing

### Key Features

1. **MMMC (Multi-Mode Multi-Corner):** Automatic generation of timing views for all corners
2. **Clock Tree Synthesis:** Fallback strategies (CCOpt → CTS) for reliable convergence
3. **Power Grid:** Automated power ring and stripe generation
4. **DRC Fixing:** Route-based ECO for clean DRC results
5. **SRAM Black-Boxing:** Proper handling of hard macros in synthesis

### Timing Constraints

- **Target Clock:** 100 MHz (10ns period)
- **Input Delay:** 2ns (20% of clock period)
- **Output Delay:** 2ns
- **Wishbone Bus:** Multi-cycle paths for 2-cycle bus protocol
- **SRAM Access:** Timing constraints based on macro datasheet specs

## Troubleshooting

### If individual macro build fails:

1. Check Cadence environment is sourced
2. Verify file paths in synthesis.tcl scripts
3. Review logs in `{macro_name}/logs/synthesis.log` and `place_route.log`
4. Ensure SKY130 PDK library files are accessible

### If timing violations occur:

- Review critical paths in timing reports
- Increase clock period in SDC files (e.g., 10ns → 12ns)
- Check inter-macro interface timing in top-level integration
- Verify SRAM timing constraints match actual macro specs

### If DRC violations remain:

- Check macro placement in top-level floorplan
- Verify power ring routing clearances
- Review metal layer usage and spacing rules
- Adjust floorplan utilization (default 70%, try 60% if congested)

### If SRAM synthesis fails:

- Verify SRAM macro verilog file path is correct
- Check don't-touch constraints are applied to SRAM instances
- Ensure SRAM lib files are available for all timing corners
- Review SRAM timing constraints in memory_macro.sdc

## Academic Use Notes

This implementation is designed for educational purposes in ASIC design courses:

1. **Learning Hierarchical Design:** Students understand macro-based chip design methodology
2. **Realistic SRAM Integration:** Using actual SRAM macros teaches real-world memory implementation
3. **PDK Familiarity:** Hands-on experience with SKY130 open-source PDK
4. **Tool Flow Mastery:** Complete Genus + Innovus flow from RTL to GDS
5. **Debugging Skills:** Troubleshooting timing, DRC, and synthesis issues

### Submission Checklist

- [ ] All 6 macro GDS files generated successfully
- [ ] Final soc_complete.gds produced without errors
- [ ] Timing reports show positive slack for all corners
- [ ] DRC report shows zero violations
- [ ] Area reports document gate count and utilization
- [ ] Logs contain no critical errors or warnings

## Next Steps

After successful macro build and integration:

1. **Signoff Checks:** Run formal DRC/LVS verification using Magic or Calibre
2. **Power Analysis:** Use Voltus for power estimation
3. **Verification:** Post-layout simulation with annotated delays
4. **Documentation:** Create design report with area, timing, power metrics

## Support and References

- **SKY130 PDK Docs:** https://skywater-pdk.readthedocs.io/
- **Cadence Documentation:** Refer to Genus and Innovus user guides
- **SRAM Macro Specs:** Check sky130_sram_macros datasheet for exact timing

For questions about this implementation, review the backup README.md.backup for historical 2-macro approach context.
