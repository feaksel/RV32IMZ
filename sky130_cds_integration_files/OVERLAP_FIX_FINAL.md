# 🔧 OVERLAP Layer Error - FINAL SOLUTION

## The Problem

When you try to use `write_lef_abstract`, you get this error:
```
**ERROR: (IMPLF-109): Cannot create OBS on overlap layer for rectilinear
partition 'mdu_macro' because there is no overlap layer defined
```

## Why Our Previous Attempt Failed

We tried to load OVERLAP as a separate overlay LEF file, but Innovus said:
```
**WARN: (IMPLF-18): The layer 'OVERLAP' defined in this LEF file is ignored.
It should be added to the first LEF file (technology LEF).
```

**The OVERLAP layer MUST be in the FIRST (technology) LEF file!**

---

## ✅ THE REAL SOLUTION

Create a **modified copy** of the technology LEF file with OVERLAP layer included.

### Step 1: Exit Your Current Innovus Session

```bash
# At innovus prompt:
exit
```

### Step 2: Navigate to P&R Directory

```bash
cd ~/Documents/Masaustu/FurkanEmir/sky130_cds/pnr
# Or wherever your sky130_cds/pnr directory is
```

### Step 3: Run the Script to Create Modified Tech LEF

```bash
chmod +x add_overlap_to_tech_lef.sh
./add_overlap_to_tech_lef.sh
```

This script will:
1. Copy the original tech LEF
2. Add OVERLAP layer definition to the copy
3. Create `sky130_osu_sc_18T_tech_with_overlap.lef`

**Your original PDK file is NOT modified!** ✅

### Step 4: Restart Innovus

Now the setup scripts will automatically use the modified tech LEF:

```bash
# Option A: Use Makefile (automatic)
make -f Makefile.rv32im init

# Option B: Use Innovus directly
innovus -init SCRIPTS/init_rv32im.tcl
```

### Step 5: Generate LEF (Will Work Now!)

```tcl
# After completing P&R steps (init, place, route)...
write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef
```

**No OVERLAP error!** ✅

---

## 🚨 If You Can't Run the Script

If the script doesn't work (e.g., original tech LEF path is different), you can create the modified tech LEF manually:

### Manual Method:

```bash
cd ~/Documents/Masaustu/FurkanEmir/sky130_cds/pnr

# 1. Copy original tech LEF
cp ../sky130_osu_sc_t18/lef/sky130_osu_sc_18T_tech.lef \
   sky130_osu_sc_18T_tech_with_overlap.lef

# 2. Edit the file
nano sky130_osu_sc_18T_tech_with_overlap.lef

# 3. Find the line "END LIBRARY" at the end
# 4. ADD these lines BEFORE "END LIBRARY":

# ============================================================================
# OVERLAP Layer - Required for write_lef_abstract
# ============================================================================

LAYER OVERLAP
  TYPE OVERLAP ;
END OVERLAP

# 5. Save and exit (Ctrl+X, Y, Enter)
```

---

## 🔍 How to Verify It's Working

When you start Innovus with the setup scripts, you should see:

```
==> Loading technology LEF files...
    ✓ Using tech LEF with OVERLAP layer
```

If you see this warning instead:
```
WARNING: Modified tech LEF not found!
Run: ./add_overlap_to_tech_lef.sh to create it
```

Then the modified tech LEF wasn't created - run the script or use the manual method.

---

## 📂 File Structure After Fix

```
sky130_cds/pnr/
├── add_overlap_to_tech_lef.sh              # Script to create modified tech LEF
├── sky130_osu_sc_18T_tech_with_overlap.lef # ← MODIFIED tech LEF (created by script)
├── tech_overlay_overlap.lef                # (old approach - not used)
├── setup_rv32im.tcl                        # Updated to use modified tech LEF
├── setup_soc.tcl                           # Updated to use modified tech LEF
├── setup_periph.tcl                        # Updated to use modified tech LEF
└── SCRIPTS/
    ├── init_rv32im.tcl
    ├── signoff_rv32im.tcl                  # Uses write_lef_abstract -5.7
    └── ...
```

---

## 🎯 What Changed in the Modified Tech LEF

The script adds these lines before `END LIBRARY`:

```lef
# ============================================================================
# OVERLAP Layer - Required for write_lef_abstract
# Added automatically - not part of original PDK
# ============================================================================

LAYER OVERLAP
  TYPE OVERLAP ;
END OVERLAP
```

That's it! Just 5 lines. ✅

---

## ✅ Summary

**Problem:** OVERLAP layer must be in the FIRST (technology) LEF file

**Solution:** Create a modified tech LEF with OVERLAP included

**How:**
1. Exit Innovus
2. Run `./add_overlap_to_tech_lef.sh` in the pnr directory
3. Restart Innovus (setup scripts auto-use modified tech LEF)
4. `write_lef_abstract` will work!

**Safe:** Original PDK not modified - we create a copy ✅

---

## 🆘 Troubleshooting

**Q: Script says "Original tech LEF not found"**
A: Edit `add_overlap_to_tech_lef.sh` and fix the path to your tech LEF file (line 13)

**Q: Still getting OVERLAP error after running script**
A: Check that `sky130_osu_sc_18T_tech_with_overlap.lef` exists in the pnr directory

**Q: Want to verify OVERLAP is in the file**
A: `grep -A2 "LAYER OVERLAP" sky130_osu_sc_18T_tech_with_overlap.lef`

**Q: Can I use the original tech LEF again?**
A: Yes! Just delete `sky130_osu_sc_18T_tech_with_overlap.lef` and the setup scripts will fall back to the original (but write_lef_abstract will fail)

---

## 🎉 That's It!

This is the **ACTUAL** fix that will work with your Innovus version.

The key insight: **OVERLAP must be in the technology LEF file itself**, not loaded as a separate overlay.
