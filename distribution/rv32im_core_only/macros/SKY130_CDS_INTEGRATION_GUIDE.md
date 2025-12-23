# Integrating RV32IMZ with sky130_cds Build System

This guide shows how to use the **sky130_cds** repository infrastructure (https://github.com/stineje/sky130_cds) with your RV32IMZ macros.

## Why Use sky130_cds?

The sky130_cds repository provides a **complete, ready-made build system** for Cadence tools:

✅ **Automated Makefiles** - Build with simple `make` commands
✅ **Standardized scripts** - Proven synthesis and PNR flows
✅ **OSU standard cells** - Free, open-source cell libraries for sky130
✅ **DRC/LVS setup** - Verification flows already configured
✅ **University-friendly** - Designed for academic use at Oklahoma State University

---

## Repository Comparison

### sky130_cds Structure
```
sky130_cds/
├── synth/                    # Synthesis directory
│   ├── Makefile             # Build automation
│   ├── genus_script.tcl     # Genus configuration
│   ├── hdl/                 # Your RTL goes here
│   ├── constraints_top.sdc  # Timing constraints
│   └── reports/             # Output reports
│
├── pnr/                      # Place & Route directory
│   ├── Makefile             # PNR automation
│   ├── setup.tcl            # Design configuration
│   ├── innovus_config.tcl   # Flow configuration
│   ├── commands.tcl         # Power network commands
│   ├── SCRIPTS/INNOVUS/     # Flow automation scripts
│   │   ├── procs.tcl        # Procedures
│   │   ├── run_all.tcl      # Complete flow
│   │   ├── run_single.tcl   # Single stage
│   │   └── run_lec.tcl      # Equivalence check
│   ├── DBS/                 # Design databases
│   ├── RPT/                 # Reports
│   └── LOG/                 # Logs
│
└── sky130_osu_sc_t18/       # OSU standard cell library (submodule)
    ├── lib/                 # Liberty timing files
    ├── lef/                 # Physical layouts
    ├── verilog/             # Cell models
    └── gds/                 # GDSII layouts
```

### Your Current RV32IMZ Structure
```
RV32IMZ/distribution/rv32im_core_only/macros/
├── core_macro/
│   ├── scripts/
│   │   ├── core_synthesis.tcl
│   │   └── core_place_route.tcl
│   ├── rtl/
│   └── constraints/
├── mdu_macro/
├── memory_macro/
└── ... (other macros)
```

---

## Integration Strategy

You have **two approaches**:

### **Option A: Adapt RV32IMZ to sky130_cds (Recommended for University)**
Use the sky130_cds infrastructure, modify it for your RV32IMZ macros.

**Pros:**
- Leverage proven Makefiles and automation
- Consistent with other university projects
- Less script maintenance
- Ready-made DRC/LVS flows

**Cons:**
- Need to adapt your RTL structure
- Uses OSU cells instead of sky130_fd_sc_hd cells

### **Option B: Adopt sky130_cds Patterns into RV32IMZ**
Keep your current structure, but add Makefile automation inspired by sky130_cds.

**Pros:**
- Keep existing scripts and structure
- Continue using sky130_fd_sc_hd cells
- Minimal disruption

**Cons:**
- More manual setup
- You maintain all scripts yourself

---

## OPTION A: Using sky130_cds Infrastructure (Step-by-Step)

### Step 1: Clone and Setup sky130_cds

```bash
# Clone the repository
git clone https://github.com/stineje/sky130_cds.git
cd sky130_cds

# Initialize submodules (gets OSU standard cell libraries)
git submodule update --init --recursive

# This downloads:
# - sky130_osu_sc_t18 (1.8V, typical threshold)
# - sky130_osu_sc_t15 (1.5V, low voltage)
# - sky130_osu_sc_t12 (1.2V, ultra-low voltage)
```

### Step 2: Understand the OSU Standard Cells

The sky130_cds repo uses **Oklahoma State University (OSU) standard cells**, NOT the standard sky130_fd_sc_hd cells.

**Differences:**
| Feature | sky130_fd_sc_hd | sky130_osu_sc_t18 |
|---------|-----------------|-------------------|
| Voltage | 1.8V | 1.8V |
| Cell height | 2.72 µm | Variable |
| Availability | SkyWater official | OSU open-source |
| Cells | ~460 cells | ~100 cells |
| Use case | Production | Academic/Research |

**You can use either library**, but if using sky130_cds infrastructure, OSU cells are easier.

### Step 3: Prepare Your RTL for sky130_cds

#### 3a. Copy Your RTL to synth/hdl/

```bash
# Create a directory for your macro
mkdir -p sky130_cds/synth/hdl/core_macro

# Copy your core macro RTL
cp RV32IMZ/distribution/rv32im_core_only/macros/core_macro/rtl/*.v \
   sky130_cds/synth/hdl/core_macro/
```

#### 3b. Create synthesis script for your macro

Edit `sky130_cds/synth/genus_script.tcl`:

```tcl
#===============================================================================
# Genus Synthesis Script for Core Macro
# Based on sky130_cds template, adapted for RV32IMZ
#===============================================================================

# Set design name
set DESIGN "core_macro"

# Set paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "hdl/core_macro"

# Library setup
set_db init_lib_search_path "$LIB_PATH/lib $LIB_PATH/lef"
set_db init_hdl_search_path $HDL_PATH

# Read libraries
read_libs "$LIB_PATH/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"

# Read LEF files (for physical info)
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T.lef"

# Read RTL files
read_hdl -v2001 {
    core_macro.v
}

# Elaborate design
elaborate $DESIGN

# Read timing constraints
if {[file exists "constraints/core_macro.sdc"]} {
    read_sdc constraints/core_macro.sdc
} else {
    # Basic constraints if no SDC
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

# Calculate clock uncertainty (10% of period)
set clk_uncertainty [expr 0.1 * 10.0]
set_clock_uncertainty $clk_uncertainty [get_clocks clk]

# Synthesis - set effort levels
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

# Run synthesis
syn_generic
syn_map
syn_opt

# Write outputs
write_hdl > "${DESIGN}.vh"
write_sdc > "${DESIGN}.sdc"
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge > "${DESIGN}.sdf"

# Generate reports
report_timing > reports/timing.rpt
report_area > reports/area.rpt
report_qor > reports/qor.rpt
report_clock > reports/clock.rpt
report_power > reports/power.rpt
report_gates > reports/gates.rpt

puts "Synthesis complete for $DESIGN"
exit
```

#### 3c. Create Makefile for synthesis

Edit `sky130_cds/synth/Makefile`:

```makefile
# Makefile for RV32IMZ Core Macro Synthesis
DESIGN = core_macro

.PHONY: synth clean reports

synth:
	@echo "Running synthesis for $(DESIGN)..."
	genus -f genus_script.tcl | tee synth.log
	@echo "Synthesis complete. Check synth.log for details."

reports:
	@echo "=== Area Report ==="
	@cat reports/area.rpt | head -20
	@echo ""
	@echo "=== Timing Report ==="
	@cat reports/timing.rpt | head -30

clean:
	rm -rf *.vh *.sdc *.sdf *.log* .rs_* fv/ genus.* reports/*

help:
	@echo "Available targets:"
	@echo "  make synth   - Run Genus synthesis"
	@echo "  make reports - Display summary reports"
	@echo "  make clean   - Clean build artifacts"
```

#### 3d. Create constraints

Create `sky130_cds/synth/constraints/core_macro.sdc`:

```tcl
# Timing constraints for Core Macro

# Clock definition (100 MHz = 10ns period)
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]

# Input delays (assume 20% of clock period)
set input_delay_value 2.0
set_input_delay $input_delay_value -clock clk [all_inputs]
remove_input_delay [get_ports clk]

# Output delays (assume 20% of clock period)
set output_delay_value 2.0
set_output_delay $output_delay_value -clock clk [all_outputs]

# Load capacitance (typical for sky130)
set_load 0.05 [all_outputs]

# Drive strength (typical buffer)
set_driving_cell -lib_cell sky130_osu_sc_18T_ms__buf_1 [all_inputs]

# Reset is async, no timing requirements
set_false_path -from [get_ports rst_n]
```

### Step 4: Run Synthesis with Makefile

```bash
cd sky130_cds/synth

# Run synthesis
make synth

# View reports
make reports

# Check for errors
grep -i "error" synth.log
grep -i "warning" synth.log
```

**Outputs:**
- `core_macro.vh` - Gate-level netlist
- `core_macro.sdc` - Timing constraints for PNR
- `reports/` - Area, timing, power reports

### Step 5: Setup Place & Route

#### 5a. Configure setup.tcl

Edit `sky130_cds/pnr/setup.tcl`:

```tcl
#===============================================================================
# Setup for Core Macro Place & Route
#===============================================================================

set DESIGN "core_macro"
set TECH "sky130"
set CELL_LIB "sky130_osu_sc_18T"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set SYNTH_PATH "../synth"

#===============================================================================
# Library Sets
#===============================================================================

create_library_set -name libs_tt \
    -timing [list "${LIB_PATH}/lib/${CELL_LIB}_ms_TT_1P8_25C.ccs.lib"]

#===============================================================================
# LEF Files
#===============================================================================

read_physical -lef [list \
    "${LIB_PATH}/lef/${CELL_LIB}_tech.lef" \
    "${LIB_PATH}/lef/${CELL_LIB}.lef" \
]

#===============================================================================
# RC Corners
#===============================================================================

create_rc_corner -name rc_typ \
    -temperature 25 \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_res 1.0 \
    -post_route_cap 1.0

# If you have QRC tech file:
# -qrc_tech qrcTechFile

#===============================================================================
# Delay Corners
#===============================================================================

create_delay_corner -name corner_tt \
    -library_set libs_tt \
    -rc_corner rc_typ

#===============================================================================
# Constraint Modes
#===============================================================================

create_constraint_mode -name setup_func_mode \
    -sdc_files [list "${SYNTH_PATH}/${DESIGN}.sdc"]

#===============================================================================
# Analysis Views
#===============================================================================

create_analysis_view -name setup_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

create_analysis_view -name hold_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

set_analysis_view -setup {setup_func} -hold {hold_func}

#===============================================================================
# Power/Ground Nets
#===============================================================================

set_power_net VDD
set_ground_net VSS

#===============================================================================
# Design Data
#===============================================================================

# Read netlist from synthesis
read_netlist "${SYNTH_PATH}/${DESIGN}.vh"

# Initialize design
init_design -setup {setup_func} -hold {hold_func}
```

#### 5b. Configure innovus_config.tcl

This file controls the PNR flow. Key settings:

```tcl
# Design name
set DESIGN "core_macro"

# Flow steps
set FLOW_STEPS {"init" "place" "cts" "postcts_hold" "route" "postroute" "signoff"}

# Directories
set DBS_DIR "DBS"
set RPT_DIR "RPT"
set LOG_DIR "LOG"

# Technology settings
set MAX_ROUTING_LAYER 5   # sky130 has 5 metal layers
set FILLER_CELLS "sky130_osu_sc_18T_ms__fill*"
set TIE_CELLS {sky130_osu_sc_18T_ms__tiehi sky130_osu_sc_18T_ms__tielo}

# CTS cells (clock tree synthesis)
set CTS_INV_CELLS {sky130_osu_sc_18T_ms__inv_1 sky130_osu_sc_18T_ms__inv_2}

# Enable features
set ENABLE_IO_PLACE true
set ENABLE_PAC_MODE "all"
```

#### 5c. Update commands.tcl for power network

The `commands.tcl` should already be good, but verify:

```tcl
# Global power connections
globalNetConnect VSS -type pgpin -pin gnd -inst *
globalNetConnect VDD -type pgpin -pin vdd -inst *

# Power rings (adjust dimensions based on your floorplan)
addRing -nets {VDD VSS} \
        -type core_rings \
        -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 2.0 \
        -spacing 1.0 \
        -offset 1.0

# Power stripes
addStripe -nets {VDD VSS} \
          -layer met2 \
          -direction vertical \
          -width 1.0 \
          -spacing 5.0 \
          -number_of_sets 10

# Special route to connect power
sroute -connect {blockPin padPin padRing corePin stripe} \
       -layerChangeRange {met1 met3}
```

### Step 6: Run Place & Route with Makefile

The sky130_cds Makefile supports stage-by-stage execution:

```bash
cd sky130_cds/pnr

# Initialize design
make init

# Place cells
make place

# Clock tree synthesis
make cts

# Post-CTS hold fixing
make postcts

# Route
make route

# Post-route optimization
make postroute

# Final signoff
make signoff
```

**Or run everything at once:**
```bash
make all
```

**View results:**
```bash
# Check logs
tail LOG/place.log
tail LOG/route.log

# Check reports
cat RPT/timing.rpt
cat RPT/area.rpt

# Restore design in GUI
innovus
# In Innovus:
restoreDesign DBS/signoff.enc.dat core_macro
```

### Step 7: Generate GDSII

After signoff, stream out GDS:

```bash
cd sky130_cds/pnr

# In Innovus (or add to tapeout.tcl)
innovus
```

In Innovus console:
```tcl
# Restore final design
restoreDesign DBS/signoff.enc.dat core_macro

# Stream out GDS
streamOut core_macro.gds \
    -mapFile streamOut.map \
    -stripes 1 \
    -units 1000 \
    -mode ALL

# Generate LEF for hierarchical integration
write_lef_abstract core_macro.lef

exit
```

---

## OPTION B: Adding sky130_cds Automation to Your RV32IMZ

If you want to **keep your existing structure** but add Makefile automation:

### Step 1: Create Makefile for Each Macro

Example: `RV32IMZ/distribution/rv32im_core_only/macros/core_macro/Makefile`

```makefile
# Makefile for Core Macro

MACRO = core_macro
SCRIPTS = scripts
RTL = rtl
OUTPUTS = outputs
REPORTS = reports
LOGS = logs

# PDK setup
export PDK_ROOT ?= $(shell cd ../../../../pdk && pwd)

.PHONY: all synth pnr clean reports help

all: synth pnr

synth:
	@echo "=== Synthesizing $(MACRO) ==="
	@mkdir -p $(LOGS) $(REPORTS) $(OUTPUTS)
	genus -batch -files $(SCRIPTS)/$(MACRO)_synthesis.tcl \
	      -log $(LOGS)/synthesis.log
	@echo "Synthesis complete. Check $(LOGS)/synthesis.log"

pnr:
	@echo "=== Place & Route for $(MACRO) ==="
	@mkdir -p $(LOGS) $(REPORTS) $(OUTPUTS)
	innovus -batch -files $(SCRIPTS)/$(MACRO)_place_route.tcl \
	        -log $(LOGS)/pnr.log
	@echo "PNR complete. Check $(LOGS)/pnr.log"

reports:
	@echo "=== Area Report ==="
	@cat $(REPORTS)/area.rpt | head -20
	@echo ""
	@echo "=== Timing Report ==="
	@cat $(REPORTS)/timing.rpt | head -30

clean:
	rm -rf $(OUTPUTS)/* $(REPORTS)/* $(LOGS)/* db/ *.log* .rs_*

help:
	@echo "Makefile for $(MACRO)"
	@echo "Targets:"
	@echo "  make synth   - Run synthesis"
	@echo "  make pnr     - Run place & route"
	@echo "  make all     - Run both synth and pnr"
	@echo "  make reports - Display summary"
	@echo "  make clean   - Remove build artifacts"
```

### Step 2: Create Top-Level Makefile

`RV32IMZ/distribution/rv32im_core_only/macros/Makefile`

```makefile
# Top-level Makefile for all RV32IMZ Macros

# List of all macros
MACROS = core_macro mdu_macro memory_macro communication_macro \
         protection_macro adc_subsystem_macro pwm_accelerator_macro

# Integrated macros (depend on leaf macros)
INTEGRATED_MACROS = rv32im_integrated_macro

# Top-level integration
SOC_MACRO = soc_integration

.PHONY: all clean $(MACROS) $(INTEGRATED_MACROS) $(SOC_MACRO)

all: leaf integrated soc

# Build all leaf macros
leaf: $(MACROS)

# Build integrated macros
integrated: leaf $(INTEGRATED_MACROS)

# Build top-level SoC
soc: integrated $(SOC_MACRO)

# Individual macro targets
$(MACROS):
	@echo "Building $@..."
	$(MAKE) -C $@ all

$(INTEGRATED_MACROS): $(MACROS)
	@echo "Building $@..."
	$(MAKE) -C $@ all

$(SOC_MACRO): $(INTEGRATED_MACROS)
	@echo "Building $@..."
	$(MAKE) -C $@ all

clean:
	@for macro in $(MACROS) $(INTEGRATED_MACROS) $(SOC_MACRO); do \
		echo "Cleaning $$macro..."; \
		$(MAKE) -C $$macro clean; \
	done

help:
	@echo "RV32IMZ Macro Build System"
	@echo "Targets:"
	@echo "  make all        - Build everything"
	@echo "  make leaf       - Build leaf macros only"
	@echo "  make integrated - Build integrated macros"
	@echo "  make soc        - Build top-level SoC"
	@echo "  make <macro>    - Build specific macro"
	@echo "  make clean      - Clean all builds"
```

### Step 3: Usage

```bash
cd RV32IMZ/distribution/rv32im_core_only/macros

# Build everything
make all

# Build only core macro
make core_macro

# Build all leaf macros
make leaf

# Clean everything
make clean
```

---

## Key Differences: OSU Cells vs. sky130_fd_sc_hd

If you want to **switch from sky130_fd_sc_hd to OSU cells**:

### Update Library Paths

**Before (sky130_fd_sc_hd):**
```tcl
set TECH_LIB_PATH "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib"
read_libs "${TECH_LIB_PATH}/sky130_fd_sc_hd__tt_025C_1v80.lib"
```

**After (OSU cells):**
```tcl
set TECH_LIB_PATH "../sky130_osu_sc_t18"
read_libs "${TECH_LIB_PATH}/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"
```

### Update LEF Files

**Before:**
```tcl
read_physical -lef "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.tlef"
read_physical -lef "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
```

**After:**
```tcl
read_physical -lef "${LIB_PATH}/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "${LIB_PATH}/lef/sky130_osu_sc_18T.lef"
```

### Update Cell Names

Some commands reference specific cells:

**sky130_fd_sc_hd:**
```tcl
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]
addFiller -cell {sky130_fd_sc_hd__fill_1 sky130_fd_sc_hd__fill_2}
```

**OSU cells:**
```tcl
set_driving_cell -lib_cell sky130_osu_sc_18T_ms__buf_1 [all_inputs]
addFiller -cell {sky130_osu_sc_18T_ms__fill_1 sky130_osu_sc_18T_ms__fill_2}
```

---

## Recommended Workflow for University

1. **Use sky130_cds for simple macros** (core, MDU, ALU, etc.)
   - Leverage the Makefile automation
   - Easier for debugging and iteration

2. **Use hierarchical integration** for complex macros
   - Build leaf macros with sky130_cds
   - Integrate using your existing scripts

3. **Keep both approaches**
   - sky130_cds for quick experiments
   - Your custom scripts for production

---

## Common Issues and Solutions

### Issue 1: OSU Cell Library Not Found

**Problem:**
```
Error: Cannot find library sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib
```

**Solution:**
```bash
# Initialize submodules
cd sky130_cds
git submodule update --init --recursive

# Verify library exists
ls sky130_osu_sc_t18/lib/
```

### Issue 2: Makefile Not Running

**Problem:**
```
make: *** No rule to make target 'synth'
```

**Solution:**
```bash
# Ensure you're in the right directory
cd sky130_cds/synth

# Check Makefile exists
ls -la Makefile

# Run with explicit target
make -f Makefile synth
```

### Issue 3: Mixing Libraries

**Problem:** Some cells from sky130_fd_sc_hd, some from OSU

**Solution:** Pick one library and stick with it throughout the flow:

```tcl
# At the start of EVERY script, set library path
set LIB_TYPE "osu"  # or "sky130_fd"

if {$LIB_TYPE == "osu"} {
    set LIB_PATH "../sky130_osu_sc_t18"
    set LIB_FILE "sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"
} else {
    set LIB_PATH "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd"
    set LIB_FILE "sky130_fd_sc_hd__tt_025C_1v80.lib"
}
```

---

## Summary

### sky130_cds Provides:
✅ Makefile automation
✅ Ready-to-use synthesis/PNR scripts
✅ OSU standard cell libraries
✅ Proven university workflow

### Your RV32IMZ Provides:
✅ Complete processor design
✅ Hierarchical macro structure
✅ Pin placement automation
✅ Integration scripts

### Best Approach:
**Combine both!**
- Use sky130_cds Makefiles for automation
- Keep your hierarchical macro structure
- Choose library based on your needs (OSU for simplicity, sky130_fd for production)

---

## Next Steps

1. **Clone sky130_cds** and explore the example (mult_seq)
2. **Run the example** to verify your Cadence tools work
3. **Adapt one macro** (start with core_macro) to the sky130_cds flow
4. **Create Makefiles** for your remaining macros
5. **Document** what works for your university setup

Good luck with your project!
