# Cadence Academic Synthesis Guide

This directory contains the complete Cadence academic synthesis flow for the RV32IMZ SoC, designed for university environments with Cadence EDA tools.

## Overview

**Flow**: RTL → Genus (Synthesis) → Innovus (Place & Route) → GDSII
**Target**: Academic projects using Sky130 PDK
**Tools Required**: Cadence Genus, Cadence Innovus

## Quick Start

### Prerequisites

```bash
# Ensure Cadence tools are in PATH
which genus innovus

# Verify Sky130 PDK is available
ls ../../pdk/sky130A/libs.ref/
```

### Complete Flow

```bash
# From synthesis/cadence directory
cd synthesis/cadence
./run_cadence_flow.sh
```

## Files Included

### Synthesis Scripts

- `synthesis.tcl` - Genus synthesis script for complete SoC
- `place_route.tcl` - Innovus place & route script
- `mmmc.tcl` - Multi-mode multi-corner analysis setup
- `run_cadence_flow.sh` - Complete automated flow

### Configuration Files

- `macro_placement.cfg` - SRAM macro placement guidance
- `outputs/` - Generated files directory

### Technology Libraries

- Sky130 standard cell libraries (3 corners)
- SRAM macro models and timing
- LEF files for physical design

## Design Hierarchy

**Target Design**: `soc_simple` (complete SoC)
**Components**:

- RV32IM processor core (~800 cells)
- 32KB dual ROM (bootloader + application)
- 64KB system RAM
- UART, PWM, ADC, GPIO peripherals
- Wishbone bus interconnect

## Expected Results

### Resource Usage

```
Standard Cells: ~30,000-35,000
SRAM Macros: 2-3 instances
Total Area: ~0.5-1.0 mm²
Max Frequency: 50 MHz target
```

### Generated Files

```
outputs/
├── soc_simple_netlist.v      # Gate-level netlist
├── soc_simple_final.gds      # GDSII layout
├── soc_simple_final.def      # Design exchange format
├── timing_report.txt         # Timing analysis
├── area_report.txt           # Area breakdown
└── synthesis.log             # Complete log
```

## Synthesis Process

### 1. Genus Synthesis

```tcl
# Key synthesis settings
set_db syn_global_effort high
set_db syn_opt_effort high
compile -to_map
```

**Optimization Focus**:

- Area optimization for educational use
- Timing closure at 50 MHz
- Power-aware synthesis

### 2. Innovus Place & Route

```tcl
# Floorplanning
setFloorPlanMode -r 0.7 -s 0.7
floorplan

# Placement with SRAM macros
source macro_placement.cfg
place_design

# Clock tree synthesis
ccopt_design

# Route
route_design
```

**Physical Design Flow**:

- Automatic floorplanning with 70% utilization
- SRAM macro placement on periphery
- Clock tree for 50 MHz operation
- Detail routing with DRC cleanup

## Advanced Options

### Timing-Driven Mode

```bash
# Modify synthesis.tcl
set_db syn_global_effort extreme
set_clock_period 15.0  # 66 MHz
```

### Area-Constrained Mode

```bash
# Modify place_route.tcl
setFloorPlanMode -r 0.9 -s 0.9  # Higher density
```

### Multi-Vt Optimization

```bash
# Use multiple threshold voltage libraries
read_libs *_hvt.lib *_lvt.lib *_rvt.lib
```

## Verification Steps

### 1. Synthesis Verification

```bash
# Check synthesis log
grep -E "(ERROR|WARNING)" outputs/synthesis.log

# Verify netlist
grep "module soc_simple" outputs/soc_simple_netlist.v
```

### 2. Timing Closure

```bash
# Check timing report
grep "Setup Slack" outputs/timing_report.txt
grep "Hold Slack" outputs/timing_report.txt
```

### 3. Physical Verification

```bash
# DRC check (built into Innovus flow)
grep "DRC violations" outputs/place_route.log

# LVS verification (post-flow)
calibre -drc -lvs soc_simple_final.gds
```

## Customization

### For Different PDKs

1. Update library paths in `synthesis.tcl`
2. Modify LEF files in `place_route.tcl`
3. Adjust macro placement in `macro_placement.cfg`

### For Different Designs

1. Change `init_top_cell` to your top module
2. Update RTL file list in `synthesis.tcl`
3. Modify timing constraints for your clock

### For Advanced Students

1. Add custom timing constraints
2. Implement multi-corner optimization
3. Add power analysis flows

## Troubleshooting

### Common Issues

**Synthesis Fails**:

```bash
# Check library paths
check_library

# Verify RTL syntax
read_hdl -v2001 your_file.v
```

**Timing Violation**:

```bash
# Relax clock period
set_clock_period 25.0  # 40 MHz

# Enable higher effort
set_db syn_global_effort extreme
```

**Placement Errors**:

```bash
# Check SRAM macro availability
check_macro sky130_sram_2kbyte_1rw1r_32x512_8

# Adjust macro placement
# Edit macro_placement.cfg coordinates
```

### Debug Commands

```tcl
# In Genus
report_timing -unconstrained
report_area -hierarchy

# In Innovus
check_design -all
report_timing -late
report_power
```

## Academic Integration

### Course Projects

- **Digital VLSI**: Complete RTL-to-GDSII flow
- **Computer Architecture**: Processor implementation
- **ASIC Design**: Physical design concepts

### Learning Objectives

- Understand synthesis optimization
- Learn physical design constraints
- Experience industry-standard tools
- Generate manufacturable layout

### Assessment Ideas

- Timing closure verification
- Area optimization challenges
- Power analysis projects
- Layout visualization exercises

## Next Steps

1. **Run the flow**: `./run_cadence_flow.sh`
2. **Analyze results**: Review timing and area reports
3. **View layout**: Open GDSII in layout viewer
4. **Iterate**: Optimize for timing/area/power
5. **Verify**: Run post-layout simulation

The complete flow typically takes 1-3 hours depending on design size and optimization settings.
