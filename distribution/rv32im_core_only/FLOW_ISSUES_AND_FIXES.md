# RTL to GDS2 Flow - Issues and Remediation Guide

**Generated**: December 18, 2025  
**Design**: custom_riscv_core (RV32IM)  
**Flow**: Cadence Genus + Innovus  
**Technology**: SKY130 HD

---

## 🚨 Critical Issues Summary

| Issue Type        | Severity   | Count           | Impact                                 |
| ----------------- | ---------- | --------------- | -------------------------------------- |
| Timing Violations | **HIGH**   | 10+ paths       | Functional failure at target frequency |
| DRC Violations    | **MEDIUM** | ~100+           | Potential yield/reliability issues     |
| Reset Network     | **HIGH**   | 1 critical path | System stability                       |

---

## 1. ⏰ TIMING VIOLATIONS - **PRIORITY 1**

### **Problem Description**

- **Worst Setup Slack**: -0.661 ns
- **Failed Paths**: All related to register file `regfile_inst_registers_reg[12][*]`
- **Target Clock**: 10 ns (100 MHz)
- **Root Cause**: Reset signal (`rst_n`) has excessive delay (8.026 ns) driving register file

### **Critical Path Analysis**

```
rst_n → g165430 (nand2_1) → g164923 (nand2_2) → g163884 (o2bb2ai_1) → registers_reg[12][24]
Delay: 2.0ns + 8.026ns + 1.336ns + 0.453ns = 11.815ns
Required: 11.154ns → SLACK: -0.661ns
```

### **Root Causes**

1. **Reset Logic Depth**: 3-4 logic levels in reset path
2. **High Fanout**: Reset drives 2,161 flip-flops simultaneously
3. **Poor Placement**: Reset logic spread across die
4. **Weak Drive Strength**: Using `nand2_1` instead of stronger variants

### **Remediation Actions**

#### **Option A: Clock Frequency Reduction (Quick Fix)**

```tcl
# Relax clock constraint to meet current timing
set_clock_period 12.0 [get_clocks sys_clk]  # 83.3 MHz instead of 100 MHz
```

#### **Option B: Reset Network Optimization (Recommended)**

```tcl
# 1. Add reset buffer tree
set_max_fanout 50 [get_nets rst_n]

# 2. Use high-drive strength cells for reset path
set_dont_use [get_lib_cells */sky130_fd_sc_hd__nand2_1]
set_preferred_lib_cells [get_lib_cells */sky130_fd_sc_hd__nand2_4]

# 3. Add reset synchronizer
# Implement 2-FF reset synchronizer in RTL:
always_ff @(posedge clk) begin
    rst_sync_r[1:0] <= {rst_sync_r[0], ~rst_n};
end
assign rst_sync = ~rst_sync_r[1];
```

#### **Option C: Register File Optimization**

```tcl
# 1. Pipeline register file access
set_max_delay 8.0 -from [get_ports rst_n] -to [get_pins regfile_inst/registers_reg*/D]

# 2. Use high-VT cells for non-critical registers
set_threshold_voltage_group_type hvt [get_cells regfile_inst/registers_reg*]
```

---

## 2. 🔧 DRC VIOLATIONS - **PRIORITY 2**

### **Problem Description**

- **Metal Shorts**: Multiple nets shorting on li1, met1 layers
- **Cut Spacing**: mcon layer violations
- **Affected Nets**: `n_6094`, `n_5831`, `regfile_inst_registers[*][11]`, `CTS_34`
- **Total Violations**: ~4,000+ (from 4010-line DRC report)

### **Root Causes**

1. **Dense Routing**: Register file creates routing congestion
2. **Clock Tree**: CTS nets conflicting with signal routing
3. **Via Conflicts**: mcon cuts too close together
4. **Metal Layer**: li1 layer over-utilization

### **Remediation Actions**

#### **Floorplan Optimization**

