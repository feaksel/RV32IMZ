# RV32IM Integrated Macro - Single IP Core

## Overview

This directory contains the **RV32IM Integrated Macro** - a complete, self-contained RV32IM processor IP core combining the CPU core and MDU (multiply/divide unit) into a single macro.

## Architecture

The integrated macro hierarchically combines two pre-built macros:

- **core_macro**: RV32I pipeline with external MDU interface (~8-9K cells)
- **mdu_macro**: Multiply/Divide Unit (~3-4K cells)

Total: **~11-13K cells** in a single deliverable GDS/LEF

## Key Features

✅ **Single IP Block**: One GDS file, one LEF file - easy to integrate  
✅ **Hierarchical Design**: Uses proven, separately-verified sub-macros  
✅ **Reusable**: Drop into any SoC design with Wishbone interface  
✅ **Complete RV32IM ISA**: All integer and multiply/divide instructions  
✅ **Timing Optimized**: Sub-macros are pre-optimized, only interconnect needs routing

## Prerequisites

Before building this integrated macro, you **MUST** build the sub-macros first:

```bash
# Build core_macro
cd ../core_macro
genus -batch -files scripts/core_synthesis.tcl
innovus -batch -files scripts/core_place_route.tcl

# Build mdu_macro
cd ../mdu_macro
./run_mdu_macro.sh
```

## Building the Integrated Macro

Once prerequisites are built:

```bash
cd rv32im_integrated_macro
./build_integrated_macro.sh
```

Or manually:

```bash
# Synthesis (reads LEF files of sub-macros)
cd scripts
genus -batch -files rv32im_integrated_synthesis.tcl

# Place & Route (places sub-macros and routes connections)
cd scripts
innovus -batch -files rv32im_integrated_place_route.tcl
```

## Outputs

After successful build:

```
outputs/
├── rv32im_integrated_macro.gds    # Complete layout (GDSII)
├── rv32im_integrated_macro.lef    # Abstract view for SoC integration
├── rv32im_integrated_macro.def    # Design Exchange Format
└── rv32im_integrated_macro_syn.v  # Synthesized netlist
```

## Using in SoC Designs

### Option 1: New SoC with Integrated Core

Use the new SoC wrapper that instantiates the integrated core:

```verilog
// rv32im_soc_with_integrated_core.v
rv32im_integrated_macro u_cpu_core (
    .clk(clk),
    .rst_n(rst_n),
    .iwb_adr_o(iwb_adr),  // Instruction bus
    .dwb_adr_o(dwb_adr),  // Data bus
    .interrupts(interrupts)
);
```

### Option 2: Standalone IP Core

Use directly in any design:

```verilog
module my_design (
    input clk, rst_n,
    // ... other signals
);

    // Wishbone buses
    wire [31:0] iwb_adr, iwb_dat_i;
    wire iwb_cyc, iwb_stb, iwb_ack;

    wire [31:0] dwb_adr, dwb_dat_o, dwb_dat_i;
    wire dwb_we, dwb_cyc, dwb_stb, dwb_ack, dwb_err;
    wire [3:0] dwb_sel;

    // Instantiate RV32IM core
    rv32im_integrated_macro #(
        .RESET_VECTOR(32'h0000_0000)
    ) cpu (
        .clk(clk),
        .rst_n(rst_n),
        .iwb_adr_o(iwb_adr),
        .iwb_dat_i(iwb_dat_i),
        .iwb_cyc_o(iwb_cyc),
        .iwb_stb_o(iwb_stb),
        .iwb_ack_i(iwb_ack),
        .dwb_adr_o(dwb_adr),
        .dwb_dat_o(dwb_dat_o),
        .dwb_dat_i(dwb_dat_i),
        .dwb_we_o(dwb_we),
        .dwb_sel_o(dwb_sel),
        .dwb_cyc_o(dwb_cyc),
        .dwb_stb_o(dwb_stb),
        .dwb_ack_i(dwb_ack),
        .dwb_err_i(dwb_err),
        .interrupts(32'h0)
    );

    // Connect to your memory/peripherals via Wishbone
    // ...
endmodule
```

## Interface

### Ports

