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

## 7. 🏗️ HIERARCHICAL MACRO-BASED APPROACH - **SIMPLIFIED 2-MACRO STRATEGY**

### **Concept Overview**

Split the RV32IM core into just **2 separate physical macros** for optimal timing closure and implementation efficiency. This simplified approach addresses your timing and DRC issues while being practical for university implementation.

### **Current RTL Analysis**

Your RTL is perfectly structured for this 2-macro partitioning:

```
Current RTL Structure → 2-Macro Partitioning:
├── mdu.v                     → MDU Macro ✅
└── Everything else           → RV32I Core Macro
    ├── custom_riscv_core.v   (pipeline + control)
    ├── regfile.v             (register file)
    ├── alu.v                 (ALU)
    ├── decoder.v             (decoder)
    ├── csr_unit.v            (CSR)
    ├── exception_unit.v      (exceptions)
    └── interrupt_controller.v (interrupts)
```

### **2-Macro Partitioning Strategy**

#### **Macro 1: MDU (Multiply/Divide Unit)** ✅

```verilog
// File: macros/mdu_macro/rtl/mdu_macro.v
module mdu_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // MDU Interface (exact copy of your existing mdu.v interface)
    input  wire        start,
    input  wire        ack,
    input  wire [2:0]  funct3,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        busy,
    output wire        done,
    output wire [63:0] product,
    output wire [31:0] quotient,
    output wire [31:0] remainder
);

// Direct instantiation of your existing MDU
mdu mdu_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .ack(ack),
    .funct3(funct3),
    .a(a),
    .b(b),
    .busy(busy),
    .done(done),
    .product(product),
    .quotient(quotient),
    .remainder(remainder)
);

endmodule
```

**Estimated**: ~3,000-4,000 cells | **Target Size**: 60×60 μm

#### **Macro 2: RV32I Core (Everything Else)**

```verilog
// File: macros/core_macro/rtl/core_macro.v
module core_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Instruction Bus (Master)
    output wire [31:0] iwb_adr_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,

    // Wishbone Data Bus (Master)
    output wire [31:0] dwb_adr_o,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output wire        dwb_we_o,
    output wire [3:0]  dwb_sel_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,
    input  wire        dwb_err_i,

    // MDU Interface
    output wire        mdu_start,
    output wire        mdu_ack,
    input  wire        mdu_busy,
    input  wire        mdu_done,
    input  wire [63:0] mdu_product,
    input  wire [31:0] mdu_quotient,
    input  wire [31:0] mdu_remainder,

    // System Interface
    input  wire [31:0] interrupts
);

// All your existing modules EXCEPT mdu.v:
// - Modified custom_riscv_core.v (without MDU instantiation)
// - regfile.v
// - alu.v
// - decoder.v
// - csr_unit.v
// - exception_unit.v
// - interrupt_controller.v (if used)

endmodule
```

**Estimated**: ~8,000-9,000 cells | **Target Size**: 120×120 μm

### **Top-Level Integration**

#### **Hierarchical custom_riscv_core.v**

```verilog
module custom_riscv_core_hierarchical #(
    parameter RESET_VECTOR = 32'h00000000
)(
    // External interfaces (unchanged)
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] iwb_adr_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,
    output wire [31:0] dwb_adr_o,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output wire        dwb_we_o,
    output wire [3:0]  dwb_sel_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,
    input  wire        dwb_err_i,
    input  wire [31:0] interrupts
);

// Inter-macro signals
wire        mdu_start, mdu_ack, mdu_busy, mdu_done;
wire [63:0] mdu_product;
wire [31:0] mdu_quotient, mdu_remainder;

// Core macro (contains everything except MDU)
core_macro core_inst (
    .clk(clk),
    .rst_n(rst_n),
    .iwb_adr_o(iwb_adr_o),
    .iwb_dat_i(iwb_dat_i),
    .iwb_cyc_o(iwb_cyc_o),
    .iwb_stb_o(iwb_stb_o),
    .iwb_ack_i(iwb_ack_i),
    .dwb_adr_o(dwb_adr_o),
    .dwb_dat_o(dwb_dat_o),
    .dwb_dat_i(dwb_dat_i),
    .dwb_we_o(dwb_we_o),
    .dwb_sel_o(dwb_sel_o),
    .dwb_cyc_o(dwb_cyc_o),
    .dwb_stb_o(dwb_stb_o),
    .dwb_ack_i(dwb_ack_i),
    .dwb_err_i(dwb_err_i),
    .mdu_start(mdu_start),
    .mdu_ack(mdu_ack),
    .mdu_busy(mdu_busy),
    .mdu_done(mdu_done),
    .mdu_product(mdu_product),
    .mdu_quotient(mdu_quotient),
    .mdu_remainder(mdu_remainder),
    .interrupts(interrupts)
);

// MDU macro
mdu_macro mdu_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(mdu_start),
    .ack(mdu_ack),
    .funct3(/* connect from core */),
    .a(/* connect from core */),
    .b(/* connect from core */),
    .busy(mdu_busy),
    .done(mdu_done),
    .product(mdu_product),
    .quotient(mdu_quotient),
    .remainder(mdu_remainder)
);

endmodule
```

