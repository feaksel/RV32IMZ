# RV32IM SoC - Complete ASIC Build Flow

## Quick Start

```bash
./build_all_macros.sh
```

Builds everything in correct order with full reports and GDS outputs.

## What You Get

### Individual Peripheral Macros

- `memory_macro.gds` - 32KB ROM + 64KB RAM (with SKY130 SRAM macros)
- `communication_macro.gds` - UART + SPI + GPIO
- `protection_macro.gds` - Thermal monitoring + Watchdog
- `adc_subsystem_macro.gds` - Sigma-delta ADC + filters
- `pwm_accelerator_macro.gds` - 4-channel PWM for motor control

### CPU Macros (Separate)

- `core_macro.gds` - RV32I 5-stage pipeline (~8-9K cells)
- `mdu_macro.gds` - Multiply/Divide unit (~3-4K cells)

### Integrated RV32IM IP

- `rv32im_integrated_macro.gds` - Core + MDU combined (~11-13K cells)
- Hierarchical build using pre-built netlists/LEF
- **Use this for drop-in IP reuse**

### Complete SoC Package

- `rv32im_soc_complete.gds` - Full chip with all peripherals (~31K cells + SRAMs)
- Integrates rv32im_integrated_macro + all peripherals
- **Final tapeout-ready design**

## Build Order

Automatically handled by `build_all_macros.sh`:

1. Build 5 peripheral macros (parallel-safe)
2. Build core_macro and mdu_macro separately
3. Build rv32im_integrated_macro (hierarchical, uses core+MDU)
4. Build final SoC package (uses integrated + peripherals)

## Directory Structure

```
macros/
├── build_all_macros.sh          ← ONE script to build everything
├── core_macro/                  ← RV32I pipeline
│   ├── rtl/
│   ├── scripts/
│   └── outputs/                 → core_macro.gds, .lef, reports
├── mdu_macro/                   ← Multiply/Divide unit
│   ├── rtl/
│   ├── scripts/
│   └── outputs/                 → mdu_macro.gds, .lef, reports
├── rv32im_integrated_macro/     ← Core+MDU combined
│   ├── rtl/                     (only wrapper - uses pre-built macros)
│   ├── scripts/
│   └── outputs/                 → rv32im_integrated_macro.gds, reports
├── memory_macro/
├── communication_macro/
├── protection_macro/
├── adc_subsystem_macro/
├── pwm_accelerator_macro/
└── soc_integration/             ← Final SoC
    ├── scripts/
    └── outputs/                 → rv32im_soc_complete.gds, reports
```

## Build Individual Macros

```bash
# Build single peripheral
cd memory_macro
genus -batch -files scripts/memory_synthesis.tcl
innovus -batch -files scripts/memory_place_route.tcl

# Build CPU components
cd core_macro && ./run_core_macro.sh
cd mdu_macro && ./run_mdu_macro.sh

# Build integrated (requires core+MDU built first)
cd rv32im_integrated_macro && ./build_integrated_macro.sh
```

## Output Files

Each macro produces:

- `outputs/*.gds` - GDSII layout file
- `outputs/*.lef` - LEF abstract view (for hierarchical integration)
- `outputs/*_syn.v` - Synthesized netlist
- `outputs/*.sdc` - Timing constraints
- `outputs/*.rpt` - Area/timing/power reports
- `logs/*.log` - Build logs

## Architecture Notes

**Core + MDU Separation**: Core has external MDU interface. MDU is separate macro. They are combined hierarchically in rv32im_integrated_macro.

**Memory Implementation**: Uses real SKY130 SRAM macros (sky130_sram_2kbyte_1rw1r_32x512_8):

- ROM: 16 banks × 2KB = 32KB
- RAM: 32 banks × 2KB = 64KB

**Hierarchical Build**: rv32im_integrated_macro and soc_integration read pre-built netlists/LEF as black boxes, only synthesize wrapper logic.

## Tool Requirements

- Cadence Genus 21.18+ (synthesis)
- Cadence Innovus 21.1+ (place & route)
- SKY130 PDK (use `../setup_pdk_from_archive.sh`)

## Build Time

- Individual macro: 10-30 minutes each
- Complete flow: 3-4 hours total
- SoC integration: 1-2 hours

## Verification

After build, check:

```bash
# Verify all GDS files exist
ls -lh */outputs/*.gds

# Check synthesis reports
grep "Total cell area" */outputs/*_area.rpt

# Check timing
grep "slack" */outputs/*_timing.rpt
```

All outputs should have positive slack and reasonable area.

---

**That's it.** Run `./build_all_macros.sh` and get all macros + integrated IP + complete SoC.
