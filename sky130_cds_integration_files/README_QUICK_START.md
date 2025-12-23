# Complete sky130_cds Integration Package with RTL

This package contains **EVERYTHING** you need for hierarchical macro integration with sky130_cds:
- ✅ All synthesis scripts
- ✅ All P&R scripts
- ✅ All Makefiles
- ✅ All constraint files
- ✅ **ALL YOUR RTL FILES** - Ready to use!

## Package Contents

```
sky130_cds_integration_files/
├── README_QUICK_START.md              # This file
├── README_INSTALLATION.md             # Detailed installation guide
├── YOUR_RTL_STRUCTURE_GUIDE.md       # RTL structure verification
├── Makefile                           # Master build automation
│
├── synth/                             # Synthesis files
│   ├── genus_script_rv32im.tcl       # RV32IM integration
│   ├── genus_script_periph.tcl       # Peripheral integration
│   ├── genus_script_soc.tcl          # SOC integration (original)
│   ├── genus_script_soc_UPDATED.tcl  # SOC integration (for your structure)
│   │
│   ├── constraints/                   # Timing constraints
│   │   ├── rv32im_integrated.sdc
│   │   ├── peripheral_subsystem.sdc
│   │   └── soc_integrated.sdc
│   │
│   └── hdl/                           # ✅ ALL YOUR RTL FILES HERE!
│       ├── core_macro/
│       │   ├── core_macro.v
│       │   ├── alu.v
│       │   ├── csr_unit.v
│       │   ├── custom_core_wrapper.v
│       │   ├── custom_riscv_core.v
│       │   ├── decoder.v
│       │   ├── exception_unit.v
│       │   ├── interrupt_controller.v
│       │   ├── regfile.v
│       │   └── riscv_defines.vh
│       │
│       ├── mdu_macro/
│       │   ├── mdu_macro.v
│       │   ├── mdu.v
│       │   └── riscv_defines.vh
│       │
│       ├── memory_macro/
│       │   └── memory_macro.v
│       │
│       ├── communication_macro/
│       │   └── communication_macro.v
│       │
│       ├── protection_macro/
│       │   └── protection_macro.v
│       │
│       ├── adc_subsystem_macro/
│       │   └── adc_subsystem_macro.v
│       │
│       ├── pwm_accelerator_macro/
│       │   └── pwm_accelerator_macro.v
│       │
│       ├── rv32im_integrated/
│       │   └── rv32im_integrated_macro.v
│       │
│       └── soc_integrated/
│           └── rv32im_soc_complete.v
│
└── pnr/                               # Place & Route files
    ├── setup_rv32im.tcl
    ├── setup_periph.tcl
    ├── setup_soc.tcl
    ├── Makefile.rv32im
    ├── Makefile.periph
    ├── Makefile.soc
    │
    └── SCRIPTS/
        ├── init_rv32im.tcl
        ├── init_periph.tcl
        ├── init_soc.tcl
        ├── signoff_rv32im.tcl
        ├── signoff_periph.tcl
        ├── signoff_soc.tcl
        └── signoff_soc_UPDATED.tcl
```

---

## ⚡ QUICK START (3 Steps!)

### Step 1: Get sky130_cds

```bash
# Clone sky130_cds repository
git clone https://github.com/stineje/sky130_cds.git
cd sky130_cds

# Initialize submodules (get OSU standard cells)
git submodule update --init --recursive
```

### Step 2: Copy Everything

```bash
# Copy ALL integration files (including RTL!)
cp -r /path/to/sky130_cds_integration_files/* .

# That's it! Everything is in the right place:
# - Scripts in synth/ and pnr/
# - RTL in synth/hdl/
# - Constraints in synth/constraints/
```

### Step 3: Build!

```bash
# Build complete SOC
make all

# Or build step by step:
# 1. Build leaf macros (standard flow for each)
# 2. Build RV32IM integration
# 3. Build final SOC
```

---

## What's Included - ALL YOUR RTL!

### ✅ Leaf Macro RTL (7 macros)

All your base implementation files are included:

- **core_macro**: 10 files (core_macro.v + 9 submodules)
- **mdu_macro**: 3 files (mdu_macro.v + mdu.v + riscv_defines.vh)
- **memory_macro**: 1 file
- **communication_macro**: 1 file
- **protection_macro**: 1 file
- **adc_subsystem_macro**: 1 file
- **pwm_accelerator_macro**: 1 file

**Total: 20 RTL files ready to synthesize!**

### ✅ Integration RTL (2 files)

Your wrapper files that connect macros:

- **rv32im_integrated_macro.v**: Connects core_macro + mdu_macro
- **rv32im_soc_complete.v**: Complete SOC with all macros

---

## Directory Mapping After Installation

After copying to sky130_cds, files go to these locations:

```
sky130_cds/
├── Makefile                          # ← From integration package
│
├── synth/
│   ├── Makefile                      # Keep existing (standard flow)
│   ├── genus_script.tcl              # Keep existing (standard flow)
│   ├── genus_script_rv32im.tcl       # ← NEW (integration)
│   ├── genus_script_soc_UPDATED.tcl  # ← NEW (integration)
│   │
│   ├── hdl/                          # ← ALL YOUR RTL!
│   │   ├── core_macro/*.v
│   │   ├── mdu_macro/*.v
│   │   ├── memory_macro/*.v
│   │   └── ... (all macros)
│   │
│   └── constraints/                  # ← NEW constraints
│       ├── rv32im_integrated.sdc
│       └── soc_integrated.sdc
│
└── pnr/
    ├── Makefile                      # Keep existing (standard flow)
    ├── setup.tcl                     # Keep existing (standard flow)
    ├── setup_rv32im.tcl              # ← NEW (integration)
    ├── Makefile.rv32im               # ← NEW (integration)
    ├── Makefile.soc                  # ← NEW (integration)
    │
    └── SCRIPTS/
        ├── init.tcl                  # Keep existing (standard flow)
        ├── init_rv32im.tcl           # ← NEW (integration)
        ├── signoff_rv32im.tcl        # ← NEW (integration)
        └── signoff_soc_UPDATED.tcl   # ← NEW (integration)
```