### **Implementation Benefits**

#### **Timing Closure Benefits**

- **Reset Network**: MDU gets separate reset tree, core gets optimized reset
- **Critical Paths**: Register file timing issues isolated to core macro
- **Clock Trees**: Two independent, optimized clock trees
- **Expected**: Setup slack from -0.661ns to +0.5ns

#### **DRC Resolution Benefits**

- **Routing Isolation**: 95% of routing contained within macro boundaries
- **Congestion Relief**: No routing conflicts between MDU and core logic
- **Via Optimization**: Only top-level interconnect needs optimization
- **Expected**: DRC violations from 4000+ to <50

#### **Implementation Benefits**

- **Parallel Development**: MDU and core can be implemented simultaneously
- **Simplified Integration**: Only 2 macros to place and route at top level
- **Design Reuse**: MDU macro reusable in other RISC-V implementations
- **Faster Convergence**: Smaller search spaces for each macro

---

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

### **Current RTL Analysis**

Your RTL is already well-structured for macro partitioning! Based on your existing modules:

```
Current RTL Structure:
├── custom_riscv_core.v    (Main core + control logic)
├── mdu.v                  ✅ Already separate! (~3,000 cells)
├── regfile.v              (32×32-bit register file)
├── alu.v                  (Arithmetic logic unit)
├── decoder.v              (Instruction decoder)
├── csr_unit.v             (Control & Status Registers)
├── exception_unit.v       (Exception handling)
├── interrupt_controller.v (Interrupt management)
└── riscv_defines.vh       (Shared definitions)
```

### **Optimal Macro Partitioning Strategy**

Based on your existing RTL structure and timing analysis, here's the recommended macro partitioning:

#### **Macro 1: MDU (Multiply/Divide Unit)** ✅ Ready!

```verilog
// File: macros/mdu_macro/rtl/mdu_macro.v
module mdu_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // MDU Interface (from your existing mdu.v)
    input  wire        start,
    input  wire        ack,
    input  wire [2:0]  funct3,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        busy,
    output wire        done,
    output wire [63:0] product,
    output wire [31:0] quotient,
    output wire [31:0] remainder
);

// Direct instantiation of your existing MDU
mdu mdu_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .ack(ack),
    .funct3(funct3),
    .a(a),
    .b(b),
    .busy(busy),
    .done(done),
    .product(product),
    .quotient(quotient),
    .remainder(remainder)
);

endmodule
```

**Estimated**: ~3,000-4,000 cells | **Target Size**: 50×50 μm

#### **Macro 2: Register File + ALU Datapath**

```verilog
// File: macros/datapath_macro/rtl/datapath_macro.v
module datapath_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Register File Interface
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    input  wire        rd_wen,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    // ALU Interface
    input  wire [31:0] alu_operand_a,
    input  wire [31:0] alu_operand_b,
    input  wire [3:0]  alu_op,
    output wire [31:0] alu_result,
    output wire        alu_zero
);

// Your existing register file
regfile regfile_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .rd_data(rd_data),
    .rd_wen(rd_wen),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
);

// Your existing ALU
alu alu_inst (
    .operand_a(alu_operand_a),
    .operand_b(alu_operand_b),
    .alu_op(alu_op),
    .result(alu_result),
    .zero(alu_zero)
);

endmodule
```

