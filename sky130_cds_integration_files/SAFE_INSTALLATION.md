# SAFE Installation Guide - Avoid Overwriting Important Files

This guide shows you **exactly** what gets copied and how to **safely** install the integration package without overwriting important sky130_cds files.

---

## ⚠️ Potential Conflicts

### Files That WILL Be Overwritten (If They Exist)

The following locations will be overwritten if they already exist in sky130_cds:

```
sky130_cds/
├── Makefile                           # ⚠️ Might overwrite
└── synth/
    └── hdl/                           # ⚠️ Might overwrite contents
        └── (any existing directories)
```

### Files That Are SAFE to Overwrite

These are **NEW files** that don't exist in standard sky130_cds:

```
✅ SAFE - These don't exist in standard sky130_cds:
├── synth/
│   ├── genus_script_rv32im.tcl       # ✅ New
│   ├── genus_script_periph.tcl       # ✅ New
│   ├── genus_script_soc.tcl          # ✅ New
│   └── constraints/
│       ├── rv32im_integrated.sdc     # ✅ New
│       ├── peripheral_subsystem.sdc  # ✅ New
│       └── soc_integrated.sdc        # ✅ New
│
└── pnr/
    ├── setup_rv32im.tcl              # ✅ New
    ├── setup_periph.tcl              # ✅ New
    ├── setup_soc.tcl                 # ✅ New
    ├── Makefile.rv32im               # ✅ New
    ├── Makefile.periph               # ✅ New
    ├── Makefile.soc                  # ✅ New
    └── SCRIPTS/
        ├── init_rv32im.tcl           # ✅ New
        ├── init_periph.tcl           # ✅ New
        ├── init_soc.tcl              # ✅ New
        ├── signoff_rv32im.tcl        # ✅ New
        ├── signoff_periph.tcl        # ✅ New
        └── signoff_soc.tcl           # ✅ New
```

---

## 🛡️ SAFE Installation Method (Recommended)

### Method 1: Selective Copy (Safest)

Copy only the NEW files, avoiding potential conflicts:

```bash
cd sky130_cds

# Create directories
mkdir -p synth/hdl synth/constraints pnr/SCRIPTS

# Copy synthesis scripts (NEW files - safe)
cp /path/to/sky130_cds_integration_files/synth/genus_script_rv32im.tcl synth/
cp /path/to/sky130_cds_integration_files/synth/genus_script_periph.tcl synth/
cp /path/to/sky130_cds_integration_files/synth/genus_script_soc.tcl synth/

# Copy constraints (NEW files - safe)
cp /path/to/sky130_cds_integration_files/synth/constraints/*.sdc synth/constraints/

# Copy RTL (might overwrite - check first!)
# First, backup existing hdl/ if it has important files:
if [ -d synth/hdl ] && [ "$(ls -A synth/hdl)" ]; then
    echo "Backing up existing hdl/ directory..."
    mv synth/hdl synth/hdl.backup.$(date +%Y%m%d_%H%M%S)
fi

cp -r /path/to/sky130_cds_integration_files/synth/hdl synth/

# Copy P&R scripts (NEW files - safe)
cp /path/to/sky130_cds_integration_files/pnr/setup_*.tcl pnr/
cp /path/to/sky130_cds_integration_files/pnr/Makefile.* pnr/
cp /path/to/sky130_cds_integration_files/pnr/SCRIPTS/init_*.tcl pnr/SCRIPTS/
cp /path/to/sky130_cds_integration_files/pnr/SCRIPTS/signoff_*.tcl pnr/SCRIPTS/

# Copy master Makefile (might overwrite - check first!)
if [ -f Makefile ]; then
    echo "Backing up existing Makefile..."
    mv Makefile Makefile.backup.$(date +%Y%m%d_%H%M%S)
fi

cp /path/to/sky130_cds_integration_files/Makefile .

echo "✓ Safe installation complete!"
```

### Method 2: Backup First (Safe)

Backup anything that might get overwritten:

```bash
cd sky130_cds

# Backup potentially conflicting files
if [ -f Makefile ]; then
    cp Makefile Makefile.original.backup
fi

if [ -d synth/hdl ] && [ "$(ls -A synth/hdl)" ]; then
    cp -r synth/hdl synth/hdl.original.backup
fi

# Now safe to copy everything
cp -r /path/to/sky130_cds_integration_files/* .

echo "✓ Installation complete (originals backed up)"
```

### Method 3: Fresh Clone (Safest for Clean Start)

If you haven't modified sky130_cds yet:

```bash
# Clone fresh sky130_cds
git clone https://github.com/stineje/sky130_cds.git
cd sky130_cds
git submodule update --init --recursive

# Now safe to copy everything
cp -r /path/to/sky130_cds_integration_files/* .

echo "✓ Installation complete!"
```

---

## 🔍 What's in Standard sky130_cds That Might Conflict

### Makefile

**Standard sky130_cds** has a Makefile for the example design (mult_seq).

**Our package** has a Makefile for hierarchical SOC build.

**Solution:**
- If you've modified the standard Makefile, back it up first
- If it's untouched, safe to replace

### synth/hdl/

**Standard sky130_cds** might have example designs like:
```
synth/hdl/
├── mult_seq.v        # Example multiplier design
└── (other examples)
```

**Our package** has:
```
synth/hdl/
├── core_macro/       # Your RTL
├── mdu_macro/        # Your RTL
└── ... (all your macros)
```

