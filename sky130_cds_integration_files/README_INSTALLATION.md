# Installation Guide for RV32IMZ Hierarchical Integration Files

This directory contains **ALL the integration files** you need to add hierarchical macro integration to the sky130_cds repository.

## What's Included

This package contains:
- ✅ Complete synthesis scripts for all integration levels
- ✅ Complete P&R scripts (setup, init, signoff)
- ✅ Complete Makefiles for automated builds
- ✅ Timing constraint (SDC) files for each level
- ✅ Master Makefile for building the entire SOC

**NO RTL FILES** are included - you already have those!

---

## Quick Start

```bash
# 1. Clone sky130_cds (if you haven't already)
git clone https://github.com/stineje/sky130_cds.git
cd sky130_cds

# 2. Initialize submodules (get OSU standard cells)
git submodule update --init --recursive

# 3. Copy all integration files
cp -r /path/to/sky130_cds_integration_files/* .

# 4. Build your SOC!
make all
```

---

## Detailed Installation Instructions

### Step 1: Prerequisites

**Required:**
- sky130_cds repository cloned
- Cadence Genus (synthesis)
- Cadence Innovus (P&R)
- OSU standard cell library (included in sky130_cds submodules)

**Your existing files:**
- RTL for all leaf macros
- Integration RTL (rv32im_integrated_macro.v, etc.)

### Step 2: Copy Files to sky130_cds

Here's **EXACTLY** where each file goes:

```bash
cd sky130_cds

# IMPORTANT: Make sure you're in the sky130_cds root directory!
```

#### A. Synthesis Scripts

```bash
# Copy integration synthesis scripts
cp path/to/sky130_cds_integration_files/synth/genus_script_rv32im.tcl synth/
cp path/to/sky130_cds_integration_files/synth/genus_script_periph.tcl synth/
cp path/to/sky130_cds_integration_files/synth/genus_script_soc.tcl synth/

# Copy constraint files
cp path/to/sky130_cds_integration_files/synth/constraints/* synth/constraints/

# Your synthesis directory should now have:
# synth/
# ├── Makefile                      (standard - already exists)
# ├── genus_script.tcl              (standard - already exists, KEEP IT!)
# ├── genus_script_rv32im.tcl       (NEW - for RV32IM integration)
# ├── genus_script_periph.tcl       (NEW - for peripheral integration)
# ├── genus_script_soc.tcl          (NEW - for SOC integration)
# └── constraints/
#     ├── rv32im_integrated.sdc     (NEW)
#     ├── peripheral_subsystem.sdc  (NEW)
#     └── soc_integrated.sdc        (NEW)
```

#### B. P&R Scripts

```bash
# Copy P&R setup scripts
cp path/to/sky130_cds_integration_files/pnr/setup_rv32im.tcl pnr/
cp path/to/sky130_cds_integration_files/pnr/setup_periph.tcl pnr/
cp path/to/sky130_cds_integration_files/pnr/setup_soc.tcl pnr/

# Copy init/signoff scripts
cp path/to/sky130_cds_integration_files/pnr/SCRIPTS/* pnr/SCRIPTS/

# Copy Makefiles
cp path/to/sky130_cds_integration_files/pnr/Makefile.rv32im pnr/
cp path/to/sky130_cds_integration_files/pnr/Makefile.periph pnr/
cp path/to/sky130_cds_integration_files/pnr/Makefile.soc pnr/

# Your P&R directory should now have:
# pnr/
# ├── Makefile                      (standard - already exists, KEEP IT!)
# ├── setup.tcl                     (standard - already exists, KEEP IT!)
# ├── setup_rv32im.tcl              (NEW)
# ├── setup_periph.tcl              (NEW)
# ├── setup_soc.tcl                 (NEW)
# ├── Makefile.rv32im               (NEW)
# ├── Makefile.periph               (NEW)
# ├── Makefile.soc                  (NEW)
# └── SCRIPTS/
#     ├── init.tcl                  (standard - already exists, KEEP IT!)
#     ├── init_rv32im.tcl           (NEW)
#     ├── init_periph.tcl           (NEW)
#     ├── init_soc.tcl              (NEW)
#     ├── signoff_rv32im.tcl        (NEW)
#     ├── signoff_periph.tcl        (NEW)
#     └── signoff_soc.tcl           (NEW)
```