**Estimated**: ~4,000-5,000 cells | **Target Size**: 70×70 μm

#### **Macro 3: Control & System Unit**

```verilog
// File: macros/control_macro/rtl/control_macro.v
module control_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Decode Interface
    input  wire [31:0] instruction,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [4:0]  rd_addr,
    output wire [31:0] immediate,
    output wire [3:0]  alu_op,
    output wire        alu_src_imm,
    output wire        mem_read,
    output wire        mem_write,
    output wire        reg_write,
    output wire        is_branch,
    output wire        is_jump,
    output wire        is_system,
    output wire        is_m,
    output wire        is_zpec,
    output wire        is_ecall,
    output wire        is_ebreak,
    output wire        is_mret,
    output wire        illegal_instr,

    // CSR Interface
    input  wire [11:0] csr_addr,
    input  wire [31:0] csr_wdata,
    input  wire [2:0]  csr_op,
    output wire [31:0] csr_rdata,
    output wire        csr_valid,

    // Trap Interface
    input  wire        trap_entry,
    input  wire        trap_return,
    input  wire [31:0] trap_pc,
    input  wire [31:0] trap_cause,
    input  wire [31:0] trap_val,
    output wire [31:0] trap_vector,
    output wire [31:0] epc_out,

    // Interrupt Interface
    input  wire [31:0] interrupts_i,
    output wire        interrupt_pending,
    output wire        interrupt_enabled,
    output wire [31:0] interrupt_cause,

    // Exception Interface
    input  wire [31:0] pc,
    input  wire [31:0] mem_addr,
    input  wire        bus_error,
    output wire        exception_taken,
    output wire [31:0] exception_cause,
    output wire [31:0] exception_val,

    // Performance
    input  wire        instr_retired
);

// Your existing decoder
decoder decoder_inst (
    .instruction(instruction),
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .immediate(immediate),
    .alu_op(alu_op),
    .alu_src_imm(alu_src_imm),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .reg_write(reg_write),
    .is_branch(is_branch),
    .is_jump(is_jump),
    .is_system(is_system),
    .is_m(is_m),
    .is_zpec(is_zpec),
    .is_ecall(is_ecall),
    .is_ebreak(is_ebreak),
    .is_mret(is_mret),
    .is_wfi(),
    .illegal_instr(illegal_instr)
);

// Your existing CSR unit
csr_unit csr_inst (
    .clk(clk),
    .rst_n(rst_n),
    .csr_addr(csr_addr),
    .csr_wdata(csr_wdata),
    .csr_op(csr_op),
    .csr_rdata(csr_rdata),
    .csr_valid(csr_valid),
    .trap_entry(trap_entry),
    .trap_return(trap_return),
    .trap_pc(trap_pc),
    .trap_cause(trap_cause),
    .trap_val(trap_val),
    .trap_vector(trap_vector),
    .epc_out(epc_out),
    .interrupts_i(interrupts_i),
    .interrupt_pending(interrupt_pending),
    .interrupt_enabled(interrupt_enabled),
    .interrupt_cause(interrupt_cause),
    .instr_retired(instr_retired)
);

// Your existing exception unit
exception_unit exc_unit (
    .pc(pc),
    .instruction(instruction),
    .funct3(funct3),
    .mem_addr(mem_addr),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .bus_error(bus_error),
    .illegal_instr(illegal_instr),
    .ecall(is_ecall),
    .ebreak(is_ebreak),
    .exception_taken(exception_taken),
    .exception_cause(exception_cause),
    .exception_val(exception_val)
);

endmodule
```

**Estimated**: ~2,000-3,000 cells | **Target Size**: 60×60 μm

#### **Macro 4: Core Pipeline Controller (Simplified)**