**✅ Standard sky130_cds files**: UNCHANGED (for leaf macros)
**✨ NEW files**: ADDED (for integration)
**🎯 YOUR RTL**: INCLUDED (ready to use)

---

## Build Flow

### Level 0: Build Leaf Macros (Standard sky130_cds)

For **each** of the 7 leaf macros:

```bash
cd synth

# Update genus_script.tcl:
# - set DESIGN "core_macro"
# - set HDL_PATH "hdl/core_macro"

make synth                    # Synthesizes YOUR RTL!

cd ../pnr

# Update setup.tcl:
# - set DESIGN "core_macro"

make all                      # P&R your design

# Generate integration files in Innovus:
innovus
> restoreDesign DBS/signoff.enc.dat core_macro
> exec mkdir -p outputs/core_macro
> write_lef_abstract -5.7 outputs/core_macro/core_macro.lef
> saveNetlist outputs/core_macro/core_macro_netlist.v -excludeLeafCell
> write_sdc outputs/core_macro/core_macro.sdc
> streamOut outputs/core_macro/core_macro.gds \
    -mapFile ../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map -mode ALL
> exit
```

**Repeat for all 7 macros:**
1. core_macro
2. mdu_macro
3. memory_macro
4. communication_macro
5. protection_macro
6. adc_subsystem_macro
7. pwm_accelerator_macro

### Level 1: Build RV32IM Integration

```bash
cd synth
genus -batch -files genus_script_rv32im.tcl

cd ../pnr
make -f Makefile.rv32im all

# Result: rv32im_integrated_macro.gds (core + mdu merged!)
```

### Level 2: Build Final SOC

```bash
cd synth
genus -batch -files genus_script_soc_UPDATED.tcl  # Use UPDATED version!

cd ../pnr
make -f Makefile.soc all

# Result: rv32imz_soc_macro.gds (COMPLETE CHIP!)
```

**Or use master Makefile:**

```bash
cd sky130_cds
make all    # Builds everything automatically!
```

---

## Final Output

After completing all builds, you'll have:

```
pnr/outputs/soc_integrated/
└── rv32imz_soc_macro.gds    # ✅ COMPLETE CHIP GDS!
```

This GDS contains **ALL 7 macros merged** in complete hierarchy:
- rv32im_integrated_macro (which contains core + mdu)
- memory_macro
- communication_macro
- protection_macro
- adc_subsystem_macro
- pwm_accelerator_macro

**Total: 6 top-level macros (8 total including nested core+mdu)**

---

## File Count Summary

| Category | Count | Location |
|----------|-------|----------|
| **RTL Files** | 20 | `synth/hdl/*/` |
| **Synthesis Scripts** | 4 | `synth/` |
| **Constraint Files** | 3 | `synth/constraints/` |
| **P&R Setup Scripts** | 3 | `pnr/` |
| **Init Scripts** | 3 | `pnr/SCRIPTS/` |
| **Signoff Scripts** | 4 | `pnr/SCRIPTS/` |
| **Makefiles** | 4 | `.` and `pnr/` |
| **Documentation** | 3 | `.` |
| **Total** | **44 files** | Complete package! |

---

## Important Notes

### Use UPDATED Scripts for Your Structure

Your SOC directly uses individual peripherals (not peripheral_subsystem), so use:

✅ **Use these:**
- `genus_script_soc_UPDATED.tcl`
- `signoff_soc_UPDATED.tcl`

❌ **Not these:**
- `genus_script_soc.tcl` (assumes peripheral_subsystem level)
- `signoff_soc.tcl` (assumes peripheral_subsystem level)

**OR** rename the UPDATED versions:
```bash
cd synth
mv genus_script_soc_UPDATED.tcl genus_script_soc.tcl

cd ../pnr/SCRIPTS
mv signoff_soc_UPDATED.tcl signoff_soc.tcl
```

### All RTL Files Included

You **don't need** to copy any RTL files - they're already in `synth/hdl/`!

Just copy the entire `sky130_cds_integration_files/` folder and you're ready to go.

---

## Troubleshooting

### "HDL files not found"

**Solution:** Make sure you copied the entire package:
```bash
cp -r sky130_cds_integration_files/* sky130_cds/
```

Not just individual files!

### "Module not found"

**Solution:** Check that RTL files are in the correct `synth/hdl/<macro>/` directory.

### "Library not found"

**Solution:**
```bash
cd sky130_cds
git submodule update --init --recursive
ls sky130_osu_sc_t18/lib/   # Should see library files
```

---

## What You Get

✅ **Complete hierarchical integration system**
✅ **All scripts ready to run**
✅ **All your RTL files included**
✅ **All constraint files**
✅ **All Makefiles**
✅ **Complete documentation**
✅ **One-command build system**

**Just download, copy, and build!** 🚀

---

## Need Help?

1. See `README_INSTALLATION.md` for detailed installation guide
2. See `YOUR_RTL_STRUCTURE_GUIDE.md` for RTL structure verification
3. Check log files in `synth/` and `pnr/LOG/` for errors

Everything is ready for your complete SOC integration!