**Solution:**
- Back up example designs if you need them
- Or use Method 1 (selective copy) to avoid this directory

### Other Directories

These are **SAFE** - standard sky130_cds doesn't have these files:
- ✅ `synth/genus_script_rv32im.tcl` (doesn't exist in standard)
- ✅ `pnr/Makefile.rv32im` (doesn't exist in standard)
- ✅ All other integration files (all new)

---

## ✅ Pre-Installation Checklist

Before copying, check:

```bash
cd sky130_cds

# 1. Check if Makefile exists and if you modified it
ls -l Makefile
git diff Makefile   # Shows if you changed it

# 2. Check what's in synth/hdl/
ls -la synth/hdl/

# 3. Check if any of our files already exist (shouldn't in fresh clone)
ls synth/genus_script_rv32im.tcl 2>/dev/null && echo "Already exists!" || echo "Safe to copy"
```

**If you get "Already exists!" for integration files:**
- You may have already installed the package
- Or another integration attempt happened
- Backup and proceed carefully

---

## 🎯 Recommended Installation

For **most users**, this is the safest approach:

```bash
# 1. Clone fresh sky130_cds (if you haven't started work yet)
git clone https://github.com/stineje/sky130_cds.git
cd sky130_cds
git submodule update --init --recursive

# 2. Copy entire integration package (safe on fresh clone)
cp -r /path/to/sky130_cds_integration_files/* .

# 3. Verify
ls synth/hdl/core_macro/     # Should show your RTL
ls synth/genus_script_rv32im.tcl  # Should exist
ls pnr/Makefile.rv32im       # Should exist

# 4. Ready to build!
make all
```

---

## 🔧 What Each Installation Method Does

### Method 1: Selective Copy
- **Pros**: Most control, won't overwrite anything
- **Cons**: More commands, easy to miss files
- **Best for**: Existing sky130_cds with important files

### Method 2: Backup + Full Copy
- **Pros**: Simple, safe with backups
- **Cons**: Creates backup files
- **Best for**: Modified sky130_cds you want to preserve

### Method 3: Fresh Clone + Copy
- **Pros**: Cleanest, simplest, guaranteed to work
- **Cons**: Loses any previous work
- **Best for**: Starting fresh (recommended!)

---

## ⚠️ Common Issues

### Issue 1: "Directory not empty" error

**Cause:** `synth/hdl/` already has files

**Solution:**
```bash
# Back up existing hdl/
mv synth/hdl synth/hdl.backup
# Then copy
cp -r sky130_cds_integration_files/synth/hdl synth/
```

### Issue 2: "File exists" error

**Cause:** File already there

**Solution:**
```bash
# Back up the file
mv <file> <file>.backup
# Then copy
cp sky130_cds_integration_files/<file> <destination>
```

### Issue 3: Lost standard examples

**Cause:** Overwrote synth/hdl/ with examples

**Solution:**
```bash
# Restore from git
cd sky130_cds
git checkout synth/hdl/mult_seq.v   # Restore specific example
# Or restore all examples:
git checkout synth/hdl/
# Then manually copy our RTL:
cp -r ../sky130_cds_integration_files/synth/hdl/* synth/hdl/
```

---

## 📋 Installation Summary

| Method | Safety | Simplicity | Best For |
|--------|--------|------------|----------|
| **Fresh Clone + Copy** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Starting fresh |
| **Backup + Full Copy** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Modified sky130_cds |
| **Selective Copy** | ⭐⭐⭐⭐⭐ | ⭐⭐ | Advanced users |

---

## ✅ Verification After Installation

After installation, verify everything is in place:

```bash
cd sky130_cds

echo "Checking RTL files..."
[ -f synth/hdl/core_macro/core_macro.v ] && echo "✓ core_macro RTL" || echo "✗ Missing core_macro RTL"
[ -f synth/hdl/mdu_macro/mdu_macro.v ] && echo "✓ mdu_macro RTL" || echo "✗ Missing mdu_macro RTL"

echo "Checking synthesis scripts..."
[ -f synth/genus_script_rv32im.tcl ] && echo "✓ RV32IM synthesis" || echo "✗ Missing RV32IM synthesis"
[ -f synth/genus_script_soc.tcl ] && echo "✓ SOC synthesis" || echo "✗ Missing SOC synthesis"

echo "Checking P&R scripts..."
[ -f pnr/Makefile.rv32im ] && echo "✓ RV32IM Makefile" || echo "✗ Missing RV32IM Makefile"
[ -f pnr/Makefile.soc ] && echo "✓ SOC Makefile" || echo "✗ Missing SOC Makefile"

echo "Checking master Makefile..."
[ -f Makefile ] && echo "✓ Master Makefile" || echo "✗ Missing Master Makefile"

echo ""
echo "If all show ✓, installation is complete!"
```

---

## 🎯 Recommended: Use Fresh Clone

**For cleanest installation:**

```bash
# 1. Fresh start
git clone https://github.com/stineje/sky130_cds.git sky130_cds_rv32imz
cd sky130_cds_rv32imz
git submodule update --init --recursive

# 2. Copy integration package
cp -r ../sky130_cds_integration_files/* .

# 3. Build!
make all
```

This avoids **ALL** conflicts and gives you a clean, working system!

---

## Summary

✅ **Safest method**: Fresh clone + full copy
✅ **If you have work to preserve**: Backup + full copy
✅ **For maximum control**: Selective copy

The integration package is designed to work with **clean sky130_cds**, so fresh clone is recommended!