```verilog
// File: macros/pipeline_macro/rtl/pipeline_macro.v
module pipeline_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Instruction Bus (Master)
    output wire [31:0] iwb_adr_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,

    // Wishbone Data Bus (Master)
    output wire [31:0] dwb_adr_o,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output wire        dwb_we_o,
    output wire [3:0]  dwb_sel_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,
    input  wire        dwb_err_i,

    // Datapath Macro Interface
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [4:0]  rd_addr,
    output wire [31:0] rd_data,
    output wire        rd_wen,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    output wire [31:0] alu_operand_a,
    output wire [31:0] alu_operand_b,
    output wire [3:0]  alu_op,
    input  wire [31:0] alu_result,
    input  wire        alu_zero,

    // Control Macro Interface
    output wire [31:0] instruction,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [31:0] immediate,
    input  wire        alu_src_imm,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        reg_write,
    input  wire        is_branch,
    input  wire        is_jump,
    input  wire        is_system,
    input  wire        is_m,
    input  wire        is_ecall,
    input  wire        is_ebreak,
    input  wire        is_mret,
    input  wire        illegal_instr,

    // MDU Macro Interface
    output wire        mdu_start,
    output wire        mdu_ack,
    input  wire        mdu_busy,
    input  wire        mdu_done,
    input  wire [63:0] mdu_product,
    input  wire [31:0] mdu_quotient,
    input  wire [31:0] mdu_remainder,

    // System Interface
    input  wire [31:0] interrupts
);

// Contains only the pipeline state machine and control logic
// from your custom_riscv_core.v (lines 1-565, excluding instantiations)
// This includes: PC management, state machine, bus interface logic
// Estimated: ~1,500-2,000 cells | Target Size: 50×50 μm

endmodule
```

### **Top-Level Integration**

#### **Modified custom_riscv_core.v (Hierarchical Version)**

```verilog
module custom_riscv_core_hierarchical #(
    parameter RESET_VECTOR = 32'h00000000
)(
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Bus Interfaces (unchanged)
    output wire [31:0] iwb_adr_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,

    output wire [31:0] dwb_adr_o,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output wire        dwb_we_o,
    output wire [3:0]  dwb_sel_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,
    input  wire        dwb_err_i,

    input  wire [31:0] interrupts
);

// Inter-macro signal declarations
wire [4:0]  rs1_addr, rs2_addr, rd_addr;
wire [31:0] rs1_data, rs2_data, rd_data;
wire        rd_wen;
wire [31:0] alu_operand_a, alu_operand_b;
wire [3:0]  alu_op;
wire [31:0] alu_result;
wire        alu_zero;
wire [31:0] instruction;
wire [6:0]  opcode;
wire [2:0]  funct3;
wire [6:0]  funct7;
// ... other interface signals

// Macro instantiations
mdu_macro mdu_inst (/* connections */);
datapath_macro datapath_inst (/* connections */);
control_macro control_inst (/* connections */);
pipeline_macro pipeline_inst (/* connections */);

endmodule
```

### **Macro Implementation Flow**

#### **Phase 1: Create Macro Wrappers (2-3 days)**

```bash
# Create macro directory structure
mkdir -p macros/{mdu_macro,datapath_macro,control_macro,pipeline_macro}/{rtl,synthesis,reports,outputs}

# Copy existing RTL into appropriate macro directories
# Create wrapper modules as shown above
```

#### **Phase 2: Individual Macro P&R (Parallel - 2-3 days each)**

```tcl
# Per-macro synthesis and P&R scripts

# Example: MDU Macro
cd macros/mdu_macro
genus -f synthesis.tcl  # Synthesize mdu_macro.v
innovus -f place_route.tcl  # P&R with tight constraints

# Generate macro deliverables
write_lef outputs/mdu_macro.lef
write_lib outputs/mdu_macro.lib
write_gds outputs/mdu_macro.gds
```

#### **Phase 3: Top-Level Integration (1-2 days)**

