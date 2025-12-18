# 2-Macro Hierarchical RV32IM Implementation

This directory contains a complete 2-macro hierarchical implementation solution for the RV32IM core, designed to address timing violations and DRC issues discovered in the original flat synthesis approach.

## Problem Analysis

The original flat synthesis approach suffered from:

- **Setup timing violations**: -0.661ns worst slack
- **DRC violations**: 4000+ violations
- **Reset network issues**: High fanout (2,161 registers)
- **Routing congestion**: Complex interconnect

## Solution Strategy

**2-Macro Hierarchical Approach:**

1. **MDU Macro**: Isolated multiply/divide unit (heavy computation)
2. **Core Macro**: Pipeline + Register File + ALU + Decoder + CSR + Exception handling

## Directory Structure

```
macros/
├── mdu_macro/                    # MDU macro implementation
│   ├── rtl/mdu_macro.v          # MDU wrapper with clean interface
│   ├── constraints/mdu_macro.sdc # Timing constraints for MDU
│   ├── scripts/                 # Synthesis/P&R TCL scripts
│   └── run_mdu_macro.sh         # Automated build script
├── core_macro/                  # Core macro implementation
│   ├── rtl/core_macro.v         # Core pipeline without internal MDU
│   ├── constraints/core_macro.sdc # Timing constraints for core
│   ├── scripts/                 # Synthesis/P&R TCL scripts
│   └── run_core_macro.sh        # Automated build script
├── constraints/
│   └── hierarchical_top.sdc     # Top-level timing constraints
├── rv32im_hierarchical_top.v    # Top-level integration wrapper
└── run_hierarchical_flow.sh     # Complete build automation
```

## Usage Instructions

### Quick Start (Complete Flow)

```bash
cd macros/
./run_hierarchical_flow.sh
```

This will:

1. Build MDU macro (synthesis + P&R)
2. Build Core macro (synthesis + P&R)
3. Generate integration files
4. Create comprehensive reports

### Individual Macro Builds

**MDU Macro:**

```bash
cd macros/mdu_macro/
./run_mdu_macro.sh
```

**Core Macro:**

```bash
cd macros/core_macro/
./run_core_macro.sh
```

### Cadence Session Integration

For your next Cadence session:

1. **Top-level design**: Use `rv32im_hierarchical_top.v`
2. **Constraints**: Apply `constraints/hierarchical_top.sdc`
3. **LEF files**: Load from `integration/` directory during floorplan
4. **Macro placement**: Place macros with optimal relative positioning

## Implementation Details

### MDU Macro

- **Purpose**: Isolated multiply/divide operations
- **Interface**: Clean handshake protocol with core
- **Benefits**: Heavy computation isolated, independent optimization

### Core Macro

- **Purpose**: Main pipeline logic without internal MDU
- **Interface**: External MDU connection via standardized signals
- **Benefits**: Reduced complexity, better timing closure

### Timing Strategy

- **Clock period**: 10ns (100MHz target)
- **Inter-macro budget**: 3ns for connections
- **Intra-macro budget**: 7ns for internal timing
- **Multi-cycle paths**: 8 cycles for MDU operations

## Expected Benefits

1. **Timing Closure**: Separate optimization per macro
2. **DRC Reduction**: Cleaner interfaces, reduced congestion
3. **Reset Distribution**: Limited fanout per macro (addresses 2,161 register issue)
4. **Synthesis Runtime**: Smaller problem sizes, faster convergence
5. **Debugging**: Isolated modules easier to analyze and fix

## File Dependencies

### Required Source Files (Copied from Original Design)

- `rtl/core/custom_riscv_core.v` → Used for pipeline logic
- `rtl/core/mdu.v` → Wrapped in MDU macro
- `rtl/core/regfile.v` → Integrated in core macro
- `rtl/core/alu.v` → Integrated in core macro
- `rtl/core/decoder.v` → Integrated in core macro
- `rtl/core/csr_unit.v` → Integrated in core macro
- `rtl/core/exception_unit.v` → Integrated in core macro

### Generated Files

- Macro wrappers with clean interfaces
- Synthesis and P&R scripts optimized for SKY130
- Timing constraints with proper budgets
- Automation scripts for complete flow

## Success Metrics

After implementation, expect:

- ✅ Positive setup slack (targeting +0.5ns minimum)
- ✅ Clean hold timing
- ✅ Significantly reduced DRC violations (<100)
- ✅ Manageable reset fanout per macro (<500 registers)
- ✅ Improved routing congestion scores

## Next Steps

1. **Validate macros**: Run individual macro flows first
2. **Integration test**: Use top-level wrapper for final validation
3. **Optimization**: Fine-tune constraints based on results
4. **Tapeout prep**: Final GDS merge and verification

## Troubleshooting

**If timing violations persist:**

- Increase clock period in SDC files
- Adjust inter-macro timing budget
- Review critical paths in individual macros

**If DRC violations remain:**

- Check macro placement in top-level
- Verify power ring routing
- Adjust floorplan utilization

**If build fails:**

- Verify Cadence environment is sourced
- Check file paths in TCL scripts
- Review individual macro logs in `logs/` directories

This hierarchical approach provides a robust foundation for achieving timing closure and clean DRC results with the RV32IM design in SKY130 technology.
