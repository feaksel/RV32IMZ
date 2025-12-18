# Testing Hierarchical Macro-Based Design
## Pre-Synthesis and Post-Synthesis Verification Guide

---

## 📋 OVERVIEW

Your hierarchical macro-based RV32IM SoC can be tested at multiple levels:

1. **Pre-Synthesis RTL Simulation** (behavioral)
2. **Post-Synthesis Gate-Level Simulation** (with timing)
3. **Post-P&R Gate-Level Simulation** (with extracted parasitics)

Let's explore how each works with your macro structure.

---

## ✅ PRE-SYNTHESIS TESTING (YES, STILL WORKS!)

### **Can You Still Test Pre-Synthesis?**
**YES!** The macro structure is just organizational wrappers. All the actual RTL logic is still there and fully simulatable.

### **How It Works:**

Your macro `.v` files are just thin wrappers that instantiate the real RTL modules:

**Example - `mdu_macro.v`:**
```verilog
module mdu_macro (
    // Macro interface ports
    ...
);
    // Just instantiates the real RTL
    mdu mdu_inst (...);
endmodule
```

**Example - `memory_macro.v`:**
```verilog
module memory_macro (
    // Macro interface ports
    ...
);
    // Real SRAM instantiations
    sky130_sram_2kbyte_1rw1r_32x512_8 sram_rom[0] (...);
    sky130_sram_2kbyte_1rw1r_32x512_8 sram_rom[1] (...);
    // ... banking logic
endmodule
```

### **Testing Hierarchy Levels:**

#### **Level 1: Individual Macro Testing**
Test each macro independently:

```bash
# Test PWM accelerator macro
cd /home/furka/RV32IMZ/sim
iverilog -g2012 \
    ../distribution/rv32im_core_only/macros/pwm_accelerator_macro/rtl/pwm_accelerator_macro.v \
    testbench/tb_pwm_macro.v \
    -o build/tb_pwm_macro.vvp
vvp build/tb_pwm_macro.vvp
```

#### **Level 2: Hierarchical Core Testing**
Test the 2-macro core (MDU + Core):

```bash
cd /home/furka/RV32IMZ/sim
iverilog -g2012 \
    -I../distribution/rv32im_core_only/macros/core_macro/rtl \
    ../distribution/rv32im_core_only/macros/rv32im_hierarchical_top.v \
    ../distribution/rv32im_core_only/macros/mdu_macro/rtl/mdu_macro.v \
    ../distribution/rv32im_core_only/macros/core_macro/rtl/*.v \
    testbench/tb_hierarchical_core.v \
    -o build/tb_hierarchical_core.vvp
vvp build/tb_hierarchical_core.vvp
```

#### **Level 3: Full SoC Testing**
Test complete 6-macro SoC:

```bash
cd /home/furka/RV32IMZ/sim
iverilog -g2012 \
    -I../distribution/rv32im_core_only/macros/core_macro/rtl \
    ../distribution/rv32im_core_only/macros/rv32im_soc_complete.v \
    ../distribution/rv32im_core_only/macros/*/rtl/*.v \
    testbench/tb_soc_complete.v \
    -o build/tb_soc_complete.vvp
vvp build/tb_soc_complete.vvp
```

---

## 🏗️ CREATING TESTBENCHES FOR MACROS

### **Example: Testbench for Hierarchical Core**

Create `/home/furka/RV32IMZ/sim/testbench/tb_hierarchical_core.v`:

```verilog
`timescale 1ns/1ps