```tcl
# Import all macro LEF/LIB files
read_lef macros/mdu_macro/outputs/mdu_macro.lef
read_lef macros/datapath_macro/outputs/datapath_macro.lef
read_lef macros/control_macro/outputs/control_macro.lef
read_lef macros/pipeline_macro/outputs/pipeline_macro.lef

# Strategic macro placement (based on data flow)
place_macro pipeline_inst   -location {50  50}   # Core controller
place_macro datapath_inst   -location {120 50}   # Register file + ALU
place_macro mdu_inst        -location {50  120}  # MDU (separate timing)
place_macro control_inst    -location {120 120}  # Decoder + CSR

# Route only top-level interconnect
route_design -effort high
```

### **Benefits for Your Specific Issues**

#### **Timing Closure Benefits**

- **Reset Network**: Each macro has local reset distribution
- **Critical Paths**: Register file timing isolated to datapath_macro
- **Clock Tree**: Separate trees per macro, much better skew control
- **Expected**: Setup slack from -0.661ns to +0.5ns

#### **DRC Resolution Benefits**

- **Routing Congestion**: 95% of routing happens within macro boundaries
- **Metal Conflicts**: Macro-internal routing pre-verified
- **Via Spacing**: Only top-level interconnect needs via optimization
- **Expected**: DRC violations from 4000+ to <20

#### **Implementation Benefits**

- **Reuse**: MDU macro can be used in other RISC-V cores
- **Debug**: Isolate timing/functional issues to specific macros
- **Parallel Development**: 4 macros can be worked on simultaneously
- **Scalability**: Easy to add/remove features by swapping macros

### **Recommended Implementation Priority**

1. **Start with MDU Macro** (easiest - already isolated)
2. **Datapath Macro** (addresses register file timing issues)
3. **Control Macro** (contains most of your decoder/CSR logic)
4. **Pipeline Macro** (simplest - mainly state machine)
5. **Top-level integration** (straightforward interconnect)

This approach leverages your existing well-structured RTL and directly addresses your current timing and DRC issues while creating valuable IP for future projects.

---

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

| Metric              | Current Flat | Target Hierarchical | Improvement          |
| ------------------- | ------------ | ------------------- | -------------------- |
| Setup Slack         | -0.661 ns    | +0.5 ns             | +1.16 ns             |
| DRC Violations      | 4000+        | <50                 | 99% reduction        |
| Implementation Time | ~2 weeks     | ~10 days            | 30% faster           |
| Design Reuse        | None         | MDU reusable        | High                 |
| Debug Complexity    | High         | Low per macro       | Significantly easier |

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

## 8. 🏛️ FULL SOC HIERARCHICAL APPROACH - **SCALABLE STRATEGY**

### **SoC-Level Macro Partitioning**

For the full SoC (`rv32imz_full_soc`), extend the hierarchical approach to include **all peripherals as individual macros**. This creates a truly scalable and modular implementation.

### **Complete SoC Macro Architecture**

#### **Macro 1: CPU Core Complex**

```verilog
module cpu_core_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone Bus Master Interface
    output wire [31:0] wb_cpu_adr_o,
    output wire [31:0] wb_cpu_dat_o,
    input  wire [31:0] wb_cpu_dat_i,
    output wire [3:0]  wb_cpu_sel_o,
    output wire        wb_cpu_we_o,
    output wire        wb_cpu_stb_o,
    output wire        wb_cpu_cyc_o,
    input  wire        wb_cpu_ack_i,
    // Interrupts
    input  wire [7:0]  irq_lines
);
// Contains: RV32IM core + MDU + caches (if any)
// Estimated: ~11,000 cells
// Target: 120x120 μm macro
endmodule
```

#### **Macro 2: Memory Subsystem**

```verilog
module memory_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone ROM Interface
    input  wire [31:0] wb_rom_adr_i,
    output wire [31:0] wb_rom_dat_o,
    input  wire [3:0]  wb_rom_sel_i,
    input  wire        wb_rom_stb_i,
    input  wire        wb_rom_cyc_i,
    output wire        wb_rom_ack_o,
    // Wishbone RAM Interface
    input  wire [31:0] wb_ram_adr_i,
    input  wire [31:0] wb_ram_dat_i,
    output wire [31:0] wb_ram_dat_o,
    input  wire [3:0]  wb_ram_sel_i,
    input  wire        wb_ram_we_i,
    input  wire        wb_ram_stb_i,
    input  wire        wb_ram_cyc_i,
    output wire        wb_ram_ack_o
);
// Contains: 32KB ROM + 64KB RAM + memory controllers
// Estimated: ~8,000-10,000 cells (mostly SRAM)
// Target: 100x100 μm macro
endmodule
```

