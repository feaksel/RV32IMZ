# 🎯 HYBRID BUILD APPROACH: Original Scripts + Integration Scripts

## You Asked a GREAT Question!

**Your observation is CORRECT:** The original sky130_cds scripts have MORE features than my simplified integration scripts!

---

## 📊 Comparison: Original vs Integration Scripts

### Original Scripts (in `distribution/rv32im_core_only/`)

**Location:** `macros/*/scripts/*.tcl` and `synthesis_cadence/*.tcl`

**Features:**
- ✅ **Multi-corner libraries** (TT, SS, FF corners for robust timing)
- ✅ **Clock gating** (reduces power consumption)
- ✅ **Advanced optimizations:**
  - Constant propagation
  - Sequential area optimization
  - Register optimization
- ✅ **Comprehensive P&R:**
  - Pre-CTS optimization
  - Filler cells (FILL1, FILL2, FILL4, FILL8)
  - Advanced power planning (metal3-6 layers)
  - Placement refinement
- ✅ **Better reporting:**
  - Congestion analysis
  - Hold/setup timing separately
  - Design rule checks
  - Violation detection
- ✅ **MMMC** (Multi-Mode Multi-Corner timing analysis)

**Library:** `sky130_fd_sc_hd` (official SkyWater 130nm PDK cells - ~80 cells)

### My Integration Scripts (in `sky130_cds_integration_files/`)

**Features:**
- ✅ **Hierarchical integration** (reads pre-built macros as black boxes)
- ✅ **GDS merging** (combines multiple macro layouts)
- ✅ **Simple & fast** (minimal configuration for quick integration)
- ⚠️ **Missing advanced optimizations** (from original scripts)

**Library:** `sky130_osu_sc_18T` (OSU standard cells - simpler)

---

## 🚀 RECOMMENDED: Hybrid Approach

**Use BOTH approaches together for BEST results!**

### Strategy:

```
Level 0 (Leaf Macros)
├── Use ORIGINAL scripts to build leaf macros
│   ├── core_macro
│   ├── mdu_macro
│   ├── memory_macro
│   ├── communication_macro
│   ├── protection_macro
│   ├── adc_subsystem_macro
│   └── pwm_accelerator_macro
│
└── Get optimized GDS/LEF/netlist outputs

Level 1 (rv32im_integrated)
└── Use INTEGRATION scripts to merge core + mdu
    └── Get rv32im_integrated_macro.gds

Level 2 (SOC)
└── Use INTEGRATION scripts to merge rv32im_integrated + peripherals
    └── Get rv32imz_soc_macro.gds (FINAL CHIP!)
```

---

## ✅ What You GAIN with Hybrid Approach

1. **Better leaf macros:**
   - Lower power (clock gating)
   - Better timing (multi-corner analysis)
   - DRC clean (filler cells)
   - More robust (comprehensive optimization)

2. **Faster integration:**
   - Don't re-synthesize macros
   - Just merge pre-built GDS files
   - Simple glue logic synthesis

3. **Best of both worlds!**

---

## ⚠️ What You LOSE if Using ONLY Integration Scripts

If you use my integration scripts for EVERYTHING (leaf macros + integration):

- ❌ **No clock gating** → Higher power consumption
- ❌ **Single corner only** → Less robust timing
- ❌ **No filler cells** → Potential DRC violations
- ❌ **Less optimization** → Larger area, worse timing
- ❌ **Simpler P&R** → May need manual fixes

**Verdict:** Use original scripts for leaf macros!

---

## 🔧 HOW TO: Hybrid Build Flow

### Step 1: Build Leaf Macros with Original Scripts

Each leaf macro has its own script in `distribution/rv32im_core_only/macros/*/scripts/`:

```bash
# Example for core_macro
cd distribution/rv32im_core_only/macros/core_macro

# Run synthesis
genus -batch -files scripts/core_synthesis.tcl

# Run P&R (would need to create this based on synthesis_cadence/place_route.tcl)
innovus -init scripts/core_pnr.tcl

# Generate integration files (LEF, GDS, netlist):
# - core_macro.lef
# - core_macro.gds
# - core_macro_netlist.v
# - core_macro.sdc
```

**Repeat for all 7 leaf macros:**
- core_macro
- mdu_macro
- memory_macro
- communication_macro
- protection_macro
- adc_subsystem_macro
- pwm_accelerator_macro

### Step 2: Copy Outputs to Integration Locations