#### C. Master Makefile

```bash
# Copy master Makefile to sky130_cds root
cp path/to/sky130_cds_integration_files/Makefile .

# Your sky130_cds root should now have:
# sky130_cds/
# ├── Makefile                      (NEW - master build automation)
# ├── synth/
# ├── pnr/
# └── sky130_osu_sc_t18/            (submodule)
```

### Step 3: Add Your RTL

Now add your RTL to the appropriate directories:

```bash
cd sky130_cds/synth

# Create directories for integration RTL
mkdir -p hdl/rv32im_integrated
mkdir -p hdl/peripheral_subsystem
mkdir -p hdl/soc_integrated

# Copy your integration RTL
# (These files instantiate the pre-built macros)

# Example:
cp /path/to/RV32IMZ/macros/rv32im_integrated/rtl/rv32im_integrated_macro.v \
   hdl/rv32im_integrated/

cp /path/to/RV32IMZ/macros/peripheral_subsystem/rtl/peripheral_subsystem_macro.v \
   hdl/peripheral_subsystem/

cp /path/to/RV32IMZ/macros/soc_integration/rtl/rv32imz_soc_macro.v \
   hdl/soc_integrated/

# Your hdl/ directory structure:
# hdl/
# ├── rv32im_integrated/
# │   └── rv32im_integrated_macro.v         (your RTL)
# ├── peripheral_subsystem/
# │   └── peripheral_subsystem_macro.v      (your RTL)
# └── soc_integrated/
#     └── rv32imz_soc_macro.v               (your RTL)
```

### Step 4: Verify Installation

```bash
cd sky130_cds

# Check that all files are in place
ls -l Makefile                          # Should exist (master)
ls -l synth/genus_script_rv32im.tcl    # Should exist
ls -l synth/genus_script_periph.tcl    # Should exist
ls -l synth/genus_script_soc.tcl       # Should exist
ls -l pnr/Makefile.rv32im               # Should exist
ls -l pnr/Makefile.periph               # Should exist
ls -l pnr/Makefile.soc                  # Should exist
ls -l pnr/SCRIPTS/init_rv32im.tcl      # Should exist
ls -l pnr/SCRIPTS/signoff_soc.tcl      # Should exist

# If all files exist, you're ready!
```

---

## Directory Structure After Installation

```
sky130_cds/
├── Makefile                                    # NEW - Master build automation
├── synth/
│   ├── Makefile                                # KEEP - Standard (for leaf macros)
│   ├── genus_script.tcl                        # KEEP - Standard (for leaf macros)
│   ├── genus_script_rv32im.tcl                 # NEW - RV32IM integration
│   ├── genus_script_periph.tcl                 # NEW - Peripheral integration
│   ├── genus_script_soc.tcl                    # NEW - SOC integration
│   ├── hdl/
│   │   ├── rv32im_integrated/                  # NEW - Your integration RTL
│   │   ├── peripheral_subsystem/               # NEW - Your integration RTL
│   │   └── soc_integrated/                     # NEW - Your integration RTL
│   └── constraints/
│       ├── rv32im_integrated.sdc               # NEW
│       ├── peripheral_subsystem.sdc            # NEW
│       └── soc_integrated.sdc                  # NEW
├── pnr/
│   ├── Makefile                                # KEEP - Standard (for leaf macros)
│   ├── setup.tcl                               # KEEP - Standard (for leaf macros)
│   ├── setup_rv32im.tcl                        # NEW
│   ├── setup_periph.tcl                        # NEW
│   ├── setup_soc.tcl                           # NEW
│   ├── Makefile.rv32im                         # NEW
│   ├── Makefile.periph                         # NEW
│   ├── Makefile.soc                            # NEW
│   └── SCRIPTS/
│       ├── init.tcl                            # KEEP - Standard
│       ├── init_rv32im.tcl                     # NEW
│       ├── init_periph.tcl                     # NEW
│       ├── init_soc.tcl                        # NEW
│       ├── signoff_rv32im.tcl                  # NEW
│       ├── signoff_periph.tcl                  # NEW
│       └── signoff_soc.tcl                     # NEW
└── sky130_osu_sc_t18/                          # Submodule (already exists)
```