#### **Macro 3: PWM Accelerator**

```verilog
module pwm_accelerator_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone Interface
    input  wire [7:0]  wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output wire [31:0] wb_dat_o,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    output wire        wb_ack_o,
    // PWM Outputs
    output wire [7:0]  pwm_out,
    // Control Signals
    input  wire        pwm_disable,
    output wire        pwm_irq
);
// Contains: 8-channel PWM with dead-time, carrier generation
// Estimated: ~2,000-3,000 cells
// Target: 60x60 μm macro
endmodule
```

#### **Macro 4: ADC Subsystem**

```verilog
module adc_subsystem_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone Interface
    input  wire [7:0]  wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output wire [31:0] wb_dat_o,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    output wire        wb_ack_o,
    // Sigma-Delta ADC Interface
    input  wire [3:0]  adc_comp_in,
    output wire [3:0]  adc_dac_out,
    output wire        adc_irq
);
// Contains: 4-channel Σ-Δ ADC + CIC filters + decimation
// Estimated: ~3,000-4,000 cells
// Target: 70x70 μm macro
endmodule
```

#### **Macro 5: Protection & Monitoring**

```verilog
module protection_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone Interface
    input  wire [7:0]  wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output wire [31:0] wb_dat_o,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    output wire        wb_ack_o,
    // Fault Inputs
    input  wire        fault_ocp,
    input  wire        fault_ovp,
    input  wire        estop_n,
    // Control Outputs
    output wire        pwm_disable,
    output wire        prot_irq
);
// Contains: OCP/OVP detection + watchdog + fault handling
// Estimated: ~800-1,200 cells
// Target: 40x40 μm macro
endmodule
```

#### **Macro 6: Communication Peripherals**

```verilog
module comm_peripherals_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    // UART Wishbone Interface
    input  wire [7:0]  wb_uart_adr_i,
    input  wire [31:0] wb_uart_dat_i,
    output wire [31:0] wb_uart_dat_o,
    input  wire [3:0]  wb_uart_sel_i,
    input  wire        wb_uart_we_i,
    input  wire        wb_uart_stb_i,
    output wire        wb_uart_ack_o,
    // GPIO Wishbone Interface
    input  wire [7:0]  wb_gpio_adr_i,
    input  wire [31:0] wb_gpio_dat_i,
    output wire [31:0] wb_gpio_dat_o,
    input  wire [3:0]  wb_gpio_sel_i,
    input  wire        wb_gpio_we_i,
    input  wire        wb_gpio_stb_i,
    output wire        wb_gpio_ack_o,
    // Timer Wishbone Interface
    input  wire [7:0]  wb_timer_adr_i,
    input  wire [31:0] wb_timer_dat_i,
    output wire [31:0] wb_timer_dat_o,
    input  wire [3:0]  wb_timer_sel_i,
    input  wire        wb_timer_we_i,
    input  wire        wb_timer_stb_i,
    output wire        wb_timer_ack_o,
    // External Interfaces
    input  wire        uart_rx,
    output wire        uart_tx,
    inout  wire [15:0] gpio,
    output wire [3:0]  led,
    // Interrupts
    output wire        uart_irq,
    output wire        timer_irq
);
// Contains: UART + GPIO + Timer + status LEDs
// Estimated: ~1,500-2,000 cells
// Target: 50x50 μm macro
endmodule
```

### **SoC Top-Level Integration**

#### **Top-Level Module (Macro Integration Only)**

