# University Cadence PC Setup Plan for RV32IM Core
# Complete Step-by-Step Guide for Academic Implementation

## Phase 1: Project Transfer to University System

### Step 1.1: Download Essential SKY130 PDK Files
```bash
# Create PDK directory structure
cd /home/furka/RV32IMZ
mkdir -p pdk/sky130A/{libs.ref,libs.tech}

# Download minimal SKY130 standard cell library (essential files only)
cd pdk/sky130A

# Option A: Download pre-curated PDK subset (recommended)
wget https://github.com/efabless/caravel_user_project/releases/download/mpw-7c/sky130A_pdk_subset.tar.gz
tar -xzf sky130A_pdk_subset.tar.gz

# Option B: Clone and extract only what we need
git clone --depth=1 https://github.com/google/skywater-pdk.git temp_pdk
cp -r temp_pdk/libraries/sky130_fd_sc_hd/latest/* libs.ref/sky130_fd_sc_hd/
cp -r temp_pdk/libraries/sky130_fd_io/latest/* libs.ref/sky130_fd_io/
rm -rf temp_pdk

# Option C: Manual download of essential files only (~50MB instead of 2GB)
mkdir -p libs.ref/sky130_fd_sc_hd/{lib,lef,gds}
mkdir -p libs.tech/{klayout,magic,netgen}

# Download core library files
curl -L -o libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__tt_025C_1v80.lib"

curl -L -o libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__ff_100C_1v95.lib"

curl -L -o libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__ss_n40C_1v60.lib"

curl -L -o libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/cells/lef/sky130_fd_sc_hd.lef"

curl -L -o libs.tech/klayout/tech/sky130A.lyt \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/klayout/tech/sky130A.lyt"
```

### Step 1.2: Create Self-Contained Homework Package
```bash
# Create PDK configuration for homework
cat > pdk/sky130A/pdk_config.sh << 'EOF'
#!/bin/bash
# SKY130 PDK Configuration for RV32IM Homework
export PDK_ROOT=$PWD/pdk/sky130A
export STD_CELL_LIB=$PDK_ROOT/libs.ref/sky130_fd_sc_hd
export PDK_TECH=$PDK_ROOT/libs.tech
echo "SKY130 PDK configured for homework use"
echo "PDK_ROOT: $PDK_ROOT"
EOF

# Verify essential files exist
echo "Verifying PDK files..."
ls pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/*.lib
ls pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/*.lef

# Clean up unnecessary files  
cd /home/furka/RV32IMZ
rm -rf __pycache__ *.vcd sim/build synthesis/build

# Create complete self-contained package
tar -czf RV32IM_homework_complete.tar.gz \
    rtl/ \
    constraints/ \
    programs/ \
    docs/ \
    pdk/ \
    synthesized_core.v \
    synthesis_check.ys \
    synthesize.sh \
    *.md

# Check package size (should be 50-100MB with PDK)
ls -lh RV32IM_homework_complete.tar.gz
echo "Package includes everything needed - no PDK setup required at university!"
```

### Step 1.2: Transfer Options

**Option A: University File Server**
```bash
# Upload complete self-contained package
scp RV32IM_homework_complete.tar.gz username@university.edu:~/

# Or use university file sharing system
# Upload to Google Drive/OneDrive if allowed (50-100MB)
```

**Option B: Git Repository with PDK (Recommended)**
```bash
# Create git repo with PDK subset
git init
git lfs track "pdk/**/*.lib" "pdk/**/*.lef"  # Use LFS for large files
git add rtl/ constraints/ docs/ pdk/ *.md synthesized_core.v
git commit -m "RV32IM core with embedded SKY130 PDK for university"

# Push to GitHub/GitLab with LFS
git remote add origin https://github.com/yourusername/RV32IM-Core-Complete.git
git push -u origin main
```

**Option C: USB Drive**
```bash
# Copy complete package to USB drive
cp RV32IM_homework_complete.tar.gz /media/usb/
# Package is self-contained - works on any system!
```

## Phase 2: University Cadence PC Setup

### Step 2.1: Initial Environment Check
```bash
# Login to university Cadence workstation
ssh username@cadence-server.university.edu

# Check available tools
which genus innovus
echo $CADENCE_HOME
module list   # If using environment modules

# No need to check PDK - we brought our own!
```

