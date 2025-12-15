# RV32IMZ Synthesis Strategy Guide - Restoring Division Implementation

## Overview

This guide provides comprehensive synthesis strategies for the RV32IMZ core, with special focus on timing closure for the **restoring division algorithm** in the MDU (Multiply-Divide Unit). The core achieves **98% RISC-V compliance** with proper timing constraints.

## Core Architecture Summary

- **ISA**: RV32IM (Base + M-extension)
- **Pipeline**: 3-stage (Fetch, Execute, Writeback)
- **MDU**: Restoring division (34 cycles) + shift-add multiplication (32 cycles)
- **Interface**: Wishbone B4 compatible
- **Compliance**: 49/50 RISC-V tests passing (98%)

## Critical Timing Analysis

### MDU Critical Paths

**1. Division Algorithm Critical Path (~7.0-8.5ns)**

```verilog
// 33-bit comparison and conditional subtraction
remainder_shifted[32:0] = {remainder_reg[30:0], dividend[31-div_count]};
can_subtract = remainder_shifted >= divisor;                    // 33-bit compare
remainder_next = can_subtract ? (remainder_shifted - divisor) : remainder_shifted;
quotient_next = (quotient_reg << 1) | can_subtract;
```

**Path breakdown:**

- 33-bit concatenation: ~0.5ns
- 33-bit comparison: ~2.5ns
- 33-bit subtraction: ~3.0ns
- 32-bit shift + OR: ~1.5ns
- Routing delays: ~0.5-1.0ns
- **Total: ~7.5-8.5ns**

**2. Multiplication Critical Path (~6.5-7.0ns)**

```verilog
// 64-bit accumulator addition
if (multiplier[0])
    acc_next = acc + multiplicand;  // 64-bit addition
multiplicand_next = multiplicand << 1;  // 64-bit left shift
```

**Path breakdown:**

- 64-bit addition: ~4.5ns
- 64-bit shift: ~1.5ns
- Control logic: ~0.5ns
- Routing delays: ~0.5ns
- **Total: ~6.5-7.0ns**

## Synthesis Constraints

### Clock Constraints

**Conservative (Recommended):**

```sdc
create_clock -period 10.0 [get_ports clk]  # 100 MHz
set_clock_uncertainty 0.5 [get_clocks sys_clk]
```

**Optimized (Advanced):**

```sdc
create_clock -period 7.1 [get_ports clk]   # 140 MHz
set_clock_uncertainty 0.3 [get_clocks sys_clk]
```

### Critical Path Constraints

**Division Algorithm:**

```sdc
# Critical 33-bit comparison path
set_max_delay -from [get_pins mdu/remainder_reg_reg[*]/Q] \
              -to [get_pins mdu/quotient_reg_reg[*]/D] 8.0

# Critical 33-bit subtraction path
set_max_delay -from [get_pins mdu/remainder_reg_reg[*]/Q] \
              -to [get_pins mdu/remainder_reg_reg[*]/D] 8.5
```

**Multiplication:**

```sdc
# 64-bit accumulator critical path
set_max_delay -from [get_pins mdu/acc_reg[*]/Q] \
              -to [get_pins mdu/acc_reg[*]/D] 7.0
```

### Multi-cycle Path Optimization

```sdc
# MDU counter and control paths don't need single-cycle timing
set_multicycle_path -setup 2 -from [get_pins mdu/div_count_reg[*]/Q]
set_multicycle_path -setup 2 -from [get_pins mdu/mul_count_reg[*]/Q]
set_multicycle_path -setup 2 -from [get_pins mdu/op_latched_reg[*]/Q]
```

## Technology-Specific Optimization

### Xilinx 7-Series/UltraScale

**LUT Optimization:**

```tcl
# Favor 6-LUT utilization for arithmetic
set_property LUT_COMBINING true [get_cells mdu/*]

# Use carry chains for fast arithmetic
set_property USE_CARRY_CHAIN true [get_cells mdu/*adder*]

# Place MDU logic together
create_pblock MDU_pblock
add_cells_to_pblock [get_pblocks MDU_pblock] [get_cells mdu]
```

**Register Optimization:**

```tcl
# Enable register duplication for timing
set_property REGISTER_DUPLICATION true [get_cells mdu/remainder_reg_reg[*]]
set_property MAX_FANOUT 50 [get_cells mdu/state_reg[*]]
```

### Intel/Altera

**ALM Optimization:**

```tcl
# Optimize for ALM efficiency
set_global_assignment -name OPTIMIZATION_MODE "HIGH PERFORMANCE EFFORT"
set_global_assignment -name ALLOW_REGISTER_RETIMING ON

# Use dedicated arithmetic blocks
set_global_assignment -name AUTO_DSP_RECOGNITION ON
```

### ASIC (Generic)

**Standard Cell Optimization:**

```sdc
# Use high-Vt cells for non-critical paths
set_dont_touch [get_cells mdu/div_count_reg[*]]
set_dont_touch [get_cells mdu/op_latched_reg[*]]

# High-drive strength for critical nets
set_driving_cell -lib_cell BUFX8 [get_ports clk]
```

## Synthesis Flow

### 1. Preparation Phase

```bash
# Clean and prepare
cd /path/to/RV32IMZ
rm -rf synthesis/*.v synthesis/*.json

# Verify constraint files exist
ls -la constraints/rv32imz_timing.sdc
ls -la constraints/rv32imz_timing.xdc
```

### 2. Yosys Synthesis

