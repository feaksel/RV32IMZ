# Fixing LEF Abstract Generation Error in Innovus

## The Error You're Seeing

```
**ERROR: (IMPLF-109): Cannot create OBS on overlap layer for rectilinear
partition 'mdu_macro' because there is no overlap layer defined in any LEF file.
```

This happens when you try to write LEF 5.8 format but your technology LEF doesn't have an OVERLAP layer defined.

---

## SOLUTION 1: Use LEF 5.7 Instead (RECOMMENDED)

The easiest fix - don't use LEF 5.8, use 5.7:

```tcl
# In Innovus console (after restoring your design):
write_lef_abstract -5.7 mdu_macro.lef
```

**Why this works:** LEF 5.7 doesn't require the OVERLAP layer definition.

**LEF 5.7 vs 5.8:**
- LEF 5.7: Works with most sky130 tech LEFs, sufficient for academic designs
- LEF 5.8: Newer format, needs OVERLAP layer, not always necessary

---

## SOLUTION 2: Write LEF Without Version Specification

Let Innovus choose the appropriate version automatically:

```tcl
# Innovus will use the same version as the tech LEF
write_lef_abstract mdu_macro.lef
```

This is even safer and usually works fine.

---

## SOLUTION 3: Add OVERLAP Layer to Tech LEF (NOT RECOMMENDED)

**WARNING: This modifies PDK files - dangerous and not portable!**

Only do this if you have a local copy and understand the risks:

### Step 1: Find your tech LEF

```bash
# For sky130_fd_sc_hd
echo $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef

# For OSU cells
ls ../sky130_osu_sc_t18/lef/sky130_osu_sc_18T_tech.lef
```

### Step 2: Make a backup

```bash
cp sky130_fd_sc_hd__nom.tlef sky130_fd_sc_hd__nom.tlef.backup
```

### Step 3: Add OVERLAP layer

Edit the tech LEF file, add this **at the end, before the final END LIBRARY**:

```lef
LAYER OVERLAP
  TYPE OVERLAP ;
END OVERLAP
```

**Better approach:** Create a local modified copy:

```bash
# Copy to your project
cp $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef \
   local_tech.lef

# Edit local_tech.lef
# Add OVERLAP layer at the end

# Use local tech LEF in your scripts
read_physical -lef local_tech.lef
```

---

## Files Needed for Hierarchical Integration

You asked: **"Is .lef the only thing I need for creating my integrated files later?"**

**Answer: NO, you need multiple files for proper integration.**

### Required Files for Each Macro

| File | Purpose | When Needed | How to Generate |
|------|---------|-------------|-----------------|
| **`.lef`** | Physical abstract (pins, blockages, size) | **REQUIRED** for P&R | `write_lef_abstract mdu_macro.lef` |
| **`.v` (netlist)** | Gate-level Verilog | **REQUIRED** for synthesis | `write_hdl > mdu_macro_netlist.v` |
| **`.gds`** | Final layout | **REQUIRED** for tapeout | `streamOut mdu_macro.gds ...` |
| **`.lib`** | Timing model (Liberty) | **Optional** (recommended) | `write_timing_model ...` |
| **`.sdc`** | Timing constraints | **Optional** (helpful) | `write_sdc mdu_macro.sdc` |

### What Each File Does

#### 1. LEF File (`.lef`) - Physical Abstract

**What it contains:**
- Macro size and boundary
- Pin locations (from your pin placement)
- Metal layer blockages
- **NOT** the internal routing (keeps IP protected)

**Used for:**
- Placing the macro in the parent design
- Routing connections to macro pins
- DRC checking

**Generate in Innovus:**
```tcl
# After completing P&R:
restoreDesign DBS/route.enc.dat mdu_macro

# Write LEF abstract
write_lef_abstract -5.7 outputs/mdu_macro.lef

# Verify it was created
ls -lh outputs/mdu_macro.lef
```

#### 2. Gate-Level Netlist (`.v`) - Logical Connectivity

**What it contains:**
- Instantiations of standard cells
- Net connections
- Module ports