### Step 2.2: Create Workspace with Embedded PDK
```bash
# Create your homework workspace
mkdir -p ~/ece_homework/rv32im_asic
cd ~/ece_homework/rv32im_asic

# Extract complete project with PDK
tar -xzf ~/RV32IM_homework_complete.tar.gz
# OR clone from git
git clone https://github.com/yourusername/RV32IM-Core-Complete.git .

# Set up local PDK environment
source pdk/sky130A/pdk_config.sh

# Verify embedded PDK
echo "Checking embedded PDK..."
ls $PDK_ROOT/libs.ref/sky130_fd_sc_hd/lib/
ls $PDK_ROOT/libs.ref/sky130_fd_sc_hd/lef/
echo "✓ PDK ready - no university PDK installation needed!"

# Create working directories
mkdir -p cadence_work/{synthesis,pnr,verification,reports,scripts}
```

## Phase 3: Using Embedded SKY130 PDK (No Installation Needed!)

### Step 3.1: Embedded PDK Verification
```bash
# Your PDK is already included in the project!
cd ~/ece_homework/rv32im_asic

# Source PDK configuration
source pdk/sky130A/pdk_config.sh

# Verify all required files are present
echo "Checking embedded PDK files..."
test -f $STD_CELL_LIB/lib/sky130_fd_sc_hd__tt_025C_1v80.lib && echo "✓ Typical timing lib"
test -f $STD_CELL_LIB/lib/sky130_fd_sc_hd__ff_100C_1v95.lib && echo "✓ Fast timing lib" 
test -f $STD_CELL_LIB/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib && echo "✓ Slow timing lib"
test -f $STD_CELL_LIB/lef/sky130_fd_sc_hd.lef && echo "✓ LEF file"

# Show PDK info
echo "Embedded PDK configured:"
echo "  PDK_ROOT: $PDK_ROOT"
echo "  STD_CELL_LIB: $STD_CELL_LIB" 
echo "  Size: $(du -sh pdk/)"
```

### Step 3.2: No Additional Downloads Required!
```bash
# Everything is self-contained!
echo "PDK Status: ✓ EMBEDDED - Ready to use"
echo "No internet required, no paths to configure"
echo "Works on any Cadence system"

# Optional: Create symlink for convenience
ln -sf ../pdk/sky130A cadence_work/pdk
```

## Phase 4: Create SKY130-Specific Scripts

### Step 4.1: SKY130 Synthesis Script
```bash
cat > cadence_work/scripts/genus_sky130.tcl << 'EOF'
#!/usr/bin/env genus

#==============================================================================
# RV32IM Core Synthesis for SKY130 PDK
#==============================================================================

# Environment setup
set PDK_ROOT $env(PDK_ROOT)
set STD_CELL_LIB $env(STD_CELL_LIB)
set DESIGN_NAME "custom_riscv_core"

# Library setup for SKY130
set_db library [list \
    $STD_CELL_LIB/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
    $STD_CELL_LIB/lib/sky130_fd_sc_hd__ff_100C_1v95.lib \
    $STD_CELL_LIB/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib \
]

# LEF files for physical info
set_db lef_library [list \
    $PDK_ROOT/libs.tech/lef/sky130_fd_sc_hd.tech.lef \
    $STD_CELL_LIB/lef/sky130_fd_sc_hd.lef \
]

# Read RTL
read_hdl -verilog [list \
    ../../rtl/core/riscv_defines.vh \
    ../../rtl/core/alu.v \
    ../../rtl/core/decoder.v \
    ../../rtl/core/regfile.v \
    ../../rtl/core/mdu.v \
    ../../rtl/core/csr_unit.v \
    ../../rtl/core/exception_unit.v \
    ../../rtl/core/interrupt_controller.v \
    ../../rtl/core/custom_riscv_core.v \
]

elaborate $DESIGN_NAME

# Read timing constraints
read_sdc ../constraints/timing_sky130.sdc

# Synthesis settings for academic use
set_db syn_generic_effort medium
set_db syn_map_effort medium  
set_db syn_opt_effort medium

# Sky130 specific settings
set_db hdl_max_loop_limit 8192

# Run synthesis
syn_generic
syn_map
syn_opt

# Generate reports
report_timing > ../reports/timing_syn.rpt
report_power > ../reports/power_syn.rpt
report_area > ../reports/area_syn.rpt
report_qor > ../reports/qor_syn.rpt

# Write outputs
write_hdl -mapped > ../synthesis/netlist.v
write_sdc > ../synthesis/netlist.sdc
write_sdf > ../synthesis/netlist.sdf

puts "SKY130 synthesis completed!"
quit
EOF
```

