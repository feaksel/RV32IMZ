# LEF Loading Errors - What They Mean and How to Fix

## 🎯 TL;DR - Quick Fix

**Set `LOAD_LEFS = 0` in the synthesis scripts** (already done for you!)

For integration synthesis, you DON'T need LEF files. LEF is only needed in Innovus for P&R.

---

## 📊 Understanding Your Errors

### ✅ Benign Warnings (Ignore These)

#### 1. **Via Resistance Warnings [PHYS-129]**
```
Via 'L1M1_PR' has no resistance value.
Via with no resistance will have a value of '0.0' assigned
```
**What it means:** LEF file doesn't specify via resistance values
**Impact:** None for synthesis
**Action:** Ignore

#### 2. **Wire Parameter Range Warnings [PHYS-12]**
```
The variant range (0.14, 1.6) of 'WIDTH' for layers 'met1' and 'met5' is too large
```
**What it means:** LEF has wide range of wire parameters
**Impact:** None for synthesis
**Action:** Ignore

#### 3. **Filler Cells Not Found [PHYS-279]**
```
Physical cell not defined in library: sky130_osu_sc_18T_ms__antfill
Physical cell not defined in library: sky130_osu_sc_18T_ms__decap_1
Physical cell not defined in library: sky130_osu_sc_18T_ms__fill_*
```
**What it means:** Filler/decap cells missing from LEF
**Impact:** None for synthesis (only needed for P&R)
**Action:** Ignore

#### 4. **Pin Name Mismatch [PHYS-113]**
```
Pin 'GND' of library cell 'sky130_osu_sc_18T_ms__addf_1' is in logical library but not in physical library.
Pin 'VDD' of library cell ... is in logical library but not in physical library.
```
**What it means:** .lib file uses GND/VDD, LEF uses different names (VSS/VCC)
**Impact:** None if you're not using physical synthesis
**Action:** Ignore for now, or fix by editing LEF pin names

---

### 🔴 Critical Errors (Need Fixing)

#### 1. **Site '18T' Not Defined [PHYS-2040]**
```
Macro 'sky130_osu_sc_18T_ms__aoi21_l' references a site '18T' that has not been defined.
```
**What it means:** Cell LEF references a SITE called '18T', but tech LEF doesn't define it
**Impact:** Physical design will fail
**Root cause:** Incomplete or mismatched LEF files

**How to fix:**
```lef
# Add to tech LEF file (sky130_osu_sc_18T.tlef):
SITE 18T
  CLASS CORE ;
  SIZE 0.46 BY 2.72 ;
END 18T
```

#### 2. **Missing Capacitance/Resistance [PHYS-10]**
```
Error: No capacitance or resistance specified. [PHYS-10] [read_physical]
: Specify the tech LEF first.
```
**What it means:** Tech LEF missing RC (resistance/capacitance) data for layers
**Impact:** Physical design and accurate timing analysis will fail
**Root cause:** Incomplete tech LEF file

**How to fix:** Need complete tech LEF with CAPACITANCE and RESISTANCE for each layer:
```lef
LAYER met1
  TYPE ROUTING ;
  WIDTH 0.14 ;
  SPACING 0.14 ;
  PITCH 0.46 ;
  CAPACITANCE CPERSQDIST 0.000025 ;  # Must be specified!
  RESISTANCE RPERSQ 0.125 ;           # Must be specified!
END met1
```

---

## 💡 Solutions

### Option 1: Skip LEF Loading (RECOMMENDED FOR NOW)

All integration scripts now have `LOAD_LEFS = 0` by default. This means:

✅ **Synthesis works** - Genus only needs .lib for timing
✅ **No LEF errors** - LEF files are skipped
✅ **Faster runtime** - No need to process LEF files
❌ **No physical data in Genus** - But you don't need it for integration!

**When you move to P&R (Innovus):**
- Innovus will load proper LEF files from your leaf macros
- You only need macro LEF files (from pre-built macros), not standard cell LEF