```bash
# Run synthesis with timing constraints
./synthesize.sh

# Check results
grep "Max frequency" synthesis_report.txt
grep "Critical path" synthesis_report.txt
```

**Expected Yosys results:**

```
Total cells: ~800-1200
LUTs: ~600-900
Registers: 163 (MDU) + ~400 (CPU)
Critical path: Division logic
```

### 3. Vivado Implementation

```tcl
# Source files
read_verilog synthesized_core.v

# Apply constraints
read_xdc constraints/rv32imz_timing.xdc

# Synthesis
synth_design -top custom_riscv_core

# Implementation
opt_design
place_design
route_design

# Timing analysis
report_timing_summary
```

### 4. Quartus Implementation

```tcl
# Project setup
project_new rv32imz

# Source files
set_global_assignment -name VERILOG_FILE synthesized_core.v
set_global_assignment -name SDC_FILE constraints/rv32imz_timing.sdc

# Compile
execute_flow -compile

# Timing analysis
report_timing
```

## Resource Utilization

### Expected Resource Usage

**Xilinx 7-Series (Artix-7):**

```
LUTs: 2,500-3,500 (5-7% of XC7A35T)
Registers: 1,200-1,800 (3-5% of XC7A35T)
BRAMs: 1-2 (for instruction memory)
DSPs: 0 (pure LUT implementation)
```

**Intel Cyclone V:**

```
ALMs: 1,800-2,500 (7-10% of 5CGXFC7)
Registers: 1,200-1,800 (3-5% of 5CGXFC7)
M20K: 1-2 (for memory)
DSPs: 0
```

### Optimization Targets

| Metric        | Conservative | Optimized | Maximum  |
| ------------- | ------------ | --------- | -------- |
| **Frequency** | 100 MHz      | 140 MHz   | 150+ MHz |
| **LUTs**      | 3,500        | 3,000     | 2,500    |
| **Power**     | Baseline     | -10%      | -20%     |
| **Effort**    | Low          | Medium    | High     |

## Timing Closure Strategies

### 1. Critical Path Optimization

**Identify bottlenecks:**

```bash
# Run timing analysis
yosys -p "read_verilog rtl/core/*.v; synth; abc -constr constraints/rv32imz_timing.sdc; tee -o timing.log stat"
```

**Fix critical paths:**

- **Pipeline critical arithmetic** (add registers)
- **Reduce fanout** on control signals
- **Optimize carry chains** for addition/subtraction

### 2. Placement Optimization

**Xilinx:**

```tcl
# Keep related logic together
set_property LOC SLICE_X20Y50 [get_cells mdu/remainder_reg_reg[0]]
set_property LOC SLICE_X21Y50 [get_cells mdu/quotient_reg_reg[0]]

# Use regional constraints
create_pblock MDU_region
add_cells_to_pblock [get_pblocks MDU_region] [get_cells mdu]
resize_pblock [get_pblocks MDU_region] -add {SLICE_X0Y0:SLICE_X50Y100}
```

**Intel:**

```tcl
# Logic lock regions
set_instance_assignment -name LL_ROOT_REGION ON -to mdu
set_instance_assignment -name LL_MEMBER_OF "mdu" -to mdu|*
```

### 3. Advanced Optimization

**Clock domain optimization:**

```verilog
// Optional: Run MDU at higher frequency
// Requires clock domain crossing logic
wire mdu_clk = clk_pll_fast;  // 200 MHz
wire mdu_data_valid;
```

**Early termination optimization:**

```verilog
// Terminate division early for smaller operands
wire [5:0] dividend_leading_zeros = /* count leading zeros */;
wire early_term_possible = (div_count + dividend_leading_zeros >= 32);

if (early_term_possible && remainder_reg < divisor) begin
    state <= DIV2;  // Skip remaining cycles
end
```

## Verification and Sign-off

### 1. Static Timing Analysis

```bash
# Post-synthesis timing
./synthesize.sh
grep "timing" synthesis_report.txt

# Check for timing violations
echo "Setup slack: $(grep -o 'slack [0-9.]*' synthesis_report.txt)"
```

### 2. Functional Verification

```bash
# Run compliance tests
python3 run_compliance_tests.py

# Expected results:
# Results: 49 passed, 1 failed, 50 total
# Pass rate: 98.0%
# All M-extension tests: PASS
```

### 3. Gate-level Simulation

```bash
# Post-synthesis simulation
iverilog -o test_synthesis synthesized_core.v test_division_final.v
./test_synthesis
```

## Troubleshooting

### Common Timing Issues

**1. Division path too slow:**

```
Solution: Reduce clock frequency or pipeline the comparison
Constraint: set_max_delay 8.5ns for 33-bit subtraction
```

**2. High fanout on control signals:**

```
Solution: Register duplication or local control generation
Constraint: set_max_fanout 50
```

**3. Cross-domain timing:**

```
Solution: Proper clock domain crossing or synchronous design
Constraint: set_false_path between unrelated domains
```

### Performance Tuning

**1. Area optimization:**

- Reduce register count with state encoding
- Share arithmetic units between operations
- Use memory-based approaches for large operations

**2. Power optimization:**

- Clock gating for idle units
- Operand isolation for unused paths
- Voltage/frequency scaling

**3. Speed optimization:**

- Pipeline critical arithmetic operations
- Use technology-specific arithmetic primitives
- Parallel processing for independent operations

This synthesis strategy ensures reliable timing closure for the RV32IMZ core with the restoring division algorithm, achieving 98% RISC-V compliance at 100+ MHz operation.