```tcl
# 1. Increase core utilization to reduce congestion
setFloorPlanParams -coreUtilization 0.65  # Reduce from 0.8

# 2. Create placement blockages around register file
createPlaceBlockage -type soft -box {100 90 130 110} -inst regfile_inst

# 3. Reserve routing tracks for critical nets
setNanoRouteMode -routeTopRoutingLayer 4  # Avoid met5 for signals
```

#### **Routing Strategy**

```tcl
# 1. Enable detailed routing optimization
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -droutePostRouteSpreadWire true

# 2. Fix specific short violations
editSelect -type net -name "n_6094 n_5831"
editRoute -selected -effort high

# 3. Add routing guides for clock nets
addRoutingGuide -net CTS_34 -layer {met1 met2} -minWidth double
```

#### **Via and Cut Optimization**

```tcl
# 1. Increase via spacing
setNanoRouteMode -drouteMinViaSpacing {mcon:0.19 via1:0.19}

# 2. Use redundant vias where possible
setNanoRouteMode -drouteRedundantViaInsertion true
```

---

## 3. 🔄 RESET NETWORK - **PRIORITY 1**

### **Problem Description**

- Reset signal has 8+ ns delay through logic chain
- High fanout (2,161 registers) causing drive strength issues
- Reset release timing not properly controlled

### **RTL-Level Fixes (Recommended)**

#### **Add Reset Synchronizer Module**

```verilog
module reset_sync (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n_sync
);

reg [2:0] rst_sync_r;

always_ff @(posedge clk or negedge rst_n_async) begin
    if (!rst_n_async) begin
        rst_sync_r <= 3'b000;
    end else begin
        rst_sync_r <= {rst_sync_r[1:0], 1'b1};
    end
end

assign rst_n_sync = rst_sync_r[2];

endmodule
```

#### **Integrate in Top Module**

```verilog
// Replace direct rst_n usage with synchronized version
reset_sync rst_sync_inst (
    .clk(clk),
    .rst_n_async(rst_n),
    .rst_n_sync(rst_n_int)
);

// Use rst_n_int for all sequential logic
always_ff @(posedge clk or negedge rst_n_int) begin
    if (!rst_n_int) begin
        // Reset logic
    end else begin
        // Normal operation
    end
end
```

### **Synthesis Constraints**

```tcl
# 1. Define reset as asynchronous
set_false_path -from [get_ports rst_n]
set_max_delay 2.0 -from [get_ports rst_n] -to [get_pins rst_sync_inst/rst_sync_r_reg*/PRE]

# 2. Constrain reset synchronizer output
set_max_delay 1.0 -from [get_pins rst_sync_inst/rst_sync_r_reg[2]/Q] -to [all_registers]
```

---

## 4. 📋 Implementation Sequence

### **Phase 1: Quick Wins (1-2 hours)**

1. Reduce clock frequency to 83 MHz (`set_clock_period 12.0`)
2. Add reset network constraints
3. Re-run timing analysis

### **Phase 2: RTL Updates (4-6 hours)**

1. Implement reset synchronizer module
2. Update testbench for new reset behavior
3. Re-synthesize with updated RTL

### **Phase 3: Physical Implementation (6-8 hours)**

1. Update floorplan with reduced utilization
2. Add routing guides for critical nets
3. Enable advanced DRC fixing options
4. Final timing closure iteration

### **Phase 4: Verification (2-4 hours)**

1. Post-layout simulation with SDF
2. DRC/LVS clean runs
3. Final GDS generation and verification

---

## 5. 🎯 Expected Results After Fixes

| Metric          | Current         | Target After Fix     |
| --------------- | --------------- | -------------------- |
| Setup Slack     | -0.661 ns       | > +0.5 ns            |
| DRC Violations  | 4000+           | < 10                 |
| Clock Frequency | Failed @ 100MHz | 90-95 MHz achievable |
| Area            | 108,893 µm²     | ~115,000 µm² (+6%)   |
| Power           | 13.0 mW         | ~14.5 mW (+10%)      |

---

## 6. 🔍 Verification Checklist