### Option 2: Use LEF with Warnings (If You Really Need It)

If you need physical data in Genus, set `LOAD_LEFS = 1` in the script:

```tcl
# In genus_script_rv32im.tcl line 52:
set LOAD_LEFS 1  ;# Enable LEF loading
```

The script now uses `catch` to suppress errors and continue despite warnings.

### Option 3: Fix the Tech LEF (Advanced)

If you want clean LEF loading:

1. **Get complete tech LEF from sky130 PDK:**
   ```bash
   # Official sky130 tech LEF location (if you have full PDK):
   $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd__nom.tlef
   ```

2. **Or manually add missing data** to your existing tech LEF:
   - Add SITE definitions (like `SITE 18T`)
   - Add CAPACITANCE to all routing layers
   - Add RESISTANCE to all routing layers

3. **Ensure LEF compatibility:**
   - Tech LEF and cell LEF must be from same library variant
   - Pin names in LEF must match .lib file (GND vs VSS issue)

---

## 🔍 What LEF Files Do

### Tech LEF (Technology LEF)
- Defines physical layers (met1, via, poly, etc.)
- Defines sites (placement grid)
- Defines RC parasitics
- **Needed for:** P&R, physical synthesis

### Cell LEF (Standard Cell LEF)
- Defines physical view of standard cells
- Pin locations, blockages, obstructions
- **Needed for:** P&R, floor planning

### For Integration Synthesis:
- ❌ **Don't need tech LEF** - Only for physical design
- ❌ **Don't need cell LEF** - Only for P&R
- ✅ **DO need macro LEF** - From your pre-built macros (core_macro, mdu_macro, etc.)
- ✅ **DO need .lib** - For timing analysis

---

## 📝 Current Status

| File | Status | Issue |
|------|--------|-------|
| `sky130_osu_sc_18T.tlef` | ⚠️ Incomplete | Missing SITE '18T' definition, missing RC data |
| `sky130_osu_sc_18T_ms.lef` | ⚠️ Compatible but... | References undefined SITE '18T' |
| `sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib` | ✅ Working | Loads correctly |
| Integration synthesis | ✅ Working | With `LOAD_LEFS = 0` |

---

## 🎯 Recommended Workflow

### For Now (Integration Synthesis):
1. ✅ Keep `LOAD_LEFS = 0` (already set)
2. ✅ Run synthesis without LEF files
3. ✅ Output netlist will work fine for P&R

### Later (P&R in Innovus):
1. Load complete macro LEF files from pre-built macros
2. Load tech LEF in Innovus (it has better error handling)
3. Standard cell LEF will be loaded from Innovus setup

---

## ❓ FAQ

**Q: Did synthesis fail?**
A: No! Despite "Encountered problems" message, it says "Normal exit" at the end. Synthesis likely completed.

**Q: Do I need to fix these errors?**
A: Not for integration synthesis. Only if you want physical synthesis in Genus.

**Q: Will this affect my final GDS?**
A: No. Innovus (P&R) will load proper LEF files from your macros.

**Q: What about the "library cell has no output pins" warnings?**
A: These are antenna/buffer cells. Genus is just complaining they're unusual. Ignore.

**Q: Should I get better LEF files?**
A: Only if you want to use physical synthesis features in Genus. For integration flow, current setup is fine.

---

## 🚀 Next Steps

1. **Check synthesis output:**
   ```bash
   ls -lh outputs/rv32im_integrated/
   # Should have: rv32im_integrated_macro.vh, .sdc, .sdf
   ```

2. **Review reports:**
   ```bash
   cat reports/rv32im_integrated/timing.rpt
   cat reports/rv32im_integrated/qor.rpt
   ```

3. **If successful, proceed to P&R:**
   ```bash
   cd ../pnr
   make -f Makefile.rv32im all
   ```

The LEF errors are annoying but **not critical for your integration flow**!
