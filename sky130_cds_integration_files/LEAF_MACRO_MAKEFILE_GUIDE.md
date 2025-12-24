# 🚀 Automated Leaf Macro Build with Makefiles

This guide shows how to use Makefiles to automate building leaf macros (core_macro, mdu_macro, memory_macro, etc.) with the sky130_cds method.

---

## 📦 What's Included

- **`Makefile.leaf_macro_template`** - Template Makefile for any leaf macro
- **`scripts_template/generate_lef.tcl`** - LEF generation script
- **`scripts_template/generate_gds_with_sram.tcl`** - GDS generation with SRAM support

---

## ✅ Setup for Each Leaf Macro

### Step 1: Copy Makefile to Your Macro Directory

```bash
# For memory_macro:
cd /path/to/macros/memory_macro
cp /path/to/sky130_cds_integration_files/Makefile.leaf_macro_template Makefile

# Edit the Makefile:
nano Makefile
# Change line 7: DESIGN = memory_macro
# Change line 23: USE_SRAM = 1 (if using SRAM, 0 if not)
```

### Step 2: Copy Helper Scripts

```bash
# Copy scripts to your macro's scripts/ directory
mkdir -p scripts
cp /path/to/sky130_cds_integration_files/scripts_template/generate_lef.tcl scripts/
cp /path/to/sky130_cds_integration_files/scripts_template/generate_gds_with_sram.tcl scripts/

# Replace DESIGN_NAME placeholder with your actual design name
sed -i 's/DESIGN_NAME/memory_macro/g' scripts/generate_lef.tcl
sed -i 's/DESIGN_NAME/memory_macro/g' scripts/generate_gds_with_sram.tcl
```

### Step 3: Ensure You Have Required Scripts

Your macro directory should have these scripts (you already have these from sky130_cds):

```
macros/memory_macro/
├── Makefile                         ← NEW (copied template)
├── scripts/
│   ├── memory_macro_synthesis.tcl  ← Your existing synthesis script
│   ├── init.tcl                     ← Your P&R init script
│   ├── place.tcl                    ← Your P&R place script
│   ├── cts.tcl                      ← Your P&R CTS script
│   ├── route.tcl                    ← Your P&R route script
│   ├── generate_lef.tcl             ← NEW (copied from template)
│   └── generate_gds_with_sram.tcl   ← NEW (copied from template)
└── rtl/
    └── memory_macro.v
```

---

## 🚀 Usage

### Build Everything (Complete Flow)

```bash
cd macros/memory_macro
make all
```

This runs:
1. ✅ Synthesis (`genus`)
2. ✅ P&R init (setup + floorplan)
3. ✅ Placement
4. ✅ Clock tree synthesis
5. ✅ Routing
6. ✅ LEF generation
7. ✅ GDS generation (with SRAM merged if USE_SRAM=1)

### Run Individual Steps

```bash
# Just synthesis
make synth

# Just P&R (assumes synthesis already done)
make pnr

# Just LEF generation (assumes route already done)
make lef

# Just GDS generation (assumes route already done)
make gds

# Check if output files exist
make check
```

### Clean Build

```bash
# Clean build artifacts (keeps outputs)
make clean

# Clean everything
make clean-all

# Rebuild from scratch
make clean-all && make all
```

---

## 🎯 Example: Building memory_macro with SRAM

```bash
cd macros/memory_macro

# 1. Setup (one-time)
cp ../../sky130_cds_integration_files/Makefile.leaf_macro_template Makefile
# Edit Makefile: set DESIGN = memory_macro, USE_SRAM = 1
cp -r ../../sky130_cds_integration_files/scripts_template/* scripts/
sed -i 's/DESIGN_NAME/memory_macro/g' scripts/generate_*.tcl

# 2. Build
make all

# Output:
# ✓ outputs/memory_macro.lef
# ✓ outputs/memory_macro.gds (with SRAM merged!)
# ✓ outputs/memory_macro_netlist.v
```