**Used for:**
- Reading into parent synthesis/P&R
- Logical connectivity verification

**Generate in Genus (during synthesis):**
```tcl
# At the end of synthesis script:
write_hdl > outputs/mdu_macro_netlist.v

# Or write for hierarchical integration:
write_hdl > outputs/mdu_macro_syn.v
```

**Or in Innovus:**
```tcl
# After P&R (includes physical optimization):
saveNetlist outputs/mdu_macro_netlist.v -excludeLeafCell
```

#### 3. GDSII Layout (`.gds`) - Final Physical Layout

**What it contains:**
- All metal layers, vias, shapes
- Complete physical implementation
- Needed for fabrication

**Used for:**
- Final tapeout
- Merging into parent GDS
- DRC/LVS verification

**Generate in Innovus:**
```tcl
# After final signoff:
streamOut outputs/mdu_macro.gds \
    -mapFile $PDK_ROOT/sky130A/libs.tech/klayout/sky130A.gds.map \
    -stripes 1 \
    -units 1000 \
    -mode ALL
```

#### 4. Liberty Timing Model (`.lib`) - Optional

**What it contains:**
- Timing arcs (input → output delays)
- Power consumption
- Pin capacitances

**Used for:**
- Accurate timing analysis in parent design
- Better than treating macro as black box

**Generate in Innovus:**
```tcl
# Write timing model
write_timing_model -format lib \
    -library_name mdu_macro_lib \
    outputs/mdu_macro.lib
```

**NOTE:** Many academic projects skip this and use SDC constraints instead.

#### 5. SDC Constraints (`.sdc`) - Optional

**What it contains:**
- Clock definitions
- Input/output delays
- False paths

**Used for:**
- Constraining the macro in parent design
- Timing verification

**Generate in Innovus:**
```tcl
write_sdc outputs/mdu_macro.sdc
```

---

## Complete LEF Generation Workflow

### In Innovus (After P&R Completion):

```tcl
#===============================================================================
# Generate All Integration Files for mdu_macro
#===============================================================================

# Restore your completed design
restoreDesign DBS/route.enc.dat mdu_macro

# Create outputs directory
exec mkdir -p outputs

#===============================================================================
# 1. Write LEF Abstract (Physical)
#===============================================================================

puts "Generating LEF abstract..."

# Use LEF 5.7 to avoid OVERLAP layer issue
write_lef_abstract -5.7 outputs/mdu_macro.lef

# Verify LEF was created
if {[file exists outputs/mdu_macro.lef]} {
    set lef_size [file size outputs/mdu_macro.lef]
    puts "✓ LEF created: outputs/mdu_macro.lef ($lef_size bytes)"
} else {
    puts "ERROR: LEF file not created!"
}

#===============================================================================
# 2. Write Gate-Level Netlist (Logical)
#===============================================================================

puts "Generating gate-level netlist..."

saveNetlist outputs/mdu_macro_netlist.v -excludeLeafCell

if {[file exists outputs/mdu_macro_netlist.v]} {
    puts "✓ Netlist created: outputs/mdu_macro_netlist.v"
} else {
    puts "ERROR: Netlist not created!"
}

#===============================================================================
# 3. Write GDSII (Physical Layout)
#===============================================================================

puts "Generating GDSII layout..."

# Set the GDS map file location
set GDS_MAP "$env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map"

# For OSU cells:
# set GDS_MAP "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"

if {[file exists $GDS_MAP]} {
    streamOut outputs/mdu_macro.gds \
        -mapFile $GDS_MAP \
        -stripes 1 \
        -units 1000 \
        -mode ALL

    puts "✓ GDSII created: outputs/mdu_macro.gds"
} else {
    puts "WARNING: GDS map file not found at $GDS_MAP"
    puts "Attempting streamOut without map file..."
    catch {streamOut outputs/mdu_macro.gds -mode ALL}
}

#===============================================================================
# 4. Write Timing Constraints (Optional)
#===============================================================================

puts "Generating SDC constraints..."

write_sdc outputs/mdu_macro.sdc

if {[file exists outputs/mdu_macro.sdc]} {
    puts "✓ SDC created: outputs/mdu_macro.sdc"
}

#===============================================================================
# 5. Write DEF (Optional - for reference)
#===============================================================================

puts "Generating DEF file..."

defOut outputs/mdu_macro.def

if {[file exists outputs/mdu_macro.def]} {
    puts "✓ DEF created: outputs/mdu_macro.def"
}

#===============================================================================
# Summary
#===============================================================================

puts ""
puts "=========================================="
puts "Integration Files Generated for mdu_macro"
puts "=========================================="
puts ""
puts "Required files for hierarchical integration:"
puts "  [file exists outputs/mdu_macro.lef] outputs/mdu_macro.lef          (Physical abstract)"
puts "  [file exists outputs/mdu_macro_netlist.v] outputs/mdu_macro_netlist.v  (Gate-level netlist)"
puts "  [file exists outputs/mdu_macro.gds] outputs/mdu_macro.gds          (GDSII layout)"
puts ""
puts "Optional files:"
puts "  [file exists outputs/mdu_macro.sdc] outputs/mdu_macro.sdc          (Timing constraints)"
puts "  [file exists outputs/mdu_macro.def] outputs/mdu_macro.def          (DEF - for reference)"
puts ""
puts "Next step: Use these files in your integrated macro or SoC"
puts "=========================================="
puts ""
```