---

## What NOT to Modify

**IMPORTANT: These standard sky130_cds files should remain UNCHANGED:**

- ✅ `synth/Makefile` - Keep for leaf macros
- ✅ `synth/genus_script.tcl` - Keep for leaf macros
- ✅ `pnr/Makefile` - Keep for leaf macros
- ✅ `pnr/setup.tcl` - Keep for leaf macros
- ✅ `pnr/SCRIPTS/init.tcl` - Keep for leaf macros

**All NEW files are for hierarchical integration only!**

---

## Usage After Installation

### Build Leaf Macros (Standard Flow - Unchanged!)

```bash
cd sky130_cds/synth

# Update genus_script.tcl for your macro (just change DESIGN and HDL_PATH)
make synth

cd ../pnr

# Run standard P&R
make all

# Generate integration files in Innovus
innovus
> restoreDesign DBS/signoff.enc.dat core_macro
> exec mkdir -p outputs/core_macro
> write_lef_abstract -5.7 outputs/core_macro/core_macro.lef
> saveNetlist outputs/core_macro/core_macro_netlist.v -excludeLeafCell
> write_sdc outputs/core_macro/core_macro.sdc
> streamOut outputs/core_macro/core_macro.gds -mapFile ../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map -mode ALL
> exit

# Repeat for all leaf macros:
# - core_macro
# - mdu_macro
# - memory_macro
# - communication_macro
# - protection_macro
# - adc_subsystem_macro
# - pwm_accelerator_macro
```

### Build Integrated Subsystems (NEW Scripts!)

```bash
cd sky130_cds/synth

# Build RV32IM integrated (core + mdu)
genus -batch -files genus_script_rv32im.tcl

cd ../pnr
make -f Makefile.rv32im all

# Build peripheral subsystem
cd ../synth
genus -batch -files genus_script_periph.tcl

cd ../pnr
make -f Makefile.periph all
```

### Build Final SOC (NEW Scripts!)

```bash
cd sky130_cds/synth

# Build SOC
genus -batch -files genus_script_soc.tcl

cd ../pnr
make -f Makefile.soc all

# Final GDS is at:
# pnr/outputs/soc_integrated/rv32imz_soc_macro.gds
```

### Or Build Everything at Once!

```bash
cd sky130_cds

# Build complete SOC with one command!
make all

# This will:
# 1. Check prerequisites
# 2. Remind you to build leaf macros
# 3. Build Level 1 integrations
# 4. Build final SOC
# 5. Generate complete GDS with all macros merged
```

---

## Output Files

After running the complete flow, you'll have:

### Level 1 Integrated Macros

```
pnr/outputs/rv32im_integrated/
├── rv32im_integrated_macro.lef           # For next-level integration
├── rv32im_integrated_macro_netlist.v     # For next-level synthesis
├── rv32im_integrated_macro.sdc           # Timing constraints
└── rv32im_integrated_macro.gds           # With core + mdu merged

pnr/outputs/peripheral_subsystem/
├── peripheral_subsystem_macro.lef
├── peripheral_subsystem_macro_netlist.v
├── peripheral_subsystem_macro.sdc
└── peripheral_subsystem_macro.gds        # With all peripheral macros merged
```

### Level 2 Final SOC

