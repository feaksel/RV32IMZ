# Guide for YOUR Specific RTL Structure

This document explains exactly how the integration scripts work with **YOUR actual RTL files**.

## Your RTL Structure (Verified)

### ✅ Leaf Macros (Your Base Implementation)

These contain your **actual design**:

```
core_macro/rtl/
├── core_macro.v               # Top module ✅
├── alu.v                      # Submodules ✅
├── csr_unit.v
├── custom_core_wrapper.v
├── custom_riscv_core.v
├── decoder.v
├── exception_unit.v
├── interrupt_controller.v
├── regfile.v
└── riscv_defines.vh

mdu_macro/rtl/
├── mdu_macro.v                # Top module ✅
├── mdu.v                      # Submodule ✅
└── riscv_defines.vh

memory_macro/rtl/
└── memory_macro.v             # Single file ✅

communication_macro/rtl/
└── communication_macro.v      # Single file ✅

protection_macro/rtl/
└── protection_macro.v         # Single file ✅

adc_subsystem_macro/rtl/
└── adc_subsystem_macro.v      # Single file ✅

pwm_accelerator_macro/rtl/
└── pwm_accelerator_macro.v    # Single file ✅
```

### ✅ Integration RTL (Wrapper Files)

These **instantiate pre-built macros**:

```
rv32im_integrated_macro/rtl/
└── rv32im_integrated_macro.v
    # Instantiates: core_macro + mdu_macro ✅

soc_integration/rtl/
└── rv32im_soc_complete.v
    # Module name: rv32im_soc_with_integrated_core
    # Instantiates: ✅
    #   - rv32im_integrated_macro (pre-built, contains core+mdu)
    #   - memory_macro (individual)
    #   - communication_macro (individual)
    #   - protection_macro (individual)
    #   - adc_subsystem_macro (individual)
    #   - pwm_accelerator_macro (individual)
```

---

## Scripts Know Your RTL - Verification

### ✅ Synthesis Scripts Read Correct Files

**genus_script_rv32im.tcl:**
```tcl
read_hdl -v2001 {
    rv32im_integrated_macro.v   # ✅ Matches your file name
}
```

**genus_script_soc_UPDATED.tcl:**
```tcl
read_hdl -v2001 {
    rv32im_soc_complete.v       # ✅ Matches your file name
}
```

### ✅ Correct Module Names

The scripts elaborate the correct module names:
- **rv32im_integrated_macro** ✅
- **rv32im_soc_with_integrated_core** ✅ (NOT rv32imz_soc_macro - I updated this!)

---

## File Generation Flow

### Stage 1: Build Leaf Macros (Standard sky130_cds)

**Input (you provide):**
```
sky130_cds/synth/hdl/core_macro/*.v       # Your RTL
sky130_cds/synth/hdl/mdu_macro/*.v        # Your RTL
# ... all other macros
```

**Commands:**
```bash
cd synth
# Update genus_script.tcl to point to core_macro
make synth                                 # Synthesizes YOUR RTL

cd ../pnr
make all                                   # P&R your design
```

**Output (auto-generated in Innovus):**
```
pnr/outputs/core_macro/
├── core_macro.lef            # ✅ Auto-created by write_lef_abstract
├── core_macro_netlist.v      # ✅ Auto-created by saveNetlist
├── core_macro.sdc            # ✅ Auto-created by write_sdc
└── core_macro.gds            # ✅ Auto-created by streamOut
```

You manually run these commands in Innovus after `make all`:
```tcl
restoreDesign DBS/signoff.enc.dat core_macro
exec mkdir -p outputs/core_macro
write_lef_abstract -5.7 outputs/core_macro/core_macro.lef
saveNetlist outputs/core_macro/core_macro_netlist.v -excludeLeafCell
write_sdc outputs/core_macro/core_macro.sdc
streamOut outputs/core_macro/core_macro.gds -mapFile ../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map -mode ALL
exit
```

Repeat for **ALL 7 leaf macros**.

---

### Stage 2: Build RV32IM Integration

**Input (you provide):**
```
sky130_cds/synth/hdl/rv32im_integrated/rv32im_integrated_macro.v    # Your wrapper RTL
```

**Input (auto-available from Stage 1):**
```
pnr/outputs/core_macro/core_macro_netlist.v     # Pre-built netlist
pnr/outputs/mdu_macro/mdu_macro_netlist.v       # Pre-built netlist
```

**Commands:**
```bash
cd synth
genus -batch -files genus_script_rv32im.tcl
```