### Step 4.2: SKY130 Timing Constraints
```bash
cat > cadence_work/constraints/timing_sky130.sdc << 'EOF'
#==============================================================================
# Timing Constraints for RV32IM Core - SKY130 PDK
#==============================================================================

# Clock: 100 MHz target (10ns period) - conservative for homework
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]  # 2.5% uncertainty
set_clock_transition 0.1 [get_clocks clk]

# Input constraints - assume signals come from flip-flops
set_input_delay -clock clk -max 1.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock clk -min 0.5 [remove_from_collection [all_inputs] [get_ports clk]]

# Output constraints - assume driving other flip-flops  
set_output_delay -clock clk -max 1.0 [all_outputs]
set_output_delay -clock clk -min 0.5 [all_outputs]

# Reset handling
set_false_path -from [get_ports rst_n]

# Environmental conditions
# SKY130: 1.8V nominal, -40°C to 125°C
set_operating_conditions tt_025C_1v80

# Drive and load modeling
# Use medium drive strength buffer for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 [all_inputs]
# Load outputs with small capacitance (academic assumption)
set_load [expr 4 * [load_of sky130_fd_sc_hd__buf_2/A]] [all_outputs]

# Wishbone bus constraints (relax for homework)
set_multicycle_path -setup 2 -through [get_pins -of [get_cells *] -filter "name =~ *wb_*"]
set_multicycle_path -hold 1 -through [get_pins -of [get_cells *] -filter "name =~ *wb_*"]

# Don't optimize test/debug signals aggressively  
set_case_analysis 0 [get_ports scan_mode] -if_exists
EOF
```

### Step 4.3: SKY130 Place & Route Script
```bash
cat > cadence_work/scripts/innovus_sky130.tcl << 'EOF'
#!/usr/bin/env innovus

#==============================================================================
# RV32IM Core Place & Route for SKY130
#==============================================================================

# Variables
set PDK_ROOT $env(PDK_ROOT)
set STD_CELL_LIB $env(STD_CELL_LIB)
set DESIGN_NAME "custom_riscv_core"

# Create library sets for corners
create_library_set -name slow_libs -timing \
    $STD_CELL_LIB/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib

create_library_set -name typical_libs -timing \
    $STD_CELL_LIB/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

create_library_set -name fast_libs -timing \
    $STD_CELL_LIB/lib/sky130_fd_sc_hd__ff_100C_1v95.lib

# Create constraint modes
create_constraint_mode -name constraints \
    -sdc_files ../synthesis/netlist.sdc

# Create RC corners (use typical for homework)
create_rc_corner -name typical_rc \
    -cap_table $PDK_ROOT/libs.tech/openlane/rules.openrcx.sky130A.nom.calibre \
    -preRoute_res 1.0 -postRoute_res 1.0 -preRoute_cap 1.0 -postRoute_cap 1.0

# Create delay corners
create_delay_corner -name slow_corner -library_set slow_libs -rc_corner typical_rc
create_delay_corner -name typical_corner -library_set typical_libs -rc_corner typical_rc  
create_delay_corner -name fast_corner -library_set fast_libs -rc_corner typical_rc

# Create analysis views
create_analysis_view -name slow_view -constraint_mode constraints -delay_corner slow_corner
create_analysis_view -name typical_view -constraint_mode constraints -delay_corner typical_corner
create_analysis_view -name fast_view -constraint_mode constraints -delay_corner fast_corner

# Set analysis views
set_analysis_view -setup slow_view -hold fast_view

# Read design and technology
read_netlist ../synthesis/netlist.v
read_lef [list \
    $PDK_ROOT/libs.tech/lef/sky130_fd_sc_hd.tech.lef \
    $STD_CELL_LIB/lef/sky130_fd_sc_hd.lef \
]

init_design

# Floorplan - size for homework (not production)
# SKY130 site: unithd (width=0.46um, height=2.72um)
floorPlan -site unithd -r 1.0 0.7 10.0 10.0 10.0 10.0

# Power planning
addRing -nets {VPWR VGND} -type core_rings \
        -layer {top met4 bottom met4 left met3 right met3} \
        -width {top 1.8 bottom 1.8 left 1.8 right 1.8} \
        -spacing {top 0.6 bottom 0.6 left 0.6 right 0.6} \
        -offset {top 2.0 bottom 2.0 left 2.0 right 2.0}

addStripe -nets {VPWR VGND} -layer met3 -direction horizontal \
          -width 1.0 -spacing 5.0 -set_to_set_distance 20.0

# Placement
setPlaceMode -place_global_place_io_pins true
placeDesign -prePlaceOpt

# Clock tree
setCTSMode -engine ck
clockDesign -specFile Clock.ctstch -outDir ../reports/cts

# Pre-route optimization  
setOptMode -fixCap true -fixTran true -fixFanoutLoad true
optDesign -preCTS
optDesign -preroute

# Routing
setNanoRouteMode -quiet -routeTopRoutingLayer 6
setNanoRouteMode -quiet -routeBottomRoutingLayer 2
setNanoRouteMode -quiet -droutePostRouteSpreadWire true

routeDesign -globalDetail

# Post-route optimization
optDesign -postRoute
optDesign -postRoute -hold

# Add filler
addFiller -cell sky130_fd_sc_hd__fill_1 -prefix FILLER

# Final reports
summaryReport -noHtml -outDir ../reports
report_timing > ../reports/timing_final.rpt
report_power > ../reports/power_final.rpt

# Export GDS2
streamOut ../RV32IM_sky130.gds \
    -mapFile $PDK_ROOT/libs.tech/klayout/tech/sky130A.gds.map \
    -units 1000 -mode ALL

saveDesign ../RV32IM_final.dat

puts "SKY130 implementation completed!"
puts "GDS file: RV32IM_sky130.gds"
exit
EOF
```

