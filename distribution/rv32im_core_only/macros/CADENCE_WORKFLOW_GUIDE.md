# Cadence Workflow Guide for RV32IMZ Macros

This guide explains pin placement, macro integration, and GDSII streaming in the Cadence flow.

---

## 1. PIN PLACEMENT IN INNOVUS

### What is Pin Placement?
Pin placement defines the **physical location** of input/output ports on the edges of your macro. This is critical for:
- **Predictable routing** when integrating macros into larger designs
- **Minimizing wire length** between connected blocks
- **Avoiding congestion** during routing

### How to Use Pin Placement Scripts

#### Step 1: Understand the Pin Placement File Structure

Each macro has a pin placement script (e.g., `core_macro/scripts/core_pin_placement.tcl`):

```tcl
# Example from core_pin_placement.tcl
editPin -pin clk -edge TOP -layer met3 -spreadType center -start {50.0 0.0}
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {60.0 0.0}
editPin -pin iwb_adr_o[*] -edge LEFT -layer met2 -spreadType spread
```

**Key Parameters:**
- `-pin`: Port name (use `[*]` for buses)
- `-edge`: Which side (TOP/BOTTOM/LEFT/RIGHT)
- `-layer`: Metal layer (met1, met2, met3, etc.)
- `-spreadType`:
  - `center`: Single pin at center
  - `spread`: Distribute pins evenly along edge
- `-start`: Starting position in microns `{x y}`

#### Step 2: Apply Pin Placement in Your P&R Script

In your place & route script (e.g., `core_place_route.tcl`), add:

```tcl
# After floorplan creation, before placement
if {[file exists scripts/core_pin_placement.tcl]} {
    source scripts/core_pin_placement.tcl
}
```

**When to apply:**
1. After `floorPlan` command
2. Before `placeDesign` command
3. Before power planning (optional, but recommended)

#### Step 3: Customize for Your Design

**Example: Grouping related signals**
```tcl
# Group instruction bus on LEFT edge
editPin -pin iwb_adr_o[*] -edge LEFT -layer met2 -spreadType spread -start {10.0 0.0}
editPin -pin iwb_cyc_o -edge LEFT -layer met3 -spreadType center -start {50.0 0.0}
editPin -pin iwb_stb_o -edge LEFT -layer met3 -spreadType center -start {55.0 0.0}

# Group data bus on RIGHT edge (for better routing to memory)
editPin -pin dwb_adr_o[*] -edge RIGHT -layer met2 -spreadType spread -start {10.0 0.0}
editPin -pin dwb_dat_o[*] -edge RIGHT -layer met2 -spreadType spread -start {80.0 0.0}
```

**Tips:**
- Put **high-fanout signals** (clocks, resets) at center edges on higher metal layers (met3+)
- Group **related signals** on the same edge
- Use **lower metal layers** (met1, met2) for buses to allow routing over them
- Leave **space between pin groups** to avoid routing congestion

#### Step 4: Verify Pin Placement

After running P&R, check pin placement in Innovus GUI:

```tcl
# In Innovus GUI
gui_select -group [get_ports *]
# View → Show Selection
```

Or generate pin report:
```tcl
report_ports > reports/pin_locations.rpt
```

---

## 2. MACRO INTEGRATION (Hierarchical Flow)

### Overview
Your design has a **hierarchical structure**:

```
soc_integration (TOP)
  ├── rv32im_integrated_macro
  │     ├── core_macro (synthesized, P&R'd separately)
  │     └── mdu_macro (synthesized, P&R'd separately)
  ├── memory_macro
  ├── communication_macro
  ├── protection_macro
  ├── adc_subsystem_macro
  └── pwm_accelerator_macro
```

### Build Order

