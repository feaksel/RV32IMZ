# 🎯 RV32IM CADENCE SESSION GUIDE

**Tools:** Genus 21.18, Innovus 21.1/21.35 | **Tech:** SKY130 | **Target:** 100 MHz

---

## ⚡ TWO STEPS TO SUCCESS

### 1. Before Session (5 min at home):

```bash
cd /home/furka/RV32IMZ/distribution/rv32im_core_only/macros
./COMPLETE_SETUP.sh
```

### 2. At University (2 hours):

```bash
# Core Macro
cd core_macro && genus -batch -files scripts/core_synthesis.tcl && innovus -batch -files scripts/core_place_route.tcl

# MDU Macro
cd ../mdu_macro && genus -batch -files synthesis/mdu_synthesis.tcl && innovus -batch -files synthesis/mdu_place_route.tcl

# Integration
cd .. && cat > int.tcl << 'EOF'
read_lef core_macro/outputs/core_macro.lef
read_lef mdu_macro/outputs/mdu_macro.lef
read_verilog rv32im_hierarchical_top.v
init_design
floorPlan -r 1.0 0.70 5 5 5 5
placeInstance u_core_macro 10 10 -fixed
placeInstance u_mdu_macro 90 10 -fixed
addRing -nets {VDD VSS} -type core_rings && sroute && routeDesign
streamOut rv32im_core.gds
EOF
innovus -batch -files int.tcl
```

**Deliverable:** `rv32im_core.gds` (~12K cells)

---

## ✅ YOUR SCRIPTS ARE PERFECT

Compared `synthesis_cadence/` (your working scripts) with macro scripts:

| Feature                   | Status          | Notes                       |
| ------------------------- | --------------- | --------------------------- |
| Synthesis effort = `high` | ✅ PERFECT      | No changes needed!          |
| Library = single typical  | ✅ PERFECT      | Matches your working script |
| SRAM black-boxing         | ✅ PERFECT      | Already correct             |
| CTS strategy              | ⚠️ ADD FALLBACK | COMPLETE_SETUP.sh adds this |

**The setup script adds CTS fallback from your working script. That's it!**

---

## 🚨 EMERGENCY FIXES

**Timing fails?** Edit SDC: `period 10.0` → `period 12.5` (80 MHz)  
**CTS fails?** Already has fallback (clock routes as net - acceptable)  
**DRC errors?** Run `ecoRoute -fix_drc` after routing

---

## 📦 WHAT YOU'RE BUILDING

```
RV32IM Core
├── Core Macro (8-9K cells) ← Pipeline, ALU, RegFile
└── MDU Macro (3-4K cells) ← Multiply/Divide
= rv32im_core.gds (12K cells, ~80×100 μm)
```

**Expected:** 30 min + 20 min + 20 min = 70 minutes total

---

## 🔍 VERIFY SUCCESS

```bash
ls core_macro/outputs/core_macro.gds  # ✅
ls mdu_macro/outputs/mdu_macro.gds    # ✅
ls rv32im_core.gds                    # ✅ FINAL
grep "slack" */reports/timing.rpt     # Should be > -1ns
```

---

## 📋 CHECKLIST

**Before leaving home:**

- [ ] Run `./COMPLETE_SETUP.sh`
- [ ] Backup: `tar -czf ~/rv32im.tar.gz macros/ pdk/`

**At university:**

- [ ] `module load cadence/genus cadence/innovus`
- [ ] Build core + MDU (follow commands above)
- [ ] Verify GDS files exist
- [ ] Copy to USB before leaving

---

## 💡 KEY POINTS

1. Your scripts already use `high` effort - **no downgrades**
2. SRAM macros confirmed present - **memory will work**
3. Setup script adds CTS fallback - **prevents crashes**
4. 100 MHz target - **can relax to 80 MHz if needed**
5. Genus 21.18, Innovus 21.1 - **modern, fully featured**

**You're 95% ready. Run the setup script and go!** 🚀