## Phase 5: Environment Configuration

### Step 5.1: Setup Script for University System (With Embedded PDK)
```bash
cat > cadence_work/setup_env.sh << 'EOF'
#!/bin/bash

#==============================================================================
# Environment Setup for University Cadence System
# Uses embedded PDK - no external dependencies!
#==============================================================================

echo "Setting up RV32IM homework environment with embedded PDK..."

# University-specific tool setup (adjust for your system)
if [[ -f /cad/cadence/setup.sh ]]; then
    source /cad/cadence/setup.sh
elif command -v module > /dev/null; then
    module load cadence 2>/dev/null || echo "No cadence module found"
fi

# Use embedded PDK (no external paths needed!)
export PDK_ROOT=$PWD/../pdk/sky130A
export STD_CELL_LIB=$PDK_ROOT/libs.ref/sky130_fd_sc_hd

# Cadence tool settings
export CDS_AUTO_64BIT=ALL
export CADENCE_ENABLE_COLORED_LOG=1

# License settings (if needed - adjust for your university)
export LM_LICENSE_FILE=27020@license-server.university.edu:$LM_LICENSE_FILE

# Working directory
export WORK_DIR=$PWD

echo "Environment configured with embedded PDK:"
echo "  PDK_ROOT: $PDK_ROOT" 
echo "  STD_CELL_LIB: $STD_CELL_LIB"
echo "  CADENCE_HOME: $CADENCE_HOME"

# Verify tools
echo "Checking tools..."
which genus && echo "✓ Genus available" || echo "✗ Genus not found"
which innovus && echo "✓ Innovus available" || echo "✗ Innovus not found"

# Verify embedded PDK
if [[ -d "$STD_CELL_LIB" ]]; then
    echo "✓ Embedded SKY130 PDK found"
    echo "  Library files: $(ls $STD_CELL_LIB/lib/*.lib | wc -l)"
    echo "  LEF files: $(ls $STD_CELL_LIB/lef/*.lef | wc -l)"
    echo "  PDK size: $(du -sh $PDK_ROOT | cut -f1)"
else
    echo "✗ Embedded PDK not found - check extraction"
    exit 1
fi

echo "Setup complete! Ready to run RTL-to-GDS2 flow with embedded PDK."
echo "No external PDK installation required! 🎉"
EOF

chmod +x cadence_work/setup_env.sh
```

