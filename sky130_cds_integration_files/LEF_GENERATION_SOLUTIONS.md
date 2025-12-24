# 🔧 LEF Generation Error Fix - OVERLAP Layer Issue

## The Problem

When running `write_lef_abstract`, Innovus gives this error:

```
**ERROR: (IMPLF-109): Cannot create OBS on overlap layer for rectilinear
partition 'mdu_macro' because there is no overlap layer defined
in any LEF file.
```

**Why?** LEF 5.7+ format requires an OVERLAP layer in the technology LEF for complex obstruction generation, but the SkyWater PDK tech LEF doesn't define it.

---

## ✅ Solution 1: Skip Obstruction Generation (FASTEST & SAFEST)

Generate LEF without detailed obstructions (abstracts will still work for integration):

```tcl
# In signoff script, replace:
# write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef

# With:
write_lef_abstract -5.7 -noOBS outputs/mdu_macro/mdu_macro.lef
```

**Pros:**
- ✅ No tech LEF modification needed
- ✅ Fast generation
- ✅ Works for hierarchical integration (P&R tools can see macro boundaries)

**Cons:**
- ⚠️ Less accurate routing blockages (usually not a problem for macros)

---

## ✅ Solution 2: Use LEF 5.6 Format (COMPATIBLE)

LEF 5.6 doesn't require OVERLAP layer:

```tcl
# Use LEF 5.6 instead of 5.7:
write_lef_abstract -5.6 outputs/mdu_macro/mdu_macro.lef
```

**Pros:**
- ✅ No tech LEF modification
- ✅ Includes obstructions
- ✅ Compatible with most tools

**Cons:**
- ⚠️ Older format (but widely supported)

---

## ✅ Solution 3: Use LEF 5.8 with `-specifyTopLayerAsPins` (MODERN)

LEF 5.8 has better handling:

```tcl
write_lef_abstract -5.8 -specifyTopLayerAsPins outputs/mdu_macro/mdu_macro.lef
```

**Pros:**
- ✅ Modern format
- ✅ Better pin placement
- ✅ May avoid OVERLAP issue

**Cons:**
- ⚠️ Tool version dependent

---

## ✅ Solution 4: Create Temporary OVERLAP Layer Definition (SAFE)

Instead of modifying the original PDK LEF, create a **custom tech LEF overlay**:

### Step 1: Create overlay file

```bash
# Create a tech LEF overlay with OVERLAP definition
cat > sky130_cds/pnr/tech_lef_overlay.lef << 'EOF'
VERSION 5.7 ;
BUSBITCHARS "[]" ;
DIVIDERCHAR "/" ;

# Add OVERLAP layer definition
LAYER OVERLAP
  TYPE OVERLAP ;
END OVERLAP

END LIBRARY
EOF
```

### Step 2: Load it AFTER standard tech LEF

In your P&R setup script (e.g., `setup_rv32im.tcl`), modify the LEF reading order:

```tcl
# Read standard tech LEF first
read_physical -lef "${LIB_PATH}/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "${LIB_PATH}/lef/sky130_osu_sc_18T.lef"

# Then read overlay to add OVERLAP layer
read_physical -lef "tech_lef_overlay.lef"

# Now read macro LEFs
read_physical -lef "${MACRO_DIR}/core_macro/core_macro.lef"
read_physical -lef "${MACRO_DIR}/mdu_macro/mdu_macro.lef"
```

### Step 3: Generate LEF normally

```tcl
write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef
```

**Pros:**
- ✅ Original PDK LEFs unchanged
- ✅ Full obstruction generation
- ✅ LEF 5.7 compatibility

**Cons:**
- ⚠️ Requires loading extra file

---

## ✅ Solution 5: Generate Abstract with Simpler Command (MINIMAL)

Use the most basic LEF generation:

```tcl
# Minimal LEF generation (works with any tech LEF)
write_lef_abstract outputs/mdu_macro/mdu_macro.lef
```

This auto-selects a compatible LEF version based on what's available.

**Pros:**
- ✅ Most compatible
- ✅ Automatic version selection

---

## 🎯 RECOMMENDED Solution

**For your case, use Solution 1 + Solution 2 combined:**

### Update all signoff scripts to use:

```tcl
# Try LEF 5.6 with obstructions first
if {[catch {
    write_lef_abstract -5.6 outputs/mdu_macro/mdu_macro.lef
    puts "    ✓ LEF generated with LEF 5.6 format"
} err]} {
    # Fallback to 5.7 without obstructions if 5.6 fails
    write_lef_abstract -5.7 -noOBS outputs/mdu_macro/mdu_macro.lef
    puts "    ✓ LEF generated with LEF 5.7 format (no OBS)"
}
```

This gives you:
1. Best compatibility (LEF 5.6)
2. Includes obstructions if possible
3. Fallback option if needed
4. **NO modification of PDK LEF files!**

---

## 🔧 Where to Apply These Fixes

Update these files in your integration package:

### For RV32IM Integration:
`sky130_cds_integration_files/pnr/SCRIPTS/signoff_rv32im.tcl`

Change line ~77:
```tcl
# OLD:
write_lef_abstract -5.7 outputs/rv32im_integrated/rv32im_integrated_macro.lef

# NEW:
write_lef_abstract -5.6 outputs/rv32im_integrated/rv32im_integrated_macro.lef
```

### For SOC Integration:
`sky130_cds_integration_files/pnr/SCRIPTS/signoff_soc.tcl`

Change line ~77:
```tcl
# OLD:
write_lef_abstract -5.7 outputs/soc_integrated/rv32imz_soc_macro.lef

# NEW:
write_lef_abstract -5.6 outputs/soc_integrated/rv32imz_soc_macro.lef
```

### For Original Leaf Macro Scripts:
In each `distribution/rv32im_core_only/macros/*/scripts/*_pnr.tcl`, use LEF 5.6 or add `-noOBS` flag.

---

## 🎓 Technical Explanation

**What is the OVERLAP layer?**

The OVERLAP layer is a LEF construct used to define complex routing obstructions when macro boundaries have irregular shapes. LEF 5.7+ requires this layer definition for certain OBS (obstruction) generation modes.

**Why doesn't SkyWater PDK have it?**

Most PDKs don't define OVERLAP because:
1. It's optional for simple rectangular macros
2. LEF 5.6 and earlier don't need it
3. `-noOBS` option exists as workaround

**Is it dangerous to add?**

Not really, but you should avoid modifying original PDK files because:
- Updates would overwrite your changes
- Other users expect standard PDK
- Better to use overlays or alternative methods

---

## ✅ Quick Fix Command

If you're at the Innovus prompt right now, just run:

```tcl
write_lef_abstract -5.6 outputs/mdu_macro/mdu_macro.lef
```

This should work immediately without any LEF modifications! 🎉