Save this as a script: `pnr/generate_integration_files.tcl`

**Run it:**
```tcl
# In Innovus
source generate_integration_files.tcl
```

---

## Using These Files in Hierarchical Integration

### Example: Integrating mdu_macro into rv32im_integrated_macro

```tcl
#===============================================================================
# In rv32im_integrated_synthesis.tcl (Genus)
#===============================================================================

# Read pre-built macro netlist
read_netlist "../mdu_macro/outputs/mdu_macro_netlist.v"

# Read top-level RTL that instantiates mdu_macro
read_hdl rv32im_integrated_macro.v

# Elaborate
elaborate rv32im_integrated_macro

# Synthesis treats mdu_macro as a black box
syn_generic
syn_map
syn_opt
```

```tcl
#===============================================================================
# In rv32im_integrated_place_route.tcl (Innovus)
#===============================================================================

# Read technology LEF
read_physical -lef "$PDK_ROOT/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.tlef"
read_physical -lef "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"

# Read pre-built macro LEF
read_physical -lef "../mdu_macro/outputs/mdu_macro.lef"

# Read netlist
read_netlist "outputs/rv32im_integrated_macro_syn.v"

# Initialize design
init_design

# Create floorplan
floorPlan -site unithd -s 300.0 200.0 10.0 10.0 10.0 10.0

# Place the macro
placeInstance u_mdu_macro 150.0 20.0 -fixed

# Continue with P&R flow...
```

---

## Using sky130_cds Makefiles Directly

You asked: **"If I use the makefiles in cds system directly the resulting stuff is okay right?"**

**Answer: YES, mostly, but you need to understand what they do.**

### What sky130_cds Makefile Does

Looking at the pnr Makefile (typical flow):

```makefile
init:
	innovus -init init.tcl -log LOG/init.log

place:
	innovus -init place.tcl -log LOG/place.log

cts:
	innovus -init cts.tcl -log LOG/cts.log

route:
	innovus -init route.tcl -log LOG/route.log

signoff:
	innovus -init signoff.tcl -log LOG/signoff.log
```

### What You Get

✅ **Automated flow** - Each stage runs in sequence
✅ **Logs** - Saved in `LOG/` directory
✅ **Reports** - Saved in `RPT/` directory
✅ **Databases** - Saved in `DBS/` directory (`.enc.dat` files)

### What You DON'T Get Automatically

❌ **LEF abstract** - Not generated by default
❌ **GDS merging** - Only generates individual GDS
❌ **Hierarchical integration scripts** - Designed for flat designs
❌ **Pin placement** - May need manual addition