---

## 🔧 Makefile Configuration

### For Macros WITHOUT SRAM

```makefile
# In Makefile, line 23:
USE_SRAM = 0

# That's it! No SRAM will be merged in GDS
```

### For Macros WITH SRAM

```makefile
# In Makefile, lines 23-24:
USE_SRAM = 1
SRAM_NAME = sky130_sram_2kbyte_1rw1r_32x512_8

# SRAM GDS will be automatically merged during GDS generation
```

### Adjusting PDK Path

```makefile
# In Makefile, line 17:
PDK_ROOT ?= ../pdk

# Change to your actual PDK location
PDK_ROOT ?= /home/user/pdk
```

---

## 📋 Complete Workflow for All Leaf Macros

```bash
# Build all 7 leaf macros using Makefiles:

# 1. Core macro (no SRAM)
cd macros/core_macro
make all

# 2. MDU macro (no SRAM)
cd ../mdu_macro
make all

# 3. Memory macro (WITH SRAM)
cd ../memory_macro
make all  # ← SRAM auto-merged!

# 4. Communication macro (no SRAM)
cd ../communication_macro
make all

# 5. Protection macro (no SRAM)
cd ../protection_macro
make all

# 6. ADC subsystem (no SRAM)
cd ../adc_subsystem_macro
make all

# 7. PWM accelerator (no SRAM)
cd ../pwm_accelerator_macro
make all
```

---

## ✅ What the Makefile Does for SRAM Integration

When `USE_SRAM = 1`, the Makefile automatically:

1. **During synthesis:**
   - Reads SRAM Verilog model as black box
   - Marks SRAM as `preserve` and `dont_touch`

2. **During P&R:**
   - Loads SRAM LEF file
   - Places SRAM instance in floorplan

3. **During GDS generation:**
   - Finds SRAM GDS file automatically
   - Merges it into final macro GDS
   - Uses `streamOut -merge` command

**You don't need to manually configure any of this!** ✅

---

## 🔍 Troubleshooting

### "SRAM not found" error

```bash
# Check if SRAM files exist:
ls -lh $PDK_ROOT/sky130A/libs.ref/sky130_sram_macros/

# If missing, you may need to:
# 1. Download SRAM macros separately
# 2. Generate with OpenRAM
# 3. Use alternative memory implementation
```

### "Synthesis script not found"

```bash
# Make sure your synthesis script matches the Makefile name
# Makefile expects: scripts/memory_macro_synthesis.tcl
# Rename if needed:
mv scripts/synthesis.tcl scripts/memory_macro_synthesis.tcl
```

### "streamOut.map not found"

```bash
# Copy from integration package:
cp ../../sky130_cds_integration_files/pnr/streamOut.map .
```

---

## 🎉 Benefits of Makefile Workflow

✅ **Automated** - One command builds everything
✅ **Consistent** - Same process for all macros
✅ **Fast** - Only rebuilds what changed
✅ **SRAM support** - Automatic SRAM integration
✅ **Clean** - Easy cleanup and rebuild
✅ **Documented** - `make help` shows all options

---

## 📊 Summary

**Old manual way:**
```bash
# Many manual steps...
genus -batch ...
innovus
> read_physical ...
> read_netlist ...
> init_design
> floorPlan ...
> place ...
# ... many more commands
> write_lef_abstract ...
> streamOut ...
```

**New Makefile way:**
```bash
make all
```

That's it! 🎉

---

## 🔗 Integration with Hierarchical Flow

After building all leaf macros with Makefiles:

```bash
# All leaf macros built → Now use integration scripts

# Copy outputs to integration location
cp macros/*/outputs/* sky130_cds/pnr/outputs/

# Run Level 1 integration (RV32IM)
cd sky130_cds
make -f Makefile.rv32im all

# Run Level 2 integration (SOC)
make -f Makefile.soc all
```

**Complete automated flow from leaf macros to final SOC!** ✅