module tb_hierarchical_core;

    reg clk;
    reg rst_n;
    
    // Instruction Wishbone
    wire [31:0] iwb_adr;
    wire [31:0] iwb_dat_out;
    reg  [31:0] iwb_dat_in;
    wire        iwb_we;
    wire [3:0]  iwb_sel;
    wire        iwb_cyc;
    wire        iwb_stb;
    reg         iwb_ack;
    
    // Data Wishbone
    wire [31:0] dwb_adr;
    wire [31:0] dwb_dat_out;
    reg  [31:0] dwb_dat_in;
    wire        dwb_we;
    wire [3:0]  dwb_sel;
    wire        dwb_cyc;
    wire        dwb_stb;
    reg         dwb_ack;
    
    reg [15:0] interrupts;

    // DUT - Hierarchical Core (MDU + Core macros)
    rv32im_hierarchical_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .iwb_adr_o  (iwb_adr),
        .iwb_dat_o  (iwb_dat_out),
        .iwb_dat_i  (iwb_dat_in),
        .iwb_we_o   (iwb_we),
        .iwb_sel_o  (iwb_sel),
        .iwb_cyc_o  (iwb_cyc),
        .iwb_stb_o  (iwb_stb),
        .iwb_ack_i  (iwb_ack),
        .iwb_err_i  (1'b0),
        .dwb_adr_o  (dwb_adr),
        .dwb_dat_o  (dwb_dat_out),
        .dwb_dat_i  (dwb_dat_in),
        .dwb_we_o   (dwb_we),
        .dwb_sel_o  (dwb_sel),
        .dwb_cyc_o  (dwb_cyc),
        .dwb_stb_o  (dwb_stb),
        .dwb_ack_i  (dwb_ack),
        .dwb_err_i  (1'b0),
        .interrupts (interrupts)
    );

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simple memory model
    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    
    initial begin
        $readmemh("firmware/test_program.hex", imem);
    end

    // Wishbone response
    always @(posedge clk) begin
        iwb_ack <= iwb_cyc && iwb_stb;
        dwb_ack <= dwb_cyc && dwb_stb;
        
        if (iwb_cyc && iwb_stb)
            iwb_dat_in <= imem[iwb_adr[11:2]];
            
        if (dwb_cyc && dwb_stb && !dwb_we)
            dwb_dat_in <= dmem[dwb_adr[11:2]];
        else if (dwb_cyc && dwb_stb && dwb_we)
            dmem[dwb_adr[11:2]] <= dwb_dat_out;
    end

    // Test sequence
    initial begin
        $dumpfile("tb_hierarchical_core.vcd");
        $dumpvars(0, tb_hierarchical_core);
        
        rst_n = 0;
        interrupts = 0;
        iwb_dat_in = 0;
        dwb_dat_in = 0;
        iwb_ack = 0;
        dwb_ack = 0;
        
        #100;
        rst_n = 1;
        
        #10000;
        $display("Test completed");
        $finish;
    end

endmodule
```

---

## 🔬 POST-SYNTHESIS TESTING

After running synthesis, you get gate-level netlists for each macro.

### **What You Get After Synthesis:**

From `build_complete_proven_package.sh`, each macro produces:

```
memory_macro/outputs/
├── memory_macro_netlist.v       ← Gate-level netlist
├── memory_macro_timing.sdf      ← Standard Delay Format (timing)
├── memory_macro.gds             ← Layout (for P&R)
└── memory_macro.lef             ← Abstract view
```

### **Post-Synthesis Simulation Setup:**

**Option 1: Full Gate-Level Simulation**
```bash
cd /home/furka/RV32IMZ/sim

# Compile with gate-level netlists + standard cell library
iverilog -g2012 \
    -I/home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog \
    /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v \
    /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v \
    ../distribution/rv32im_core_only/macros/mdu_macro/outputs/mdu_macro_netlist.v \
    ../distribution/rv32im_core_only/macros/core_macro/outputs/core_macro_netlist.v \
    testbench/tb_hierarchical_core.v \
    -o build/tb_post_synth.vvp

# Run with SDF timing annotation
vvp build/tb_post_synth.vvp +sdf_annotate=../distribution/rv32im_core_only/macros/mdu_macro/outputs/mdu_macro_timing.sdf
```

**Option 2: Mixed RTL/Gate-Level Simulation**
This is useful when debugging - simulate some macros as RTL, some as gates:

```verilog
// In testbench - use RTL for peripherals, gates for core
module tb_mixed;
    // ... testbench code
    
    // Core macro - use gate-level netlist
    core_macro dut_core (
        // ... connections
    );
    
    // Peripherals - use RTL for easier debugging
    pwm_accelerator_macro pwm (
        // ... connections  
    );
endmodule
```

Compile command:
```bash
iverilog -g2012 \
    ../distribution/rv32im_core_only/macros/core_macro/outputs/core_macro_netlist.v \
    ../distribution/rv32im_core_only/macros/pwm_accelerator_macro/rtl/pwm_accelerator_macro.v \
    /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v \
    testbench/tb_mixed.v \
    -o build/tb_mixed.vvp
```

---

## 🎯 POST-PLACE & ROUTE TESTING

After P&R, you get parasitics-extracted netlists with real interconnect delays.

### **What You Need:**

```
memory_macro/outputs/
├── memory_macro_netlist_final.v    ← Post-P&R netlist
├── memory_macro_timing_final.sdf   ← Timing with interconnect
└── memory_macro_parasitics.spef    ← Parasitic extraction (optional)
```

### **Post-P&R Simulation:**

```bash
# Very similar to post-synthesis, but with final netlist and timing
vvp build/tb_post_synth.vvp \
    +sdf_annotate=../distribution/rv32im_core_only/macros/mdu_macro/outputs/mdu_macro_timing_final.sdf \
    +sdf_annotate=../distribution/rv32im_core_only/macros/core_macro/outputs/core_macro_timing_final.sdf
```

### **Timing Violations Check:**

In your testbench, add timing checks:
```verilog
// Setup/Hold checking
initial begin
    $sdf_annotate("../outputs/macro_timing.sdf", dut);
    $timeformat(-9, 2, " ns", 10);
end

always @(posedge clk) begin
    if ($time > 0) begin
        // Check for timing violations
        if ($setuphold_violation)
            $error("Setup/Hold violation at time %t", $time);
    end
end
```

---

## 🛠️ CREATING A COMPREHENSIVE TEST MAKEFILE

Create `/home/furka/RV32IMZ/sim/Makefile.hierarchical`:

```makefile
# Makefile for Hierarchical Macro Testing
# Supports: RTL, Post-Synthesis, Post-P&R simulation

MACRO_ROOT = ../distribution/rv32im_core_only/macros
PDK_ROOT = ../pdk/sky130A

# Standard cell library
STD_CELL_VERILOG = $(PDK_ROOT)/libs.ref/sky130_fd_sc_hd/verilog

# Macros RTL paths
MDU_RTL = $(MACRO_ROOT)/mdu_macro/rtl/mdu_macro.v
CORE_RTL = $(MACRO_ROOT)/core_macro/rtl/*.v
MEMORY_RTL = $(MACRO_ROOT)/memory_macro/rtl/memory_macro.v
PWM_RTL = $(MACRO_ROOT)/pwm_accelerator_macro/rtl/pwm_accelerator_macro.v

# Macros gate-level paths
MDU_GATES = $(MACRO_ROOT)/mdu_macro/outputs/mdu_macro_netlist.v
CORE_GATES = $(MACRO_ROOT)/core_macro/outputs/core_macro_netlist.v

# Hierarchical top
HIER_TOP = $(MACRO_ROOT)/rv32im_hierarchical_top.v

# Testbenches
TB_DIR = testbench
TB_HIER = $(TB_DIR)/tb_hierarchical_core.v

# Targets
.PHONY: rtl_sim post_synth_sim post_pr_sim clean

# Pre-synthesis RTL simulation
rtl_sim:
	@echo "Running pre-synthesis RTL simulation..."
	iverilog -g2012 -DSIMULATION \
		-I$(MACRO_ROOT)/core_macro/rtl \
		$(HIER_TOP) \
		$(MDU_RTL) \
		$(CORE_RTL) \
		$(TB_HIER) \
		-o build/tb_rtl.vvp
	vvp build/tb_rtl.vvp
	@echo "✓ RTL simulation complete"

# Post-synthesis simulation
post_synth_sim:
	@echo "Running post-synthesis gate-level simulation..."
	iverilog -g2012 -DSIMULATION \
		$(STD_CELL_VERILOG)/primitives.v \
		$(STD_CELL_VERILOG)/sky130_fd_sc_hd.v \
		$(MDU_GATES) \
		$(CORE_GATES) \
		$(TB_HIER) \
		-o build/tb_post_synth.vvp
	vvp build/tb_post_synth.vvp
	@echo "✓ Post-synthesis simulation complete"

# Post-P&R simulation with timing
post_pr_sim:
	@echo "Running post-P&R simulation with timing..."
	iverilog -g2012 -DSIMULATION \
		$(STD_CELL_VERILOG)/primitives.v \
		$(STD_CELL_VERILOG)/sky130_fd_sc_hd.v \
		$(MDU_GATES) \
		$(CORE_GATES) \
		$(TB_HIER) \
		-o build/tb_post_pr.vvp
	vvp build/tb_post_pr.vvp \
		+sdf_annotate=$(MACRO_ROOT)/mdu_macro/outputs/mdu_macro_timing.sdf \
		+sdf_annotate=$(MACRO_ROOT)/core_macro/outputs/core_macro_timing.sdf
	@echo "✓ Post-P&R simulation complete"

clean:
	rm -f build/*.vvp *.vcd

wave:
	gtkwave *.vcd &
```

Usage:
```bash
cd /home/furka/RV32IMZ/sim

# Test pre-synthesis RTL
make -f Makefile.hierarchical rtl_sim

# Test post-synthesis gates
make -f Makefile.hierarchical post_synth_sim

# Test post-P&R with timing
make -f Makefile.hierarchical post_pr_sim
```

---

## 🧪 TESTING STRATEGY RECOMMENDATIONS

### **Development Phase (Pre-Synthesis):**
✅ Use RTL simulation exclusively
- Fast compilation
- Easy debugging with waveforms
- Full signal visibility
- No timing issues to deal with

### **After Synthesis (Gate-Level):**
✅ Mixed RTL/Gate simulation
- Critical path macros as gates (e.g., core, MDU)
- Peripherals still in RTL (easier debug)
- Sanity check for synthesis correctness

### **Before Tape-Out (Post-P&R):**
✅ Full gate-level with timing
- All macros as gates
- SDF timing annotation
- Check for setup/hold violations
- Verify actual chip timing

---

## 📊 SIMULATION PERFORMANCE COMPARISON

| Method | Compile Time | Run Time | Debug Ease | Accuracy |
|--------|--------------|----------|------------|----------|
| **RTL** | Fast (seconds) | Fast | ★★★★★ Easy | Functional only |
| **Post-Synth** | Slow (minutes) | Medium | ★★★☆☆ Harder | Gate-level functional |
| **Post-P&R** | Slow (minutes) | Slow | ★★☆☆☆ Hard | Near-silicon |

**Recommendation:** Use RTL for 95% of testing, gate-level for final verification.

---

## ✅ SUMMARY

### **Pre-Synthesis (RTL):**
- ✅ **YES, still works!** Macros are just organizational wrappers
- ✅ Compile all `.v` files together like before
- ✅ Test individual macros, hierarchical core, or full SoC
- ✅ Fast, easy debugging with full visibility

### **Post-Synthesis (Gates):**
- ✅ Use gate-level netlists from `outputs/` directories
- ✅ Need SKY130 standard cell library for primitives
- ✅ Add SDF for timing annotation
- ✅ Mixed RTL/gate simulation recommended for debug

### **Post-P&R (Final):**
- ✅ Use final netlists with parasitics
- ✅ Full timing verification
- ✅ Slower but most accurate

### **Key Insight:**
Your macro structure doesn't change the testing flow - it's just better organized! The macros are transparent wrappers that make physical design easier while keeping RTL simulation simple.

---

**Next Steps:**
1. Continue using your existing sim/ testbenches
2. Create `tb_hierarchical_core.v` for 2-macro testing  
3. Create `tb_soc_complete.v` for full 6-macro testing
4. After synthesis, try post-synth simulation with gates

Would you like me to create these testbenches for you?