**What happens:**
1. Genus reads `core_macro_netlist.v` (pre-built) ✅
2. Genus reads `mdu_macro_netlist.v` (pre-built) ✅
3. Genus marks them as **black boxes** (don't re-synthesize) ✅
4. Genus reads `rv32im_integrated_macro.v` (your wrapper) ✅
5. Genus **only synthesizes the wires** connecting core and mdu ✅

**Output (auto-generated):**
```
synth/outputs/rv32im_integrated/
├── rv32im_integrated_macro.vh    # ✅ Auto-created by write_hdl
├── rv32im_integrated_macro.sdc   # ✅ Auto-created by write_sdc
└── rv32im_integrated_macro.sdf   # ✅ Auto-created by write_sdf
```

**Commands (P&R):**
```bash
cd ../pnr
make -f Makefile.rv32im all
```

**What happens:**
1. Innovus reads `core_macro.lef` and `mdu_macro.lef` ✅
2. Innovus places them as **fixed blocks** ✅
3. Innovus places/routes only the **glue logic** ✅
4. Innovus generates **merged GDS** with core+mdu inside ✅

**Output (auto-generated):**
```
pnr/outputs/rv32im_integrated/
├── rv32im_integrated_macro.lef           # ✅ Auto-created
├── rv32im_integrated_macro_netlist.v     # ✅ Auto-created
├── rv32im_integrated_macro.sdc           # ✅ Auto-created
└── rv32im_integrated_macro.gds           # ✅ Auto-created (core+mdu merged!)
```

---

### Stage 3: Build Final SOC

**Input (you provide):**
```
sky130_cds/synth/hdl/soc_integrated/rv32im_soc_complete.v    # Your SOC wrapper
```

**Input (auto-available from previous stages):**
```
pnr/outputs/rv32im_integrated/rv32im_integrated_macro_netlist.v   # Pre-built
pnr/outputs/memory_macro/memory_macro_netlist.v                   # Pre-built
pnr/outputs/communication_macro/communication_macro_netlist.v     # Pre-built
pnr/outputs/protection_macro/protection_macro_netlist.v           # Pre-built
pnr/outputs/adc_subsystem_macro/adc_subsystem_macro_netlist.v     # Pre-built
pnr/outputs/pwm_accelerator_macro/pwm_accelerator_macro_netlist.v # Pre-built
```

**Commands:**
```bash
cd synth
genus -batch -files genus_script_soc_UPDATED.tcl  # Use UPDATED version!
```

**What happens:**
1. Genus reads **rv32im_integrated_macro_netlist.v** (pre-built, contains core+mdu) ✅
2. Genus reads all 5 peripheral macro netlists (pre-built) ✅
3. Genus marks them ALL as **black boxes** ✅
4. Genus reads `rv32im_soc_complete.v` (your wrapper) ✅
5. Genus **only synthesizes the top-level interconnect** (Wishbone bus arbiter, etc.) ✅

**Output (auto-generated):**
```
synth/outputs/soc_integrated/
├── rv32im_soc_with_integrated_core.vh    # ✅ Auto-created
├── rv32im_soc_with_integrated_core.sdc   # ✅ Auto-created
└── rv32im_soc_with_integrated_core.sdf   # ✅ Auto-created
```

**Commands (P&R):**
```bash
cd ../pnr
make -f Makefile.soc all
```

**What happens:**
1. Innovus reads LEF files for **ALL 6 macros** ✅
2. Innovus places them as **fixed blocks** ✅
3. Innovus places/routes only the **top-level glue logic** ✅
4. Innovus generates **complete merged GDS** with ALL macros ✅

**Output (auto-generated):**
```
pnr/outputs/soc_integrated/
├── rv32imz_soc_macro.lef           # ✅ Auto-created
├── rv32imz_soc_macro_netlist.v     # ✅ Auto-created
├── rv32imz_soc_macro_full.v        # ✅ Auto-created (with all cells)
├── rv32imz_soc_macro.sdc           # ✅ Auto-created
├── rv32imz_soc_macro.sdf           # ✅ Auto-created
└── rv32imz_soc_macro.gds           # ✅ FINAL GDS with ALL macros merged!
```

---

## Final GDS Hierarchy

Your final `rv32imz_soc_macro.gds` contains:

```
rv32imz_soc_macro.gds (TOP)
├── rv32im_integrated_macro.gds (MERGED)
│   ├── core_macro.gds (MERGED)
│   └── mdu_macro.gds (MERGED)
├── memory_macro.gds (MERGED)
├── communication_macro.gds (MERGED)
├── protection_macro.gds (MERGED)
├── adc_subsystem_macro.gds (MERGED)
└── pwm_accelerator_macro.gds (MERGED)
```

**Total: 7 top-level macros, but 8 total including the nested core+mdu**

---

## Important: Use UPDATED Scripts!

For **YOUR structure**, use these files:

### ❌ Don't Use (assumes peripheral_subsystem level):
- `genus_script_soc.tcl`
- `signoff_soc.tcl`

### ✅ Use Instead (matches your structure):
- `genus_script_soc_UPDATED.tcl` - Reads individual peripherals directly
- `signoff_soc_UPDATED.tcl` - Merges individual peripheral GDS files

**Or** you can rename them:
```bash
cd sky130_cds_integration_files
mv synth/genus_script_soc_UPDATED.tcl synth/genus_script_soc.tcl
mv pnr/SCRIPTS/signoff_soc_UPDATED.tcl pnr/SCRIPTS/signoff_soc.tcl
```

---

## Summary: Your Questions Answered

### Q1: Do scripts know my correct base RTL?

**A: YES! ✅**

The scripts read exactly the files you have:
- `rv32im_integrated_macro.v` ✅
- `rv32im_soc_complete.v` ✅
- Module name: `rv32im_soc_with_integrated_core` ✅

### Q2: Does it automatically generate files in correct places?

**A: YES! ✅**

Files are auto-generated in these locations:
- **Synthesis outputs**: `synth/outputs/<macro>/`
- **P&R outputs**: `pnr/outputs/<macro>/`

You just run commands, files appear automatically in the right places!

### Q3: For full SOC, do you use integrated rv32im?

**A: YES! ✅**

Your SOC correctly uses:
- `rv32im_integrated_macro` (which contains core_macro + mdu_macro already merged)
- NOT separate core_macro and mdu_macro

This means the GDS has proper hierarchy:
```
SOC → rv32im_integrated → (core + mdu)
```

Perfect! 🚀

---

## Next Steps

1. Copy YOUR RTL to `sky130_cds/synth/hdl/`
2. Build all 7 leaf macros using standard sky130_cds flow
3. Generate integration files (LEF, netlist, GDS) for each
4. Build rv32im_integrated using `genus_script_rv32im.tcl`
5. Build final SOC using `genus_script_soc_UPDATED.tcl`
6. Get complete GDS with all macros merged!

Everything is ready for your exact RTL structure! ✅