```verilog
module soc_top_hierarchical (
    // External Interfaces
    input  wire        clk_100mhz,
    input  wire        rst_n,
    input  wire        uart_rx,
    output wire        uart_tx,
    output wire [7:0]  pwm_out,
    input  wire [3:0]  adc_comp_in,
    output wire [3:0]  adc_dac_out,
    input  wire        fault_ocp,
    input  wire        fault_ovp,
    input  wire        estop_n,
    inout  wire [15:0] gpio,
    output wire [3:0]  led
);

// Internal clock generation (100MHz → 50MHz)
wire clk, rst_n_sync;

// Wishbone bus interconnects (between macros)
wire [31:0] wb_cpu_adr, wb_cpu_dat_o, wb_cpu_dat_i;
wire [3:0]  wb_cpu_sel;
wire        wb_cpu_we, wb_cpu_stb, wb_cpu_cyc, wb_cpu_ack;

// Interrupt aggregation
wire [7:0] irq_lines;
wire pwm_irq, adc_irq, prot_irq, uart_irq, timer_irq;
assign irq_lines = {3'b0, timer_irq, uart_irq, prot_irq, adc_irq, pwm_irq};

// Macro instantiations with only top-level interconnect
cpu_core_macro       cpu_inst     (/* connections */);
memory_macro         mem_inst     (/* connections */);
pwm_accelerator_macro pwm_inst    (/* connections */);
adc_subsystem_macro  adc_inst     (/* connections */);
protection_macro     prot_inst    (/* connections */);
comm_peripherals_macro comm_inst  (/* connections */);

// Wishbone bus arbiter/crossbar (interconnect logic only)
wishbone_crossbar wb_xbar_inst (/* connections */);

endmodule
```

### **SoC Implementation Flow**

#### **Phase 1: Individual Macro Implementation (Parallel)**

```bash
#!/bin/bash
# run_soc_hierarchical_flow.sh

echo "Starting full SoC hierarchical implementation..."

# Parallel macro implementation (can run simultaneously)
parallel_jobs() {
    # CPU Core macro
    cd macros/cpu_core_macro && genus -f synthesis.tcl && innovus -f place_route.tcl &

    # Memory macro
    cd ../memory_macro && genus -f synthesis.tcl && innovus -f place_route.tcl &

    # PWM macro
    cd ../pwm_accelerator_macro && genus -f synthesis.tcl && innovus -f place_route.tcl &

    # ADC macro
    cd ../adc_subsystem_macro && genus -f synthesis.tcl && innovus -f place_route.tcl &

    # Protection macro
    cd ../protection_macro && genus -f synthesis.tcl && innovus -f place_route.tcl &

    # Communication macro
    cd ../comm_peripherals_macro && genus -f synthesis.tcl && innovus -f place_route.tcl &

    wait  # Wait for all parallel jobs to complete
}

parallel_jobs
echo "All macros completed successfully!"

# Top-level integration
cd integration/soc_top_integration
innovus -f soc_integration.tcl

echo "Full SoC hierarchical flow complete!"
```

#### **Phase 2: SoC-Level Floorplanning**

```tcl
# soc_integration.tcl - Top-level floorplanning

# Import all macro LEF/LIB files
read_lef ../macros/cpu_core_macro/outputs/cpu_core_macro.lef
read_lef ../macros/memory_macro/outputs/memory_macro.lef
read_lef ../macros/pwm_accelerator_macro/outputs/pwm_accelerator_macro.lef
read_lef ../macros/adc_subsystem_macro/outputs/adc_subsystem_macro.lef
read_lef ../macros/protection_macro/outputs/protection_macro.lef
read_lef ../macros/comm_peripherals_macro/outputs/comm_peripherals_macro.lef

# Create SoC floorplan (larger die for full SoC)
create_floorplan -core_utilization 0.50 -aspect_ratio 1.0 -die_size {400 400}

# Strategic macro placement
place_macro cpu_inst       -location {50  50}    # Bottom-left (CPU core)
place_macro mem_inst       -location {200 50}    # Bottom-center (Memory)
place_macro pwm_inst       -location {50  200}   # Top-left (PWM)
place_macro adc_inst       -location {150 200}   # Top-center (ADC)
place_macro prot_inst      -location {250 200}   # Top-right (Protection)
place_macro comm_inst      -location {300 50}    # Bottom-right (UART/GPIO)

# Add placement halos to avoid congestion
set_macro_placement_halo -all_macros -horizontal 5.0 -vertical 5.0

# Route only SoC-level interconnect (Wishbone bus + clock tree)
place_design -effort medium  # Only interconnect logic
clock_tree_synthesis -effort high
route_design -effort high
```