### How to Extend sky130_cds Makefile

Add a `tapeout` target for generating integration files:

**Edit `pnr/Makefile`:**

```makefile
# Add this target after signoff:

.PHONY: tapeout
tapeout: signoff
	@echo "Generating integration files..."
	innovus -init tapeout.tcl -log LOG/tapeout.log
	@echo "Done! Check outputs/ directory"
```

**Create `pnr/tapeout.tcl`:**

```tcl
# Restore final design
restoreDesign DBS/signoff.enc.dat $(DESIGN)

# Source the integration files generation script
source generate_integration_files.tcl

exit
```

**Now you can run:**
```bash
make tapeout
```

And it will generate all LEF, netlist, and GDS files automatically!

---

## Recommended Workflow for Your University Project

### Phase 1: Build Individual Macros with sky130_cds

```bash
# For each macro (mdu, core, memory, etc.)
cd sky130_cds/synth
# ... edit genus_script.tcl for your macro ...
make synth

cd ../pnr
# ... edit setup.tcl for your macro ...
make init
make place
make cts
make route
make signoff
make tapeout  # Your custom target

# Collect outputs
cp outputs/mdu_macro.lef ../../RV32IMZ/macros/mdu_macro/outputs/
cp outputs/mdu_macro_netlist.v ../../RV32IMZ/macros/mdu_macro/outputs/
cp outputs/mdu_macro.gds ../../RV32IMZ/macros/mdu_macro/outputs/
```

### Phase 2: Integrate Macros

Use your existing RV32IMZ integration scripts with the generated files:

```bash
cd RV32IMZ/macros/rv32im_integrated_macro

# Your integration scripts now have all required files:
# - ../mdu_macro/outputs/mdu_macro.lef
# - ../core_macro/outputs/core_macro.lef
# - ../mdu_macro/outputs/mdu_macro_netlist.v
# - ../core_macro/outputs/core_macro_netlist.v

genus -files scripts/rv32im_integrated_synthesis.tcl
innovus -files scripts/rv32im_integrated_place_route.tcl
```

---

## Quick Reference

### Fixing the LEF Error (3 Solutions)

```tcl
# Solution 1: Use LEF 5.7 (EASIEST)
write_lef_abstract -5.7 mdu_macro.lef

# Solution 2: Let Innovus decide version
write_lef_abstract mdu_macro.lef

# Solution 3: Add OVERLAP to tech LEF (NOT RECOMMENDED)
# Edit tech.lef and add OVERLAP layer definition
```

### Files Needed for Integration

```bash
outputs/
├── mdu_macro.lef          # ✓ REQUIRED - Physical abstract
├── mdu_macro_netlist.v    # ✓ REQUIRED - Gate-level netlist
├── mdu_macro.gds          # ✓ REQUIRED - Final layout
├── mdu_macro.sdc          # Optional - Timing constraints
└── mdu_macro.lib          # Optional - Liberty timing model
```

### Generate All Files Script

```tcl
# Save as generate_all.tcl
restoreDesign DBS/signoff.enc.dat mdu_macro
exec mkdir -p outputs
write_lef_abstract -5.7 outputs/mdu_macro.lef
saveNetlist outputs/mdu_macro_netlist.v -excludeLeafCell
write_sdc outputs/mdu_macro.sdc
streamOut outputs/mdu_macro.gds -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map -mode ALL
exit
```

```bash
# Run it
innovus -init generate_all.tcl -log tapeout.log
```

---

## Summary

1. **Fix your error:** Use `write_lef_abstract -5.7 mdu_macro.lef` instead of `-5.8`

2. **You need 3 files minimum:**
   - `.lef` (physical abstract)
   - `.v` (netlist)
   - `.gds` (layout)

3. **sky130_cds Makefile is good** but doesn't generate LEF/netlist by default - add a custom `tapeout` target

4. **Don't modify PDK files** - use LEF 5.7 instead

Your approach of using sky130_cds for building macros is solid! Just make sure to generate all required files for integration.

Good luck!