```bash
# After implementing fixes, verify:

# 1. Timing closure
report_timing -max_paths 10 -nworst 1
report_design_summary

# 2. DRC clean
verify_drc -report final_drc.rpt

# 3. LVS clean
run_lvs -netlist final_netlist.v -gds final.gds

# 4. Functional verification
run_sdf_simulation -sdf post_route.sdf -testbench tb_top.v

# 5. Power analysis
report_power -analysis_effort high
```

---

## 7. 🏗️ HIERARCHICAL MACRO-BASED APPROACH - **RECOMMENDED STRATEGY**

### **Concept Overview**
Split the RV32IM core into separate physical macros, implement each independently, then integrate at top level. This addresses timing, congestion, and complexity issues simultaneously.

### **Proposed Module Partitioning**

#### **Macro 1: MDU (Multiply/Divide Unit)**
```verilog
module riscv_mdu_macro (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [2:0]  mdu_op,
    input  wire        mdu_enable,
    output wire [31:0] mdu_result,
    output wire        mdu_ready,
    output wire        mdu_valid
);
// Contains: multiplier, divider, state machines
// Estimated: ~3,000-4,000 cells
// Target: 50x50 μm macro
endmodule
```

#### **Macro 2: Core Logic (Everything Else)**
```verilog
module riscv_core_macro (
    input  wire        clk,
    input  wire        rst_n,
    // Instruction fetch interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    // Data memory interface  
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_we,
    input  wire [31:0] dmem_rdata,
    // MDU interface
    output wire [31:0] mdu_operand_a,
    output wire [31:0] mdu_operand_b,
    output wire [2:0]  mdu_op,
    output wire        mdu_enable,
    input  wire [31:0] mdu_result,
    input  wire        mdu_ready,
    input  wire        mdu_valid
);
// Contains: fetch, decode, execute, regfile, control
// Estimated: ~7,000-8,000 cells  
// Target: 80x80 μm macro
endmodule
```

### **Implementation Flow**

#### **Step 1: Macro-Level Implementation**
```tcl
# For each macro independently:

# 1. Synthesize individual macro
set_top_module riscv_mdu_macro
synthesize_design

# 2. Floorplan macro with specific constraints
create_floorplan -core_utilization 0.75 -aspect_ratio 1.0
set_macro_placement_halo -horizontal 2.0 -vertical 2.0

# 3. Place & Route with macro-specific timing
place_design -effort high
clock_tree_synthesis -effort high  
route_design -effort high

# 4. Generate macro deliverables
write_lef riscv_mdu_macro.lef
write_gds riscv_mdu_macro.gds  
write_lib riscv_mdu_macro.lib
```

#### **Step 2: Top-Level Integration**
```tcl
# Top level with instantiated macros
set_top_module custom_riscv_core_top

# Import macro LEF/LIB files
read_lef riscv_mdu_macro.lef
read_lef riscv_core_macro.lef
read_lib riscv_mdu_macro.lib  
read_lib riscv_core_macro.lib

# Floorplan with macro placement
create_floorplan -core_utilization 0.60  # Lower utilization for top level
place_macro riscv_mdu_macro_inst -location {20.0 20.0}
place_macro riscv_core_macro_inst -location {80.0 20.0}

# Route only top-level interconnect
route_design -skip_macro_routing
```

### **Key Benefits for Your Issues**

#### **Timing Closure**
- **Smaller Search Space**: Each macro optimized independently
- **Better Clock Distribution**: Separate clock trees per macro
- **Reduced Congestion**: Critical paths contained within macros
- **Expected Improvement**: Setup slack from -0.661ns to +0.5ns

#### **DRC Resolution**  
- **Isolated Routing**: Macro internals pre-verified
- **Controlled Interfaces**: Only macro pins need top-level routing
- **Reduced Complexity**: ~90% fewer nets to route at top level
- **Expected Improvement**: DRC violations from 4000+ to <50