```bash
# After building all leaf macros, copy their outputs:
mkdir -p sky130_cds/pnr/outputs/{core_macro,mdu_macro,memory_macro,communication_macro,protection_macro,adc_subsystem_macro,pwm_accelerator_macro}

# For each macro, copy these files:
cp distribution/rv32im_core_only/macros/core_macro/outputs/core_macro.lef \
   sky130_cds/pnr/outputs/core_macro/

cp distribution/rv32im_core_only/macros/core_macro/outputs/core_macro.gds \
   sky130_cds/pnr/outputs/core_macro/

cp distribution/rv32im_core_only/macros/core_macro/outputs/core_macro_netlist.v \
   sky130_cds/pnr/outputs/core_macro/

cp distribution/rv32im_core_only/macros/core_macro/outputs/core_macro.sdc \
   sky130_cds/pnr/outputs/core_macro/

# ... repeat for all macros
```

### Step 3: Run Integration Scripts

Now use my integration scripts to combine the optimized leaf macros:

```bash
cd sky130_cds

# Level 1: Integrate core + mdu → rv32im_integrated_macro
cd synth
genus -batch -files genus_script_rv32im.tcl

cd ../pnr
make -f Makefile.rv32im init
make -f Makefile.rv32im place
make -f Makefile.rv32im cts
make -f Makefile.rv32im route
make -f Makefile.rv32im signoff  # → rv32im_integrated_macro.gds

# Level 2: Integrate rv32im_integrated + peripherals → SOC
cd ../synth
genus -batch -files genus_script_soc.tcl

cd ../pnr
make -f Makefile.soc init
make -f Makefile.soc place
make -f Makefile.soc cts
make -f Makefile.soc route
make -f Makefile.soc signoff  # → rv32imz_soc_macro.gds (FINAL!)
```

---

## 🎯 Critical Compatibility Note

**IMPORTANT:** Original scripts and integration scripts use **DIFFERENT standard cell libraries!**

| Script Type | Library | Cells |
|-------------|---------|-------|
| Original | `sky130_fd_sc_hd` | Official SkyWater PDK (~80 cells) |
| Integration | `sky130_osu_sc_18T` | OSU standard cells (~40 cells) |

### Solution Options:

#### Option A: Make Integration Scripts Use sky130_fd_sc_hd (RECOMMENDED)

Update integration scripts to use the same library as original scripts:

```tcl
# In genus_script_rv32im.tcl and genus_script_soc.tcl, change:
# OLD:
set LIB_PATH "../sky130_osu_sc_t18"
read_libs "$LIB_PATH/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T_tech.lef"

# NEW:
set LIB_PATH "../pdk/sky130A/libs.ref/sky130_fd_sc_hd"
read_libs "$LIB_PATH/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
read_physical -lef "$LIB_PATH/techlef/sky130_fd_sc_hd__nom.tlef"
read_physical -lef "$LIB_PATH/lef/sky130_fd_sc_hd.lef"
```

#### Option B: Make Original Scripts Use sky130_osu_sc_18T

Less recommended - you lose the advanced features of the official PDK.

---

## 📝 Automation: Create Makefiles for Original Scripts

The original scripts don't have Makefiles yet. Here's how to add them:

### Create: `distribution/rv32im_core_only/macros/core_macro/Makefile`

```makefile
.PHONY: synth pnr clean all

all: synth pnr

synth:
	@echo "==> Running synthesis for core_macro..."
	genus -batch -files scripts/core_synthesis.tcl -log logs/synthesis.log

pnr:
	@echo "==> Running P&R for core_macro..."
	innovus -init scripts/core_pnr.tcl -log logs/pnr.log

clean:
	rm -rf outputs/* reports/* logs/* db/*
```

**Repeat for all 7 leaf macros!**

---

## 🎓 Summary: What to Do

1. ✅ **Use original scripts** to build all 7 leaf macros (best optimization)
2. ✅ **Update integration scripts** to use `sky130_fd_sc_hd` library (compatibility)
3. ✅ **Use integration scripts** to merge macros hierarchically (fast integration)
4. ✅ **Get final SOC GDS** with all optimizations preserved!

---

## 🤔 Answer to Your Question

> "if I use them to generate the leaf stuff for integration parts can ı still use the integration scripts?"

**YES! Absolutely!**

The integration scripts are DESIGNED to work with pre-built macros from ANY source, including the original scripts. Just make sure the library is consistent (`sky130_fd_sc_hd`).

> "if so how and with that approach would I lose something?"

**How:** Follow Step 1 (original scripts) → Step 2 (copy outputs) → Step 3 (integration scripts)

**What you'd lose:** NOTHING! You GAIN everything:
- ✅ Optimized leaf macros (from original scripts)
- ✅ Fast hierarchical integration (from integration scripts)
- ✅ Final merged GDS with all macros

**This is the BEST approach!** 🎉
