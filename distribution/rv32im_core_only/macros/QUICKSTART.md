# RV32IM SoC - One Command Build

## Build Everything

```bash
./build_all_macros.sh
```

**Time**: 3-4 hours  
**Output**: All macros + integrated IP + complete SoC with GDS/reports

## What You Get

```
outputs/
├── Peripheral Macros (5):
│   ├── memory_macro.gds
│   ├── communication_macro.gds  
│   ├── protection_macro.gds
│   ├── adc_subsystem_macro.gds
│   └── pwm_accelerator_macro.gds
│
├── CPU Macros (2):
│   ├── core_macro.gds
│   └── mdu_macro.gds
│
├── Integrated RV32IM IP:
│   └── rv32im_integrated_macro.gds  ← USE THIS for IP reuse
│
└── Complete SoC:
    └── rv32im_soc_complete.gds      ← Full tapeout package
```

Each macro includes: `.gds`, `.lef`, `_syn.v`, timing/area/power reports

## Architecture

- **7 Individual Macros**: All peripherals + core + MDU (separate)
- **1 Integrated IP**: Core + MDU combined hierarchically  
- **1 Complete SoC**: Integrated IP + all peripherals

## Requirements

- Cadence Genus 21.18+ (synthesis)
- Cadence Innovus 21.1+ (place & route)  
- SKY130 PDK (setup: `../setup_pdk_from_archive.sh`)

## Documentation

- `README.md` - Detailed guide
- `BUILD_STATUS.md` - Current status
- This file - Quick start

---

**That's it.** One command, complete tapeout package.