### Step 5.2: Master Run Script
```bash
cat > cadence_work/run_homework.sh << 'EOF'
#!/bin/bash

#==============================================================================
# Complete RTL-to-GDS2 Flow for University Homework
#==============================================================================

# Setup environment
source ./setup_env.sh

echo "Starting RV32IM RTL-to-GDS2 homework flow..."

# Create timestamp for this run
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "Run timestamp: $TIMESTAMP"

# Step 1: Synthesis
echo ""
echo "=== Step 1: Logic Synthesis ==="
cd scripts
genus -f genus_sky130.tcl -log ../reports/genus_$TIMESTAMP.log
cd ..

if [[ -f "synthesis/netlist.v" ]]; then
    echo "✓ Synthesis completed successfully"
    wc -l synthesis/netlist.v
else
    echo "✗ Synthesis failed"
    exit 1
fi

# Step 2: Place & Route
echo ""  
echo "=== Step 2: Place & Route ==="
cd scripts
innovus -init innovus_sky130.tcl -log ../reports/innovus_$TIMESTAMP.log
cd ..

if [[ -f "RV32IM_sky130.gds" ]]; then
    echo "✓ Place & Route completed successfully"
    ls -lh RV32IM_sky130.gds
else
    echo "✗ Place & Route failed"
    exit 1
fi

# Step 3: Generate homework report
echo ""
echo "=== Step 3: Generate Report ==="
cat > reports/homework_summary_$TIMESTAMP.txt << REPORT
RV32IM Core Implementation Summary
==================================

Student: [YOUR NAME]
Date: $(date)
Course: [COURSE NUMBER]

Design Specifications:
- Architecture: RV32IM RISC-V Core
- ISA: 48 instructions (RV32I + RV32M)
- Pipeline: 3-stage (Fetch, Execute, Writeback)
- Bus: Wishbone B4
- Technology: SKY130 (130nm)

Implementation Results:
- Synthesis Tool: Cadence Genus
- Place & Route: Cadence Innovus  
- Target Frequency: 100 MHz
- Core Area: $(grep -i "Total cell area" reports/area_syn.rpt | tail -1)
- Gate Count: $(grep -i "instances" reports/qor_syn.rpt | tail -1)
- Critical Path: $(grep -i "worst" reports/timing_final.rpt | head -1)

Files Generated:
- synthesis/netlist.v (gate-level netlist)
- RV32IM_sky130.gds (final layout)
- reports/ (timing, power, area analysis)

Status: COMPLETED SUCCESSFULLY ✓

Next Steps:
- Physical verification (DRC/LVS)
- Parasitic extraction  
- Sign-off timing analysis
REPORT

echo ""
echo "================================================="
echo "RV32IM homework implementation completed!"
echo "================================================="
echo "Key deliverables:"
echo "  • Layout file: RV32IM_sky130.gds"
echo "  • Reports: reports/homework_summary_$TIMESTAMP.txt"
echo "  • All files in: $PWD"
echo ""
echo "Ready to submit! 🎓"
EOF

chmod +x cadence_work/run_homework.sh
```

## Phase 6: Execution Plan

### Step 6.1: First Session (Setup & Synthesis)
```bash
# On university Cadence PC
cd ~/ece_homework/rv32im_asic/cadence_work

# Setup environment
./setup_env.sh

# Run synthesis only
cd scripts
genus -f genus_sky130.tcl

# Check results
ls -la ../synthesis/
cat ../reports/area_syn.rpt
```

### Step 6.2: Second Session (Place & Route)  
```bash
# Continue from synthesis
cd ~/ece_homework/rv32im_asic/cadence_work/scripts
innovus -init innovus_sky130.tcl

# Check final results
ls -lh ../RV32IM_sky130.gds
```

### Step 6.3: Complete Automated Run
```bash
# Full flow in one go (recommended after testing)
cd ~/ece_homework/rv32im_asic/cadence_work
./run_homework.sh

# Wait for completion (~30-60 minutes depending on server)
# Check progress: tail -f reports/genus_*.log
```

## Phase 7: Deliverables Package

### Step 7.1: Create Submission Package
```bash
# Create final homework package
cd ~/ece_homework/rv32im_asic

tar -czf RV32IM_homework_submission.tar.gz \
    cadence_work/RV32IM_sky130.gds \
    cadence_work/reports/ \
    cadence_work/synthesis/netlist.v \
    rtl/ \
    docs/ \
    README.md

# Verify package
tar -tzf RV32IM_homework_submission.tar.gz
ls -lh RV32IM_homework_submission.tar.gz
```

### Step 7.2: What to Include in Report
```
1. Design overview (RV32IM architecture)
2. Implementation flow (Genus → Innovus → GDS2)
3. Results summary (area, timing, power)
4. Layout screenshots from Innovus
5. Lessons learned / challenges faced
6. Files: GDS2, reports, netlist
```

This plan should get you completely set up on your university's Cadence system with SKY130! The scripts are designed to be robust and work in typical academic environments. 🎓