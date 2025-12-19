# RV32IM SoC Build Status

**Date**: December 20, 2025  
**Status**: ✅ Ready to build

## ONE Command Builds Everything

```bash
./build_all_macros.sh
```

## What It Does

1. **Builds 5 peripheral macros** (memory, uart/spi, pwm, adc, protection)
2. **Builds CPU separately** (core_macro + mdu_macro)
3. **Creates integrated IP** (rv32im_integrated_macro = core+MDU)
4. **Builds final SoC** (integrated IP + peripherals)

## Outputs

All in `{macro}/outputs/`:

- `.gds` - Layout files
- `.lef` - Abstract views
- `_syn.v` - Netlists
- `.rpt` - Reports (area/timing/power)

## Final Deliverables

- `rv32im_integrated_macro.gds` - Reusable RV32IM IP (~11-13K cells)
- `rv32im_soc_complete.gds` - Complete chip (~31K cells + SRAMs)
- All individual macros available separately

## Architecture Changes Made

**Corrected understanding**: Core and MDU are SEPARATE macros, combined hierarchically in rv32im_integrated_macro.

**Files cleaned**:

- Removed redundant documentation
- Moved old build scripts to `old_scripts/`
- One clear README
- One master build script

## Key Files

- `build_all_macros.sh` - Master build script
- `README.md` - Usage guide
- `soc_integration/` - Final SoC assembly
- `rv32im_integrated_macro/` - Core+MDU IP

---

**Build time**: 3-4 hours for everything  
**Requirements**: Cadence Genus 21.18+, Innovus 21.1+, SKY130 PDK