#### **Reset Network**
- **Local Reset Trees**: Each macro has optimized reset distribution
- **Synchronized Interfaces**: Reset synchronizers at macro boundaries
- **Reduced Fanout**: Reset drives macro enable pins, not all flops

### **Macro Interface Strategy**

#### **MDU Interface Timing**
```verilog
// Pipelined MDU interface for timing closure
always_ff @(posedge clk) begin
    if (!rst_n) begin
        mdu_req_r <= '0;
        mdu_operands_r <= '0;
    end else begin
        mdu_req_r <= mdu_enable;
        mdu_operands_r <= {operand_a, operand_b, mdu_op};
    end
end

// Multi-cycle MDU operation
assign mdu_enable = mdu_req_r;
assign {operand_a, operand_b, mdu_op} = mdu_operands_r;
```

#### **Macro Timing Constraints**
```tcl
# Define macro interface timing
set_input_delay 2.0 -clock clk [get_ports mdu_operand*]
set_output_delay 2.0 -clock clk [get_ports mdu_result*]
set_max_delay 8.0 -from [get_ports mdu_enable] -to [get_ports mdu_ready]
```

### **Directory Structure for Macro Flow**
```
synthesis_cadence/
├── macros/
│   ├── mdu_macro/
│   │   ├── synthesis/
│   │   ├── place_route/  
│   │   ├── outputs/
│   │   │   ├── riscv_mdu_macro.lef
│   │   │   ├── riscv_mdu_macro.lib
│   │   │   └── riscv_mdu_macro.gds
│   │   └── reports/
│   ├── core_macro/
│   │   └── [similar structure]
│   └── integration/
│       ├── top_level_synthesis/
│       ├── top_level_pnr/
│       └── final_outputs/
```

### **Implementation Timeline**

#### **Phase 1: RTL Partitioning (2-3 days)**
- Extract MDU into separate module
- Create clean interfaces between macros
- Update testbench for hierarchical verification

#### **Phase 2: Individual Macro Implementation (3-4 days each)**
- **MDU Macro**: Focus on multiplier/divider timing
- **Core Macro**: Optimize fetch/decode/execute paths
- Achieve timing closure for each macro independently

#### **Phase 3: Top-Level Integration (2-3 days)**
- Macro placement optimization
- Interface routing and timing verification
- Final DRC/LVS closure

### **Expected Results**

| Metric | Current Flat | Target Hierarchical | Improvement |
|--------|-------------|-------------------|-------------|
| Setup Slack | -0.661 ns | +0.5 ns | +1.16 ns |
| DRC Violations | 4000+ | <50 | 99% reduction |
| Implementation Time | ~2 weeks | ~10 days | 30% faster |
| Design Reuse | None | MDU reusable | High |
| Debug Complexity | High | Low per macro | Significantly easier |

### **Tools and Scripts**

#### **Automated Macro Flow Script**
```bash
#!/bin/bash
# run_hierarchical_flow.sh

echo "Starting hierarchical implementation..."

# Build MDU macro
cd macros/mdu_macro
genus -f synthesis.tcl
innovus -f place_route.tcl

# Build Core macro  
cd ../core_macro
genus -f synthesis.tcl
innovus -f place_route.tcl

# Top-level integration
cd ../integration
innovus -f top_level_integration.tcl

echo "Hierarchical flow complete!"
```

This hierarchical approach will significantly improve your timing closure and DRC results while making the design more manageable and reusable.

---

## 8. 📞 Support Resources

- **University CAD Support**: Contact for Cadence license/tool issues
- **SKY130 PDK Documentation**: [SkyWater PDK GitHub](https://github.com/google/skywater-pdk)
- **OpenLane Flow**: Alternative open-source RTL2GDS flow
- **Academic Papers**: Search "RISC-V physical implementation" for optimization techniques
- **Hierarchical Design**: "Physical Design of VLSI Circuits" - Sarrafzadeh & Wong

---

_This document provides a systematic approach to resolving the identified issues. The hierarchical macro-based approach is recommended for best results and future design reuse._