#### Phase 1: Build Individual Leaf Macros
Build these **first** (they don't depend on others):

```bash
cd core_macro
genus -files scripts/core_synthesis.tcl
innovus -files scripts/core_place_route.tcl

cd ../mdu_macro
genus -files scripts/mdu_synthesis.tcl
innovus -files scripts/mdu_place_route.tcl

# Repeat for: memory, communication, protection, adc_subsystem, pwm_accelerator
```

**Critical outputs per macro:**
- `outputs/<macro>_netlist.v` - Gate-level netlist
- `outputs/<macro>.lef` - Physical abstract (LEF)
- `outputs/<macro>.lib` - Timing model (optional)
- `outputs/<macro>.gds` - Final GDSII layout

#### Phase 2: Build Integrated Macro

The `rv32im_integrated_macro` combines **core_macro** + **mdu_macro**:

```bash
cd rv32im_integrated_macro

# 1. Synthesis (reads pre-built netlists)
genus -files scripts/rv32im_integrated_synthesis.tcl

# 2. Place & Route (places macros as black boxes)
innovus -files scripts/rv32im_integrated_place_route.tcl
```

**How integration works in `rv32im_integrated_place_route.tcl`:**

```tcl
# Read pre-built macro LEF files (physical abstract)
read_physical -lef "$MACRO_DIR/core_macro/outputs/core_macro.lef"
read_physical -lef "$MACRO_DIR/mdu_macro/outputs/mdu_macro.lef"

# Read integrated netlist (instantiates core + mdu)
read_netlist "outputs/rv32im_integrated_macro_syn.v"

# Create floorplan big enough for both
floorPlan -site unithd -s 300.0 200.0 10.0 10.0 10.0 10.0

# Place macros at specific locations
placeInstance u_core_macro 20.0 20.0 -fixed
placeInstance u_mdu_macro 150.0 20.0 -fixed

# Innovus routes ONLY the connections between macros + glue logic
```

#### Phase 3: Build Top-Level SoC

```bash
cd soc_integration

# Synthesis
genus -files scripts/soc_integration_synthesis.tcl

# Place & Route
innovus -files scripts/soc_integration_place_route.tcl
```

### Key Integration Concepts

#### LEF (Library Exchange Format)
- **Abstract physical view** of a macro
- Contains:
  - Macro boundary
  - Pin locations
  - Blockage layers
  - **NOT the internal routing** (keeps IP protected)

Generate LEF in Innovus:
```tcl
write_lef_abstract outputs/<macro>.lef
```

#### DEF (Design Exchange Format)
- **Complete physical layout** including placement and routing
- Used for transferring designs between tools

```tcl
defOut outputs/<macro>.def
```

#### Macro Placement Strategies

**Option 1: Manual placement (current approach)**
```tcl
placeInstance u_core_macro 20.0 20.0 -fixed
```

**Option 2: Auto-placement with constraints**
```tcl
# Define keepout regions
createPlaceBlockage -box {0 0 100 100} -type soft

# Let Innovus place macros
placeDesign -noPrePlaceOpt
```

**Option 3: Floorplan constraints**
```tcl
# Create region for specific macro
createInstGroup core_group -fence {20 20 120 150}
addInstToInstGroup core_group u_core_macro
```

---

## 3. GDSII STREAMING

### What is GDSII Streaming?

GDSII (`.gds`) is the **final layout format** for chip fabrication. "Streaming out" converts Innovus database to GDSII.

### Basic GDSII Stream Command

In your P&R scripts:

```tcl
streamOut outputs/core_macro.gds \
    -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map \
    -stripes 1 \
    -units 1000 \
    -mode ALL
```

**Parameters:**
- `-mapFile`: Maps Innovus layer names to GDSII layer numbers (required for sky130)
- `-stripes`: Include power stripes
- `-units`: Database units (1000 = nm)
- `-mode ALL`: Include all cells

### GDSII Streaming for Hierarchical Designs

#### Issue: Hierarchical vs. Flat GDSII

**Problem:** When you have:
```
top_level
  ├── macro_a (built separately)
  └── macro_b (built separately)
```

You need to ensure `top_level.gds` **includes** the GDS of macro_a and macro_b.

#### Solution 1: Merge GDS Files (Recommended)

After building all macros, merge them:

```tcl
# In top-level P&R script
streamOut outputs/soc_integration.gds \
    -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map \
    -merge {
        ../rv32im_integrated_macro/outputs/rv32im_integrated_macro.gds
        ../memory_macro/outputs/memory_macro.gds
        ../communication_macro/outputs/communication_macro.gds
        ../protection_macro/outputs/protection_macro.gds
        ../adc_subsystem_macro/outputs/adc_subsystem_macro.gds
        ../pwm_accelerator_macro/outputs/pwm_accelerator_macro.gds
    } \
    -mode ALL
```

This creates a **single GDS file** with all macros included.

#### Solution 2: Reference GDS (for large designs)

If macros are very large, keep them as references:

```tcl
# Load macro GDS as references before streaming
read_gds ../core_macro/outputs/core_macro.gds
read_gds ../mdu_macro/outputs/mdu_macro.gds

# Stream out with references
streamOut outputs/rv32im_integrated.gds \
    -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map \
    -mode ALL
```

Innovus will create a **hierarchical GDS** (top-level references macro GDS files).

### Common GDSII Issues and Fixes

#### Issue 1: Missing Macro Cells in GDS

**Symptom:** Top-level GDS has empty boxes instead of macro layouts

**Cause:** Macro GDS not merged or referenced

**Fix:**
```tcl
# Option A: Merge during streamOut
streamOut outputs/top.gds -merge {macro1.gds macro2.gds} ...

# Option B: Read before streamOut
read_gds macro1.gds
read_gds macro2.gds
streamOut outputs/top.gds ...
```

#### Issue 2: Layer Number Mismatch

**Symptom:** Layers appear in wrong places, DRC errors

**Cause:** Wrong or missing GDS map file

**Fix:**
```tcl
# Always use the PDK's official map file
-mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map
```

#### Issue 3: SRAM Macros Not in GDS

**Symptom:** Memory blocks are empty

**Cause:** SRAM GDS not included

**Fix:**
```tcl
# Before streamOut, read SRAM GDS
set SRAM_GDS "$env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/gds"
read_gds "${SRAM_GDS}/sky130_sram_2kbyte_1rw1r_32x512_8.gds"

# Then stream out
streamOut outputs/memory_macro.gds -mapFile ... -mode ALL
```

#### Issue 4: Standard Cells Missing

**Symptom:** Only macro blocks visible, no standard cells

**Cause:** `-mode` parameter issue

**Fix:**
```tcl
# Use -mode ALL to include everything
streamOut outputs/design.gds -mode ALL ...

# Or explicitly:
streamOut outputs/design.gds -mode {ALL CHIP} ...
```

### Verifying GDSII Output

#### Using KLayout (Recommended)

```bash
# View GDS file
klayout outputs/core_macro.gds

# Or with layer properties
klayout -l $PDK_ROOT/sky130A/libs.tech/klayout/sky130A.lyp \
        outputs/core_macro.gds
```

#### Using Magic (sky130 verification)

```bash
# Open in Magic
magic -T $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech \
      outputs/core_macro.gds

# In Magic tcl console:
% drc check
% drc why
```

### Complete Streaming Example

Here's a complete script for streaming hierarchical design:

```tcl
#===============================================================================
# Final GDSII Generation for SoC Integration
#===============================================================================

# Set paths
set PDK_ROOT $env(PDK_ROOT)
set GDS_MAP "$PDK_ROOT/sky130A/libs.tech/klayout/sky130A.gds.map"

# Read pre-built macro GDS files
puts "Reading pre-built macro GDS files..."
read_gds ../rv32im_integrated_macro/outputs/rv32im_integrated_macro.gds
read_gds ../memory_macro/outputs/memory_macro.gds
read_gds ../communication_macro/outputs/communication_macro.gds
read_gds ../protection_macro/outputs/protection_macro.gds
read_gds ../adc_subsystem_macro/outputs/adc_subsystem_macro.gds
read_gds ../pwm_accelerator_macro/outputs/pwm_accelerator_macro.gds

# Read SRAM GDS if used
if {[file exists "$PDK_ROOT/sky130A/libs.ref/sky130_sram_macros/gds"]} {
    read_gds "$PDK_ROOT/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_2kbyte_1rw1r_32x512_8.gds"
}

# Stream out complete SoC
puts "Streaming out final GDS..."
streamOut outputs/soc_complete.gds \
    -mapFile $GDS_MAP \
    -stripes 1 \
    -units 1000 \
    -mode ALL

puts "GDS generation complete: outputs/soc_complete.gds"
```

---

## 4. COMPLETE WORKFLOW EXAMPLE

### Step-by-Step: Building and Integrating Macros

```bash
# 1. Set environment
export PDK_ROOT=/path/to/your/pdk

# 2. Build leaf macros
cd /path/to/RV32IMZ/distribution/rv32im_core_only/macros

# Build core
cd core_macro
genus -batch -files scripts/core_synthesis.tcl -log logs/synthesis.log
innovus -batch -files scripts/core_place_route.tcl -log logs/pnr.log
cd ..

# Build MDU
cd mdu_macro
genus -batch -files scripts/mdu_synthesis.tcl -log logs/synthesis.log
innovus -batch -files scripts/mdu_place_route.tcl -log logs/pnr.log
cd ..

# Build other macros (memory, communication, protection, adc, pwm)
# ... repeat for each ...

# 3. Build integrated macro
cd rv32im_integrated_macro
genus -batch -files scripts/rv32im_integrated_synthesis.tcl -log logs/synthesis.log
innovus -batch -files scripts/rv32im_integrated_place_route.tcl -log logs/pnr.log
cd ..

# 4. Build top-level SoC
cd soc_integration
genus -batch -files scripts/soc_integration_synthesis.tcl -log logs/synthesis.log
innovus -batch -files scripts/soc_integration_place_route.tcl -log logs/pnr.log

# 5. Verify final GDS
klayout outputs/soc_complete.gds
```

---

## 5. TROUBLESHOOTING

### Pin Placement Issues

**Problem:** Pins not appearing after placement

**Solution:**
```tcl
# Check if ports exist
report_ports

# Re-apply pin placement
source scripts/<macro>_pin_placement.tcl

# Save and reload
saveDesign checkpoint_after_pins
restoreDesign checkpoint_after_pins
```

### Macro Integration Issues

**Problem:** "Cannot find module core_macro" during integration

**Solution:**
```tcl
# Ensure netlist is available
ls ../core_macro/outputs/core_macro_syn.v

# Read it explicitly
read_netlist ../core_macro/outputs/core_macro_syn.v
read_netlist ../mdu_macro/outputs/mdu_macro_syn.v
```

**Problem:** Macro placement overlaps

**Solution:**
```tcl
# Check macro sizes first
report_property [get_cells u_core_macro] {origin bbox_llx bbox_lly bbox_urx bbox_ury}
report_property [get_cells u_mdu_macro] {origin bbox_llx bbox_lly bbox_urx bbox_ury}

# Adjust placement coordinates
placeInstance u_mdu_macro 200.0 20.0 -fixed  # Move further right
```

### GDSII Issues

**Problem:** GDS file is too small (only KB instead of MB)

**Solution:**
```tcl
# Check if design is loaded
report_area

# Ensure -mode ALL is used
streamOut outputs/design.gds -mapFile ... -mode ALL

# Verify map file exists
file exists $GDS_MAP
```

**Problem:** DRC errors in final GDS

**Solution:**
```bash
# Run DRC in Innovus before streaming
verify_drc -limit 1000
ecoRoute -fix_drc

# Then stream
streamOut ...
```

---

## 6. USEFUL INNOVUS COMMANDS

```tcl
# === Pin Placement ===
# List all ports
report_ports

# Check pin positions
report_property [get_ports clk] {layer bbox_llx bbox_lly bbox_urx bbox_ury}

# Delete pin placement (to redo)
deleteIoPin -port [get_ports *]

# === Macro Placement ===
# List all instances
report_instances

# Get macro position
report_property [get_cells u_core_macro] {origin status}

# Unplace macro (to reposition)
placeInstance u_core_macro -unplace

# === GDSII ===
# List loaded GDS
report_gds

# Check layer mapping
report_layer_mapping

# Dry-run stream (check without writing)
streamOut outputs/test.gds -mode ALL -checkOnly
```

---

## SUMMARY

1. **Pin Placement**: Use `editPin` commands in separate TCL scripts, source them after floorplan
2. **Macro Integration**: Build leaf macros first, then integrate using LEF files and `placeInstance`
3. **GDSII Streaming**: Use `streamOut` with `-merge` or `read_gds` to include all hierarchy

Your existing scripts already have this infrastructure! Just:
- Customize pin placement files for your signal groupings
- Build macros in bottom-up order
- Use the provided integration scripts

Good luck with your university project!