```
pnr/outputs/soc_integrated/
├── rv32imz_soc_macro.lef
├── rv32imz_soc_macro_netlist.v
├── rv32imz_soc_macro_full.v              # With all leaf cells
├── rv32imz_soc_macro.sdc
├── rv32imz_soc_macro.sdf                 # For timing simulation
└── rv32imz_soc_macro.gds                 # <-- COMPLETE CHIP GDS!
```

The final `rv32imz_soc_macro.gds` contains **ALL 8 macros** merged in complete hierarchy!

---

## Troubleshooting

### Problem: "Macro netlist not found"

**Solution:**
```bash
# Make sure you built the macro first using standard flow
cd synth
make synth   # Build the leaf macro

cd ../pnr
make all     # P&R the leaf macro

# Then generate integration files in Innovus
innovus
> restoreDesign DBS/signoff.enc.dat <macro_name>
> exec mkdir -p outputs/<macro_name>
> write_lef_abstract -5.7 outputs/<macro_name>/<macro_name>.lef
> saveNetlist outputs/<macro_name>/<macro_name>_netlist.v -excludeLeafCell
> streamOut outputs/<macro_name>/<macro_name>.gds -mapFile ../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map -mode ALL
> exit
```

### Problem: "LEF file not found"

**Solution:** Same as above - generate the LEF file in Innovus after completing P&R.

### Problem: "Integration RTL not found"

**Solution:**
```bash
# Make sure you copied your integration RTL to the right location:
cd synth/hdl
ls rv32im_integrated/rv32im_integrated_macro.v    # Should exist
ls peripheral_subsystem/peripheral_subsystem_macro.v  # Should exist
ls soc_integrated/rv32imz_soc_macro.v              # Should exist
```

### Problem: "Library not found"

**Solution:**
```bash
cd sky130_cds
git submodule update --init --recursive
ls sky130_osu_sc_t18/lib/   # Should see library files
```

---

## Complete Build Checklist

Use this checklist to ensure you have everything:

**Prerequisites:**
- [ ] sky130_cds cloned
- [ ] Submodules initialized (`git submodule update --init --recursive`)
- [ ] Integration files copied to sky130_cds
- [ ] Cadence tools (Genus, Innovus) accessible

**Level 0 (Leaf Macros):**
- [ ] core_macro built and integration files generated
- [ ] mdu_macro built and integration files generated
- [ ] memory_macro built and integration files generated
- [ ] communication_macro built and integration files generated
- [ ] protection_macro built and integration files generated
- [ ] adc_subsystem_macro built and integration files generated
- [ ] pwm_accelerator_macro built and integration files generated

**Level 1 (Integrated Subsystems):**
- [ ] rv32im_integrated RTL copied to synth/hdl/
- [ ] rv32im_integrated synthesis complete
- [ ] rv32im_integrated P&R complete
- [ ] peripheral_subsystem RTL copied to synth/hdl/
- [ ] peripheral_subsystem synthesis complete
- [ ] peripheral_subsystem P&R complete

**Level 2 (Final SOC):**
- [ ] SOC RTL copied to synth/hdl/
- [ ] SOC synthesis complete
- [ ] SOC P&R complete
- [ ] Final GDS generated with all macros merged

**Done!**
- [ ] Final GDS verified: `pnr/outputs/soc_integrated/rv32imz_soc_macro.gds`
- [ ] Timing reports checked (no violations)
- [ ] Ready for tapeout! 🚀

---

## Summary

This installation adds hierarchical integration capability to sky130_cds **WITHOUT modifying any standard files!**

- ✅ Standard files for leaf macros: **UNCHANGED**
- ✅ New files for integration: **ADDED**
- ✅ Works seamlessly with existing sky130_cds flow
- ✅ Complete automation with master Makefile
- ✅ Final GDS with all macros merged

You now have a complete 3-level hierarchical build system ready to use!

---

## Questions?

If you encounter any issues:

1. Check this README carefully
2. Verify all files are in the correct locations
3. Ensure leaf macros are built and integration files generated
4. Check log files for specific errors

Good luck with your SOC integration! 🚀
