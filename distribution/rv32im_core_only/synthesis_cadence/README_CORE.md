# Cadence Academic Synthesis Flow - Core Only

This directory contains the complete RTL-to-GDSII synthesis flow for the **RV32IM core only** using Cadence academic tools.

## Overview

**Target Design**: RV32IM processor core
**Technology**: Sky130 130nm
**Tools**: Cadence Genus + Innovus
**Output**: Complete GDS layout file

## Quick Start

```bash
# Navigate to synthesis directory
cd synthesis_cadence

# Run complete RTL-to-GDSII flow
./run_cadence_flow.sh
```

## Flow Steps

1. **Synthesis** (Genus): RTL → Netlist
2. **Place & Route** (Innovus): Netlist → Layout
3. **Timing/DRC/LVS**: Verification

## Outputs

- `output/core_final.gds` - GDS layout file
- `output/core_final.def` - DEF placed design
- `reports/` - Timing, area, power reports

## Requirements

- Cadence Genus 21.1+
- Cadence Innovus 21.1+
- Sky130 PDK (included)

## Core-Specific Notes

This flow synthesizes only the processor core (`custom_riscv_core.v`) without SoC peripherals for:
- Integration into larger designs
- Academic ASIC design projects
- Research applications

For full SoC synthesis, use the `rv32imz_full_soc` package instead.