| Port       | Direction | Width | Description                |
| ---------- | --------- | ----- | -------------------------- |
| clk        | Input     | 1     | System clock (typ. 100MHz) |
| rst_n      | Input     | 1     | Active-low reset           |
| iwb_adr_o  | Output    | 32    | Instruction address        |
| iwb_dat_i  | Input     | 32    | Instruction data           |
| iwb_cyc_o  | Output    | 1     | Instruction cycle          |
| iwb_stb_o  | Output    | 1     | Instruction strobe         |
| iwb_ack_i  | Input     | 1     | Instruction acknowledge    |
| dwb_adr_o  | Output    | 32    | Data address               |
| dwb_dat_o  | Output    | 32    | Data to write              |
| dwb_dat_i  | Input     | 32    | Data to read               |
| dwb_we_o   | Output    | 1     | Write enable               |
| dwb_sel_o  | Output    | 4     | Byte select                |
| dwb_cyc_o  | Output    | 1     | Data cycle                 |
| dwb_stb_o  | Output    | 1     | Data strobe                |
| dwb_ack_i  | Input     | 1     | Data acknowledge           |
| dwb_err_i  | Input     | 1     | Data error                 |
| interrupts | Input     | 32    | Interrupt request lines    |

### Parameters

| Parameter    | Default       | Description          |
| ------------ | ------------- | -------------------- |
| RESET_VECTOR | 32'h0000_0000 | PC value after reset |

## Physical Characteristics

- **Technology**: SKY130 (130nm)
- **Standard Cells**: sky130_fd_sc_hd
- **Area**: ~0.06 mm² (250µm × 200µm estimated)
- **Gate Count**: ~11,000-13,000 gates
- **Target Frequency**: 100 MHz
- **Power Domains**: Single VDD/VSS
- **Metal Layers**: Up to Metal 5

## Comparison with Alternatives

| Architecture                | Macros              | Use Case                          |
| --------------------------- | ------------------- | --------------------------------- |
| **rv32im_integrated_macro** | 1 (Core+MDU)        | **Reusable IP, easy integration** |
| core_macro + mdu_macro      | 2 (separate)        | Educational, flexible replacement |
| Full 6-macro SoC            | 6 (CPU+peripherals) | Complete application SoC          |

## Directory Structure

```
rv32im_integrated_macro/
├── rtl/
│   └── rv32im_integrated_macro.v  # Top-level wrapper
├── scripts/
│   ├── rv32im_integrated_synthesis.tcl  # Genus synthesis
│   ├── rv32im_integrated_place_route.tcl  # Innovus P&R
│   └── rv32im_integrated_pin_placement.tcl  # Pin assignments
├── mmmc/
│   └── rv32im_integrated_mmmc.tcl  # Multi-corner timing
├── constraints/
│   └── rv32im_integrated_macro.sdc  # Timing constraints
├── outputs/  # Build artifacts
├── reports/  # Timing/area/power reports
└── build_integrated_macro.sh  # Automated build script
```

## Build Time

Typical build time on modern workstation:

- Prerequisites (core + MDU): ~30-45 minutes
- Integrated macro synthesis: ~5-10 minutes
- Integrated macro P&R: ~10-15 minutes
- **Total**: ~50-70 minutes

## Verification

The integrated macro inherits verification from its sub-components:

- core_macro: Verified with RISC-V compliance tests
- mdu_macro: Verified with multiply/divide test vectors

Additional integration testing recommended:

```bash
# Run testbench with integrated core
cd ../../sim
make test_integrated_core
```

## Documentation References

- [Core Macro Documentation](../core_macro/README.md)
- [MDU Macro Documentation](../mdu_macro/README.md)
- [Complete SoC Guide](../README.md)
- [Firmware Guide](../FIRMWARE_AND_TESTING_GUIDE.md)

## Support

For issues or questions:

1. Check build prerequisites are met
2. Review synthesis/P&R logs in `reports/`
3. Verify sub-macro LEF files exist
4. Ensure PDK_ROOT environment variable is set

---

**Status**: ✅ Ready for Production  
**Last Updated**: December 20, 2025  
**Version**: 2.0 - Hierarchical Integration