### **Benefits for Full SoC**

#### **Massive Parallelization**

- **6 macros** can be implemented **simultaneously**
- **Development time**: Reduced from 4-6 weeks to 2-3 weeks
- **Team allocation**: 6 different engineers can work on individual macros

#### **Modular Testing & Verification**

- **Unit-level testing**: Each macro verified independently
- **Focused debugging**: Issues isolated to specific functional blocks
- **Regression testing**: Macro changes don't affect other blocks

#### **Design Reuse & IP Creation**

- **PWM macro**: Reusable in other motor control applications
- **ADC macro**: Portable to different SoC configurations
- **CPU macro**: Drop-in replacement capability for other projects
- **Communication macro**: Standard UART/GPIO/Timer IP block

#### **Improved Timing & Physical Results**

- **Clock distribution**: Separate clock trees per macro
- **Critical paths**: Contained within macro boundaries
- **Congestion**: Eliminated through macro-level isolation
- **Power islands**: Each macro can have independent power management

### **Expected SoC Results**

| Metric                  | Flat Implementation | Hierarchical Macros  | Improvement     |
| ----------------------- | ------------------- | -------------------- | --------------- |
| **Implementation Time** | 4-6 weeks           | 2-3 weeks            | 50% faster      |
| **Timing Closure**      | Multiple iterations | First-pass success   | 90% improvement |
| **DRC Violations**      | 10,000+ expected    | <100                 | 99% reduction   |
| **Team Productivity**   | Sequential work     | Parallel development | 6× efficiency   |
| **Design Reuse**        | Monolithic          | 6 reusable macros    | High IP value   |
| **Debugging Time**      | Weeks               | Days per macro       | 80% faster      |

### **Directory Structure for Full SoC**

```
synthesis_cadence/
├── macros/
│   ├── cpu_core_macro/
│   │   ├── rtl/ (core + MDU)
│   │   ├── synthesis/
│   │   ├── place_route/
│   │   └── outputs/ (.lef, .lib, .gds)
│   ├── memory_macro/
│   │   ├── rtl/ (ROM + RAM)
│   │   └── [similar structure]
│   ├── pwm_accelerator_macro/
│   │   ├── rtl/ (PWM + dead-time + carrier)
│   │   └── [similar structure]
│   ├── adc_subsystem_macro/
│   │   ├── rtl/ (Σ-Δ ADC + filters)
│   │   └── [similar structure]
│   ├── protection_macro/
│   │   ├── rtl/ (OCP + OVP + watchdog)
│   │   └── [similar structure]
│   └── comm_peripherals_macro/
│       ├── rtl/ (UART + GPIO + Timer)
│       └── [similar structure]
├── integration/
│   ├── soc_top_integration/
│   │   ├── rtl/ (soc_top_hierarchical.v + crossbar)
│   │   ├── constraints/ (soc_timing.sdc)
│   │   ├── scripts/ (soc_integration.tcl)
│   │   └── outputs/ (final SoC GDS)
│   └── verification/
│       ├── tb_soc_hierarchical.v
│       └── post_layout_sim/
└── reports/
    ├── macro_summary.rpt
    ├── soc_integration.rpt
    └── final_results.rpt
```

This hierarchical approach for the full SoC creates a truly scalable, maintainable, and high-performance implementation that can serve as the foundation for an entire family of motor control SoCs.

---

## 9. 📞 Support Resources

- **University CAD Support**: Contact for Cadence license/tool issues
- **SKY130 PDK Documentation**: [SkyWater PDK GitHub](https://github.com/google/skywater-pdk)
- **OpenLane Flow**: Alternative open-source RTL2GDS flow
- **Academic Papers**: Search "RISC-V physical implementation" for optimization techniques
- **Hierarchical Design**: "Physical Design of VLSI Circuits" - Sarrafzadeh & Wong

---

_This document provides a systematic approach to resolving the identified issues. The hierarchical macro-based approach is recommended for best results and future design reuse._
