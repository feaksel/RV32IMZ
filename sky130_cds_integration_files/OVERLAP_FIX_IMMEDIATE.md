# 🔧 IMMEDIATE FIX: OVERLAP Layer Error in Innovus

## Problem
`write_lef_abstract` fails with OVERLAP layer error on ALL versions (5.6, 5.7, 5.8, 6.0).

## ✅ Solution: Add OVERLAP Layer Definition

We've created `tech_overlay_overlap.lef` that adds the OVERLAP layer without modifying original PDK files.

---

## 🚀 If You're Currently at Innovus Prompt

You can fix this **RIGHT NOW** without restarting:

### Step 1: Load the OVERLAP layer definition

```tcl
# At the innovus prompt, run:
read_physical -lef tech_overlay_overlap.lef
```

### Step 2: Generate LEF

```tcl
# Now write_lef_abstract will work:
write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef
```

**That's it!** The error should be gone. ✅

---

## 🔄 For Future Runs (Automatic Loading)

The setup scripts have been updated to automatically load the OVERLAP layer:

- `setup_rv32im.tcl` - Loads `tech_overlay_overlap.lef` automatically
- `setup_soc.tcl` - Loads `tech_overlay_overlap.lef` automatically
- `setup_periph.tcl` - Loads `tech_overlay_overlap.lef` automatically

When you run the normal flow, the OVERLAP layer is loaded automatically:

```bash
cd sky130_cds/pnr

# The setup script will automatically load tech_overlay_overlap.lef
innovus -init SCRIPTS/init_rv32im.tcl
```

---

## 📄 What's in tech_overlay_overlap.lef?

It's a minimal LEF file that only adds the OVERLAP layer definition:

```lef
VERSION 5.7 ;
BUSBITCHARS "[]" ;
DIVIDERCHAR "/" ;

LAYER OVERLAP
  TYPE OVERLAP ;
END OVERLAP

END LIBRARY
```

**Safe:** This doesn't modify your original PDK files at all!

---

## 🎯 Complete Workflow Example

### Scenario: Building mdu_macro and generating LEF

```bash
# 1. Navigate to P&R directory
cd sky130_cds/pnr

# 2. Start Innovus with your design
innovus

# 3. At Innovus prompt, load tech LEF
innovus 1> read_physical -lef ../sky130_osu_sc_t18/lef/sky130_osu_sc_18T_tech.lef
innovus 2> read_physical -lef ../sky130_osu_sc_t18/lef/sky130_osu_sc_18T.lef

# 4. Load OVERLAP layer (THE FIX!)
innovus 3> read_physical -lef tech_overlay_overlap.lef

# 5. Continue with your normal flow...
innovus 4> read_netlist ../synth/outputs/mdu_macro/mdu_macro.vh
innovus 5> init_design
# ... do placement, routing, etc ...

# 6. Generate LEF (will work now!)
innovus 99> write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef
```

---

## ✅ Verification

After running `write_lef_abstract`, you should see:

```
Writing LEF abstract...
Writing outputs/mdu_macro/mdu_macro.lef
```

**No OVERLAP error!** ✅

---

## 🔍 Why This Works

1. **Problem:** Innovus needs OVERLAP layer for complex obstruction generation in LEF 5.7+
2. **Root cause:** SkyWater/OSU PDK tech LEF doesn't define OVERLAP layer
3. **Solution:** We add OVERLAP definition via overlay LEF loaded AFTER tech LEF
4. **Result:** Innovus sees OVERLAP layer and write_lef_abstract works!

---

## 📚 Related Files

- `tech_overlay_overlap.lef` - The OVERLAP layer definition (14 lines)
- `setup_rv32im.tcl` - Auto-loads overlay for RV32IM integration
- `setup_soc.tcl` - Auto-loads overlay for SOC integration
- `setup_periph.tcl` - Auto-loads overlay for peripheral subsystem
- `LEF_GENERATION_SOLUTIONS.md` - Alternative solutions (if this doesn't work)

---

## 🎉 Summary

**Manual fix (current session):**
```tcl
read_physical -lef tech_overlay_overlap.lef
write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef
```

**Automatic (future runs):**
- Just use the normal flow - overlay is auto-loaded by setup scripts!

**Safe:** Original PDK files are NOT modified. ✅
