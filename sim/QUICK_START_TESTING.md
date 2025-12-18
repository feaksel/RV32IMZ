# Quick Start: Testing Your Hierarchical Macros

## ✅ You Can Test Pre-Synthesis RIGHT NOW!

Your macro structure doesn't prevent testing - the macros are just organizational wrappers around the real RTL logic.

---

## 🚀 IMMEDIATE TESTING (Pre-Synthesis RTL)

### Test the Hierarchical Core (MDU + Core macros):

```bash
cd /home/furka/RV32IMZ/sim

# Run RTL simulation
make -f Makefile.hierarchical rtl_sim

# View waveforms
make -f Makefile.hierarchical wave
```

**What it tests:**

- ✅ MDU macro (multiply/divide operations)
- ✅ Core macro (pipeline, register file, ALU)
- ✅ Inter-macro communication
- ✅ Simple test program: ADD, MUL, DIV, LOAD, STORE

**Expected output:**

```
========================================
Hierarchical Core Test Starting
Testing: MDU Macro + Core Macro
========================================

[100] Reset released
[150] IFETCH: addr=0x00000000 data=0x00000033
[160] Instruction #1 executed at PC=0x00000000
...
[450] STORE: addr=0x00000000 data=0x0000000a sel=1111
[460] LOAD:  addr=0x00000000 data=0x0000000a

========================================
Test Results
========================================
Instructions executed: 7
Data memory[0] = 0x0000000a (should be 0x0000000a = 10)

✓ TEST PASSED!
  - MUL operation worked (10 * 5 = 50)
  - DIV operation worked (50 / 5 = 10)
  - Memory store/load worked
========================================
```

---

## 🏗️ AFTER SYNTHESIS (Gate-Level Testing)

### Step 1: Build all macros

```bash
cd /home/furka/RV32IMZ/distribution/rv32im_core_only/macros
./build_complete_proven_package.sh
```

Wait for synthesis to complete (~20-40 minutes).

### Step 2: Run post-synthesis simulation

```bash
cd /home/furka/RV32IMZ/sim

# Check what's available
make -f Makefile.hierarchical status

# Run gate-level simulation
make -f Makefile.hierarchical post_synth_sim
```

**What it tests:**

- ✅ Synthesized gate-level netlists (actual standard cells)
- ✅ Functional correctness after synthesis
- ✅ Catches synthesis-introduced bugs
- ⚠️ No timing yet (unit delay)

---

## ⏱️ AFTER PLACE & ROUTE (Full Timing)

### Run post-P&R simulation with timing:

```bash
cd /home/furka/RV32IMZ/sim
make -f Makefile.hierarchical post_pr_sim
```

**What it tests:**

- ✅ Final gate-level netlist with routing
- ✅ Real interconnect delays (from SDF file)
- ✅ Setup/hold timing violations
- ✅ Near-silicon accuracy

---

## 📊 WHAT EACH TEST LEVEL GIVES YOU

| Test Level     | Speed        | Accuracy     | When to Use                              |
| -------------- | ------------ | ------------ | ---------------------------------------- |
| **RTL**        | ⚡ Fast      | Functional   | Development, debugging (use 95% of time) |
| **Post-Synth** | 🐢 Slow      | Gate-level   | After synthesis, sanity check            |
| **Post-P&R**   | 🐌 Very Slow | Near-silicon | Before tape-out, final verification      |

---

## 🧪 TESTING YOUR EXISTING DESIGNS

Your current sim/ directory already has many testbenches. You can use them with macros too!

### Use existing SoC testbench with macros:

```bash
cd /home/furka/RV32IMZ/sim

# Modify Makefile.soc_top to include macro RTL
# Add these to RTL_CORE section:
# ../distribution/rv32im_core_only/macros/rv32im_hierarchical_top.v
# ../distribution/rv32im_core_only/macros/mdu_macro/rtl/*.v
# ../distribution/rv32im_core_only/macros/core_macro/rtl/*.v

make -f Makefile.soc_top all
```

---

## 🎯 RECOMMENDED WORKFLOW

### During Development:

1. ✅ **Use RTL simulation exclusively**
   - Fast compile/run times
   - Easy debugging with waveforms
   - Full signal visibility
   ```bash
   make -f Makefile.hierarchical rtl_sim
   gtkwave tb_hierarchical_core.vcd
   ```

### After Synthesis:

2. ✅ **Quick gate-level check**
   - Verify synthesis didn't break functionality
   - 1-2 test runs, not exhaustive
   ```bash
   make -f Makefile.hierarchical post_synth_sim
   ```

### Before Tape-Out:

3. ✅ **Full timing verification**
   - Run complete test suite with SDF timing
   - Check for timing violations
   ```bash
   make -f Makefile.hierarchical post_pr_sim
   ```

---

## 🔍 DEBUGGING TIPS

### View internal macro signals in waveforms:

```bash
# Run simulation
make -f Makefile.hierarchical rtl_sim

# Open waveform
gtkwave tb_hierarchical_core.vcd

# In GTKWave, expand hierarchy:
# - tb_hierarchical_core
#   - dut (rv32im_hierarchical_top)
#     - u_mdu_macro (MDU macro)
#       - mdu_inst (actual MDU implementation)
#     - u_core_macro (Core macro)
#       - pc, instruction, regfile, etc.
```

You have **full visibility** into macro internals in RTL simulation!

### Add custom monitoring in testbench:

```verilog
// In tb_hierarchical_core.v, add:
always @(posedge clk) begin
    if (dut.u_mdu_macro.mdu_inst.busy) begin
        $display("[MDU] Operation in progress: funct3=%b",
                 dut.u_mdu_macro.mdu_inst.funct3);
    end
    if (dut.u_mdu_macro.mdu_inst.done) begin
        $display("[MDU] Result: product=%h quotient=%h",
                 dut.u_mdu_macro.mdu_inst.product,
                 dut.u_mdu_macro.mdu_inst.quotient);
    end
end
```

---

## ✅ FILES CREATED FOR YOU

1. **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Comprehensive testing documentation
2. **[testbench/tb_hierarchical_core.v](testbench/tb_hierarchical_core.v)** - Complete testbench for 2-macro core
3. **[Makefile.hierarchical](Makefile.hierarchical)** - Build system for all test levels

---

## 🎓 KEY TAKEAWAYS

### **Pre-Synthesis:**

- ✅ **Works exactly like before** - macros are transparent
- ✅ Compile all `.v` files together
- ✅ Fast simulation, easy debugging
- ✅ **Use this for 95% of your testing**

### **Post-Synthesis:**

- ✅ Use gate-level netlists from `outputs/` directories
- ✅ Need SKY130 standard cell models
- ✅ Slower but verifies synthesis correctness

### **Post-P&R:**

- ✅ Includes real interconnect delays
- ✅ Most accurate (near-silicon)
- ✅ Use for final verification

### **The Magic:**

Your macros are just organizational wrappers - they make physical design easier **without complicating simulation!** 🎉

---

## 🚀 TRY IT NOW!

```bash
cd /home/furka/RV32IMZ/sim
make -f Makefile.hierarchical rtl_sim
```

You should see a passing test in seconds! ✨
