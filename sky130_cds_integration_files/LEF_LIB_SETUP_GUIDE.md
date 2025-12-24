# 🔧 LEF/LIB File Setup for Integration Scripts

## ❌ Common Error

```
Error: Undefined pin layer detected. [PHYS-148] [read_physical]
The layer 'met1' referenced in pin 'X' in macro 'sky130_osu_sc_18T_ms__addf_1' is not found in the database.
```

**Cause:** LEF files are missing or incomplete in the expected location.

---

## ✅ Quick Fix

### Step 1: Find Where the Script Looks for LEF Files

The integration scripts expect LEF files at:
```
sky130_cds/sky130_osu_sc_t18/
├── lib/
│   └── sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib (or similar)
└── lef/
    ├── sky130_osu_sc_18T_tech.lef (REQUIRED - defines layers)
    └── sky130_osu_sc_18T.lef (REQUIRED - defines cells)
```

### Step 2: Check if Directory Exists

```bash
cd sky130_cds
ls -la sky130_osu_sc_t18/

# If it doesn't exist:
mkdir -p sky130_osu_sc_t18/lib
mkdir -p sky130_osu_sc_t18/lef
```

### Step 3: Copy LEF Files from Your PDK or Existing Setup

**Option A: From your leaf macro builds (if you used sky130_fd_sc_hd)**

```bash
# If you built leaf macros with sky130_fd_sc_hd, you probably have LEF files there
# Find them:
find . -name "*tech*.lef" -o -name "*sky130*.lef" | head -10

# Copy to integration location:
cp /path/to/sky130_fd_sc_hd/techlef/*.tlef sky130_osu_sc_t18/lef/sky130_osu_sc_18T_tech.lef
cp /path/to/sky130_fd_sc_hd/lef/*.lef sky130_osu_sc_t18/lef/sky130_osu_sc_18T.lef
```

**Option B: Use OSU standard cells (if available)**

```bash
# If you have OSU standard cell library:
cp /path/to/osu/sky130_osu_sc_18T/lef/sky130_osu_sc_18T_tech.lef sky130_osu_sc_t18/lef/
cp /path/to/osu/sky130_osu_sc_18T/lef/sky130_osu_sc_18T.lef sky130_osu_sc_t18/lef/
cp /path/to/osu/sky130_osu_sc_18T/lib/*.lib sky130_osu_sc_t18/lib/
```

**Option C: Create symlinks to existing LEF files**

```bash
# If LEF files exist elsewhere, create symlinks:
ln -s /path/to/actual/lef/directory sky130_cds/sky130_osu_sc_t18
```

---

## 🔍 Verify Setup

After copying files, verify:

```bash
cd sky130_cds/sky130_osu_sc_t18

# Check LEF files exist:
ls -lh lef/*.lef
# Should show:
# sky130_osu_sc_18T_tech.lef (tech LEF - defines layers)
# sky130_osu_sc_18T.lef (cell LEF - defines standard cells)

# Check lib files exist:
ls -lh lib/*.lib
# Should show timing library (.lib or .ccs.lib)
```

---

## 🎯 Alternative: Use Same Library as Leaf Macros

**RECOMMENDED:** If you built leaf macros with a specific library (e.g., `sky130_fd_sc_hd`), use the SAME library for integration!

### Update Integration Script to Use Your Library:

Edit `synth/genus_script_rv32im.tcl`, line 9:

```tcl
# OLD:
set LIB_PATH "../sky130_osu_sc_t18"

# NEW (if you used sky130_fd_sc_hd for leaf macros):
set LIB_PATH "../pdk/sky130A/libs.ref/sky130_fd_sc_hd"
```

Then update the library/LEF file names in the script to match your actual files.

---

## 🔧 What Each File Does

### Tech LEF (`*_tech.lef`)
- **Purpose:** Defines metal layers (met1, met2, etc.), vias, and technology rules
- **MUST load FIRST** - all other LEFs depend on these layer definitions
- **Critical:** Without this, you get "layer not found" errors

### Cell LEF (`*.lef`)
- **Purpose:** Defines standard cell physical abstracts (AND gates, buffers, etc.)
- **MUST load AFTER tech LEF**
- **Contains:** Pin locations, cell boundaries, obstruction layers

### Timing Library (`*.lib` or `*.ccs.lib`)
- **Purpose:** Timing characterization for standard cells
- **Used for:** Synthesis timing optimization
- **Variants:** TT (typical), FF (fast), SS (slow)

---

## ✅ After Setup, Test:

```bash
cd sky130_cds/synth

# Run integration synthesis:
genus -batch -files genus_script_rv32im.tcl

# If successful, you should see:
# ✓ Loaded library: sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib
# ✓ Tech LEF loaded: sky130_osu_sc_18T_tech.lef
# ✓ Cell LEF loaded: sky130_osu_sc_18T.lef
```

---

## 🆘 Still Getting Errors?

### Error: "No timing library found"

```bash
# Check what lib files you actually have:
find .. -name "*.lib" -o -name "*.ccs.lib" | grep sky130

# Then update genus_script_rv32im.tcl with actual file names
```

### Error: "No technology LEF found"

```bash
# Check what LEF files you have:
find .. -name "*tech*.lef" -o -name "*.tlef"

# Copy or symlink to expected location
```

### Error: "Layer 'met1' not found"

**Cause:** Tech LEF didn't load or is incomplete

**Fix:**
1. Make sure tech LEF exists and loads FIRST
2. Check tech LEF file contains layer definitions (should have "LAYER met1" etc.)
3. Try using the tech LEF from sky130_fd_sc_hd PDK

---

## 📝 Summary

**Problem:** Integration scripts can't find LEF/lib files

**Solutions:**
1. Copy LEF files from your PDK to `sky130_osu_sc_t18/lef/`
2. OR change `LIB_PATH` to point to your existing library
3. OR create symlinks to existing library location

**Critical:** Tech LEF must load before cell LEF, and must define all metal layers!

---

## 🎯 Recommended Approach

**Use the same library for both leaf macros AND integration:**

1. If you built leaf macros with `sky130_fd_sc_hd` → use `sky130_fd_sc_hd` for integration
2. Update `LIB_PATH` in integration scripts to match
3. No file copying needed!

This ensures consistency and avoids library mixing issues.
