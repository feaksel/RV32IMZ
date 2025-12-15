# Complete SoC Synthesis Strategy: RTL to GDSII

**Project:** Custom RISC-V SoC for 5-Level Inverter Control
**Target:** Academic Homework (RTL-to-GDSII Flow) + Real Application
**Tools:** Cadence Genus (synthesis) + Innovus (place & route) + Open-source verification
**Document Version:** 1.0
**Last Updated:** 2025-12-09

---

## Table of Contents

1. [Overview](#1-overview)
2. [Design Hierarchy](#2-design-hierarchy)
3. [Strategic Decision: CPU-Only vs Full SoC](#3-strategic-decision-cpu-only-vs-full-soc)
4. [Home Development Workflow (Open-Source)](#4-home-development-workflow-open-source)
5. [School Synthesis Workflow (Cadence)](#5-school-synthesis-workflow-cadence)
6. [Memory Strategy](#6-memory-strategy)
7. [Clock and Reset Strategy](#7-clock-and-reset-strategy)
8. [Constraint Development](#8-constraint-development)
9. [Synthesis Optimization](#9-synthesis-optimization)
10. [Place and Route Strategy](#10-place-and-route-strategy)
11. [Verification Strategy](#11-verification-strategy)
12. [Common Issues and Solutions](#12-common-issues-and-solutions)
13. [Homework Submission Checklist](#13-homework-submission-checklist)
14. [Complete Genus Script Examples](#14-complete-genus-script-examples)
15. [Timeline and Effort Estimation](#15-timeline-and-effort-estimation)

---

## 1. Overview

### 1.1 What is RTL-to-GDSII Flow?

**Complete Digital IC Design Flow:**

```
┌────────────────────────────────────────────────────────────┐
│                    RTL Design (Verilog)                    │
│  • Behavioral description of hardware                      │
│  • Module hierarchy (core.v, alu.v, regfile.v, ...)       │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│              Functional Verification (Home)                │
│  • Icarus Verilog: Compile and simulate                    │
│  • Testbenches: Verify behavior                            │
│  • Waveform analysis: GTKWave                              │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│                 Lint Check (Optional)                      │
│  • Verilator: Check for common RTL errors                  │
│  • Yosys: Basic synthesis check                            │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│         SYNTHESIS (Cadence Genus @ School) ★               │
│  • Convert RTL → Gate-level netlist                        │
│  • Technology mapping (standard cells)                     │
│  • Optimization (area, timing, power)                      │
│  • Output: Verilog netlist + constraints                   │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│        PLACE & ROUTE (Cadence Innovus @ School) ★          │
│  • Floorplanning: Arrange blocks                           │
│  • Placement: Position standard cells                      │
│  • Clock tree synthesis: Distribute clock                  │
│  • Routing: Connect wires                                  │
│  • Optimization: Fix timing violations                     │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│              Sign-off Verification                         │
│  • DRC: Design rule check                                  │
│  • LVS: Layout vs schematic                                │
│  • STA: Static timing analysis                             │
│  • Power analysis                                          │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│                   GDSII Generation                         │
│  • Final layout file for fabrication                       │
│  • Ready for tape-out                                      │
└────────────────────────────────────────────────────────────┘
```

### 1.2 Your Two-Track Strategy

**Track 1: Home (Daily Development)**
- Use open-source tools (Icarus, Yosys, Verilator)
- Fast iteration: edit → compile → simulate → debug
- No license restrictions
- Learn and develop freely

**Track 2: School (Final Submission)**
- Use Cadence tools (Genus, Innovus)
- Professional-grade synthesis
- Generate GDSII for homework
- Submit once when RTL is ready

**Why This Works:**
- ✅ Develop 95% at home (fast, free)
- ✅ Synthesize 5% at school (1-2 sessions)
- ✅ No time wasted waiting for licenses
- ✅ Learn industry tools when it matters

### 1.3 Homework Requirements

**What Professor Expects:**

| Deliverable | Description | Format |
|-------------|-------------|--------|
| RTL Source | Verilog modules | `.v` files |
| Testbenches | Verification tests | `tb_*.v` files |
| Simulation Results | Waveforms proving correctness | `.vcd` or screenshots |
| Synthesis Netlist | Gate-level design | `netlist.v` |
| Timing Report | STA results | `.rpt` file |
| Area Report | Gate count, die size | `.rpt` file |
| Power Report | Estimated power | `.rpt` file |
| Layout (GDSII) | Final physical design | `.gds` file |
| Design Report | Explanation document | `.pdf` (10-20 pages) |

**Grading Weights (Typical):**
- RTL Design & Verification: 30%
- Synthesis Quality: 25%
- Physical Design: 25%
- Reports & Documentation: 20%

### 1.4 Technology Node

**Your School Likely Provides:**
- **Process:** 180nm, 130nm, 90nm, or 45nm CMOS
- **Standard Cell Library:** Synopsys, ARM, or university library
- **Voltage:** 1.8V (180nm), 1.2V (130nm), 1.0V (90nm)

**Example (180nm technology):**
- Gate delay: ~0.1 ns
- Wire delay: ~0.05 ns/µm
- Minimum feature size: 180nm
- Die size limit: ~5mm × 5mm (typical student project)

---

## 2. Design Hierarchy

### 2.1 Complete SoC Structure

```
soc_top.v (TOP LEVEL)
├── custom_riscv_core.v ★ (CPU CORE)
│   ├── regfile.v ★ (YOU IMPLEMENT)
│   ├── alu.v ★ (YOU IMPLEMENT)
│   ├── decoder.v ★ (YOU IMPLEMENT)
│   └── control_fsm.v (state machine)
├── wishbone_interconnect.v (bus arbiter)
├── rom.v (instruction memory)
├── ram.v (data memory)
├── peripherals/
│   ├── pwm_generator.v
│   ├── adc_interface.v
│   ├── uart.v
│   ├── gpio.v
│   ├── timer.v
│   └── protection.v
```

**Module Complexity:**

| Module | Lines of Code | Gates (Est.) | Synthesize? |
|--------|---------------|--------------|-------------|
| **regfile.v** | ~50 | 1,024 | ✅ Yes |
| **alu.v** | ~100 | 2,000 | ✅ Yes |
| **decoder.v** | ~200 | 500 | ✅ Yes |
| **control_fsm.v** | ~150 | 300 | ✅ Yes |
| **custom_riscv_core.v** | ~400 | 5,000 | ✅ Yes (top) |
| **wishbone_interconnect.v** | ~200 | 1,000 | ✅ Yes |
| **rom.v** | ~50 | Special | ⚠️ Replace with SRAM |
| **ram.v** | ~50 | Special | ⚠️ Replace with SRAM |
| **pwm_generator.v** | ~200 | 1,500 | ✅ Yes |
| **uart.v** | ~300 | 2,000 | ✅ Yes |
| **Full SoC** | ~2,000 | 50,000 | ⚠️ Optional |

### 2.2 What to Synthesize for Homework

**Option A: CPU Core Only (Safe, Meets Requirements)**

```
Synthesize:
└── custom_riscv_core.v
    ├── regfile.v
    ├── alu.v
    ├── decoder.v
    └── control_fsm.v

Result:
- Gate count: ~5,000 gates
- Area: ~0.012 mm² @ 180nm
- Timing: Achievable at 50 MHz
- Homework: ✅ Meets all requirements
- Time @ school: 1 hour
```

**Option B: CPU + Memories (Realistic)**

```
Synthesize:
└── cpu_with_memory.v
    ├── custom_riscv_core.v
    ├── sram_controller.v
    └── (SRAM macros from library)

Result:
- Gate count: ~8,000 gates
- Area: ~0.5 mm² (including SRAM)
- Timing: Achievable at 100 MHz
- Homework: ✅ Exceeds requirements
- Time @ school: 2 hours
```

**Option C: Full SoC (Ambitious, Publication-Worthy)**

```
Synthesize:
└── soc_top.v
    ├── custom_riscv_core.v
    ├── wishbone_interconnect.v
    ├── sram_controller.v
    ├── pwm_generator.v
    ├── uart.v
    ├── gpio.v
    ├── timer.v
    └── protection.v

Result:
- Gate count: ~50,000 gates
- Area: ~1.0 mm² @ 180nm
- Timing: Achievable at 50 MHz (carefully)
- Homework: ✅ A+ material, conference paper potential
- Time @ school: 4-6 hours
```

**My Recommendation:** Start with **Option A** (CPU only), synthesize it first as backup. If time permits, upgrade to **Option C** (Full SoC) for impressive results.

### 2.3 Module Ownership

**What YOU Must Implement (Required for Homework):**

```verilog
// regfile.v - Register file (32 × 32-bit registers)
module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  rs1_addr,    // Read port 1
    input  wire [4:0]  rs2_addr,    // Read port 2
    output reg  [31:0] rs1_data,
    output reg  [31:0] rs2_data,
    input  wire [4:0]  rd_addr,     // Write port
    input  wire [31:0] rd_data,
    input  wire        rd_we        // Write enable
);
    // YOUR CODE HERE
endmodule

// alu.v - Arithmetic Logic Unit
module alu (
    input  wire [31:0] a,           // Operand A
    input  wire [31:0] b,           // Operand B
    input  wire [3:0]  alu_op,      // Operation select
    output reg  [31:0] result,      // Result
    output wire        zero         // Zero flag
);
    // YOUR CODE HERE
endmodule

// decoder.v - Instruction decoder
module decoder (
    input  wire [31:0] instruction, // 32-bit instruction
    output reg  [6:0]  opcode,
    output reg  [4:0]  rd,
    output reg  [4:0]  rs1,
    output reg  [4:0]  rs2,
    output reg  [31:0] imm,         // Sign-extended immediate
    // ... control signals ...
);
    // YOUR CODE HERE
endmodule
```

**What's Already Provided (Use As-Is):**
- Wishbone interconnect
- Peripheral controllers
- Testbenches
- SoC integration

---

## 3. Strategic Decision: CPU-Only vs Full SoC

### 3.1 Comparison Matrix

| Aspect | CPU Only | CPU + Memories | Full SoC |
|--------|----------|----------------|----------|
| **Gate Count** | 5,000 | 8,000 | 50,000 |
| **Die Area** | 0.012 mm² | 0.5 mm² | 1.0 mm² |
| **Synthesis Time** | 30 min | 1 hour | 2-3 hours |
| **P&R Time** | 30 min | 1 hour | 2-3 hours |
| **Timing Closure** | Easy | Moderate | Challenging |
| **Homework Grade** | A (meets req) | A (exceeds) | A+ (impressive) |
| **Learning Value** | Moderate | High | Very High |
| **Risk Level** | Low | Low | Medium |
| **Publication Potential** | No | No | Yes |
| **Debugging Time** | Low | Medium | High |

### 3.2 Decision Tree

```
START: Do you have time for synthesis at school?
│
├─ YES (4+ hours available)
│  │
│  └─ Do you want maximum grade/publication?
│     │
│     ├─ YES → Full SoC (Option C) ★ BEST OUTCOME
│     │
│     └─ NO → CPU + Memories (Option B)
│
└─ NO (only 1-2 hours available)
   │
   └─ CPU Only (Option A) ✓ SAFE CHOICE
```

### 3.3 Recommended Strategy: Dual Submission

**Week 1-3: Implement RTL (at home)**
- Write all three modules (regfile, alu, decoder)
- Verify with testbenches
- Test full SoC in simulation
- Prepare both CPU-only and Full SoC versions

**Week 4: First School Visit (2 hours)**
- Synthesize CPU-only (Option A)
- Complete P&R
- Generate GDSII
- **This is your backup submission** ✅

**Week 4-5: If Successful**
- Optimize any timing issues
- Clean up SoC integration

**Week 5: Second School Visit (4 hours, optional)**
- Synthesize Full SoC (Option C)
- Complete P&R with careful floorplanning
- Generate GDSII
- **This is your impressive submission** ⭐

**Result:** You have two submissions:
1. Safe CPU-only (guaranteed to work)
2. Ambitious Full SoC (if time permits)

Submit whichever you're most confident in!

---

## 4. Home Development Workflow (Open-Source)

### 4.1 Tool Setup

**Required Tools (Install Once):**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    iverilog \        # Icarus Verilog (simulator)
    gtkwave \         # Waveform viewer
    yosys \           # Open-source synthesis
    verilator \       # Lint checker
    make \            # Build automation
    git               # Version control

# Verify installation
iverilog -v          # Should show version
yosys -V             # Should show version
verilator --version  # Should show version
```

**Optional (Recommended):**
```bash
# GTKWave configuration for better viewing
mkdir -p ~/.gtkwave
echo "fontname Monospace 10" > ~/.gtkwave/gtkwaverc
```

### 4.2 Daily Development Cycle

**Typical Workflow (10-30 minutes per iteration):**

```bash
# 1. Edit RTL
vim rtl/core/alu.v

# 2. Compile (check syntax)
cd sim
make compile MODULE=alu
# → Checks for syntax errors

# 3. Run testbench
make test MODULE=alu
# → Runs tb_alu.v, generates waveform

# 4. View waveforms
gtkwave tb_alu.vcd &
# → Inspect signals visually

# 5. If pass, commit
git add rtl/core/alu.v
git commit -m "feat: Implement ALU ADD/SUB operations"

# 6. Repeat for next module
```

**Example Session:**

```
$ cd ~/5level-inverter/02-embedded/riscv

$ make test-alu
iverilog -o tb_alu.out \
    -I rtl/core \
    sim/tb_alu.v \
    rtl/core/alu.v
vvp tb_alu.out
VCD info: dumpfile tb_alu.vcd opened for output.
[TEST] ALU ADD: 5 + 3 = 8 ✓
[TEST] ALU SUB: 10 - 4 = 6 ✓
[TEST] ALU AND: 0xFF & 0x0F = 0x0F ✓
[TEST] ALU OR:  0xF0 | 0x0F = 0xFF ✓
All tests passed!

$ gtkwave tb_alu.vcd &
# View waveforms
```

### 4.3 Verification Checklist (Before Going to School)

**Pre-Synthesis Verification (Do ALL at Home):**

- [ ] All modules compile without errors
  ```bash
  make compile-all
  ```

- [ ] All unit tests pass
  ```bash
  make test-regfile  # ✓ Pass
  make test-alu      # ✓ Pass
  make test-decoder  # ✓ Pass
  make test-core     # ✓ Pass
  ```

- [ ] Integration test passes
  ```bash
  make test-integration
  # Should run simple program (add, branch, load/store)
  ```

- [ ] Verilator lint check clean
  ```bash
  verilator --lint-only rtl/core/custom_riscv_core.v
  # Should show no warnings
  ```

- [ ] Yosys synthesis test (no errors)
  ```bash
  cd synthesis/opensource
  make synth-test
  # Should generate netlist without errors
  ```

- [ ] Waveforms inspected for all tests
  - Register writes happen correctly
  - ALU outputs are correct
  - Memory reads/writes work
  - Branches execute properly

**If ALL checkboxes pass → Ready for school synthesis!** ✅

### 4.4 Test Program for Verification

**Minimal Test Program (verify core works):**

```assembly
# test.s - Simple program to verify CPU

.text
.globl _start

_start:
    # Test 1: Register operations
    li   x1, 10        # x1 = 10
    li   x2, 20        # x2 = 20
    add  x3, x1, x2    # x3 = 30

    # Test 2: Memory operations
    li   x4, 0x1000    # Address
    sw   x3, 0(x4)     # Store 30 to memory
    lw   x5, 0(x4)     # Load back

    # Test 3: Branch
    li   x6, 30
    beq  x5, x6, pass  # Should branch (30 == 30)
    li   x7, 0         # FAIL: x7 = 0
    j    end

pass:
    li   x7, 1         # PASS: x7 = 1

end:
    # Infinite loop (success if x7 == 1)
    j    end
```

**Compile and Load:**

```bash
# Compile to binary
riscv32-unknown-elf-as -march=rv32i test.s -o test.o
riscv32-unknown-elf-ld -T linker.ld test.o -o test.elf
riscv32-unknown-elf-objcopy -O binary test.elf test.bin

# Convert to Verilog hex for ROM
hexdump -v -e '1/4 "%08x\n"' test.bin > test.hex

# Copy to simulation directory
cp test.hex sim/rom_contents.hex

# Run simulation
cd sim
make test-core
# Verify: x7 should be 1 at end
```

**Success Criteria:**
- x1 = 10 (0x0000000A)
- x2 = 20 (0x00000014)
- x3 = 30 (0x0000001E)
- x5 = 30 (loaded from memory)
- x7 = 1 (test passed!)

---

## 5. School Synthesis Workflow (Cadence)

### 5.1 Environment Setup

**First Time at School Lab:**

```bash
# 1. Source Cadence setup (provided by school)
source /tools/cadence/setup.csh
# or
source /tools/cadence/setup.sh

# 2. Verify tools available
which genus     # Should show path: /tools/cadence/.../bin/genus
which innovus   # Should show path: /tools/cadence/.../bin/innovus

# 3. Check license
lmstat -a       # Should show licenses available

# 4. Copy your RTL to school workstation
scp -r ~/5level-inverter/02-embedded/riscv/ school-server:~/

# 5. Navigate to project
cd ~/riscv
```

### 5.2 Technology Library Setup

**Your school provides standard cell library:**

```bash
# Typical location (ask TA for exact path)
export PDK_ROOT=/tools/pdk/180nm
export STD_CELL_LIB=${PDK_ROOT}/lib/typical.lib
export TECH_LEF=${PDK_ROOT}/lef/tech.lef
export STD_CELL_LEF=${PDK_ROOT}/lef/stdcells.lef

# Verify files exist
ls $STD_CELL_LIB     # Should show .lib file
ls $TECH_LEF         # Should show .lef file
```

**Standard Cell Library Contains:**
- Logic gates (AND, OR, NAND, NOR, XOR, INV, BUF)
- Flip-flops (DFF with various features)
- Latches
- Multiplexers
- Adders (half, full)
- Timing/power/area data for each cell

### 5.3 Complete Genus Synthesis Flow

**Step-by-Step Synthesis (CPU Core Only):**

**STEP 1: Create Synthesis Script**

File: `scripts/synthesize_cpu.tcl`

```tcl
#===============================================================================
# Genus Synthesis Script for RISC-V CPU Core
# Target: Academic RTL-to-GDSII homework
# Author: Your Name
# Date: 2025-12-09
#===============================================================================

# Set variables
set DESIGN_NAME "custom_riscv_core"
set CLK_PERIOD 20.0 ;# 50 MHz (20ns period)
set PDK_ROOT "/tools/pdk/180nm"
set RTL_DIR "../rtl"

puts "========================================"
puts "Starting synthesis for $DESIGN_NAME"
puts "Target frequency: [expr 1000.0 / $CLK_PERIOD] MHz"
puts "========================================"

#===============================================================================
# 1. Setup Library
#===============================================================================

puts "\n[1/9] Setting up technology library..."

# Set up library search paths
set_attribute lib_search_path [list \
    ${PDK_ROOT}/lib \
    ${PDK_ROOT}/lef \
]

# Read timing library (.lib file)
set_attribute library [list \
    typical.lib \
]

# Optional: Read additional libraries for better cells
# set_attribute library [list typical.lib fast.lib slow.lib]

puts "Library setup complete ✓"

#===============================================================================
# 2. Read RTL
#===============================================================================

puts "\n[2/9] Reading RTL files..."

# Read Verilog files in dependency order
read_hdl -sv [list \
    ${RTL_DIR}/core/riscv_defines.vh \
    ${RTL_DIR}/core/regfile.v \
    ${RTL_DIR}/core/alu.v \
    ${RTL_DIR}/core/decoder.v \
    ${RTL_DIR}/core/control_fsm.v \
    ${RTL_DIR}/core/custom_riscv_core.v \
]

puts "RTL read complete ✓"

#===============================================================================
# 3. Elaborate Design
#===============================================================================

puts "\n[3/9] Elaborating design..."

elaborate $DESIGN_NAME

puts "Elaboration complete ✓"

#===============================================================================
# 4. Apply Constraints
#===============================================================================

puts "\n[4/9] Applying constraints..."

# Create clock
create_clock -name clk -period $CLK_PERIOD [get_ports clk]

# Set input delay (assume inputs arrive 2ns after clock edge)
set_input_delay -clock clk -max 2.0 [all_inputs]
set_input_delay -clock clk -min 0.5 [all_inputs]

# Set output delay (outputs must be stable 2ns before next clock)
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.5 [all_outputs]

# Set load capacitance on outputs (typical: 0.01 pF)
set_load 0.01 [all_outputs]

# Set driving cell for inputs (typical: medium buffer)
set_driving_cell -lib_cell BUFX2 [all_inputs]

# Clock uncertainty (jitter, skew)
set_clock_uncertainty 0.5 [get_clocks clk]

# Clock transition (rise/fall time)
set_clock_transition 0.3 [get_clocks clk]

# Don't touch reset (will be handled by reset tree)
set_dont_touch [get_ports rst_n]

# Operating conditions
set_operating_conditions typical

puts "Constraints applied ✓"
puts "  Clock period: ${CLK_PERIOD} ns"
puts "  Target freq:  [expr 1000.0 / $CLK_PERIOD] MHz"

#===============================================================================
# 5. Synthesize to Generic Gates
#===============================================================================

puts "\n[5/9] Synthesizing to generic gates..."

# First-pass synthesis (no optimization, just functional)
syn_generic

puts "Generic synthesis complete ✓"

# Check for errors
check_design

#===============================================================================
# 6. Map to Technology
#===============================================================================

puts "\n[6/9] Mapping to technology library..."

# Map to actual standard cells
syn_map

puts "Technology mapping complete ✓"

#===============================================================================
# 7. Optimize Design
#===============================================================================

puts "\n[7/9] Optimizing design..."

# Optimize for area and timing
syn_opt

# Additional optimization passes
syn_opt -incremental

puts "Optimization complete ✓"

#===============================================================================
# 8. Generate Reports
#===============================================================================

puts "\n[8/9] Generating reports..."

# Create reports directory
file mkdir ../reports

# Timing report
report_timing -nworst 10 -max_paths 10 > ../reports/timing.rpt
puts "  → reports/timing.rpt"

# Area report
report_area > ../reports/area.rpt
puts "  → reports/area.rpt"

# Power report
report_power > ../reports/power.rpt
puts "  → reports/power.rpt"

# Gate count report
report_gates > ../reports/gates.rpt
puts "  → reports/gates.rpt"

# QoR (Quality of Results) summary
report_qor > ../reports/qor.rpt
puts "  → reports/qor.rpt"

puts "Reports generated ✓"

#===============================================================================
# 9. Write Outputs
#===============================================================================

puts "\n[9/9] Writing output files..."

# Create output directory
file mkdir ../outputs

# Write gate-level netlist (Verilog)
write_hdl -generic > ../outputs/${DESIGN_NAME}_netlist.v
puts "  → outputs/${DESIGN_NAME}_netlist.v"

# Write constraints (SDC format)
write_sdc > ../outputs/${DESIGN_NAME}.sdc
puts "  → outputs/${DESIGN_NAME}.sdc"

# Write SDF (Standard Delay Format) for timing simulation
write_sdf > ../outputs/${DESIGN_NAME}.sdf
puts "  → outputs/${DESIGN_NAME}.sdf"

puts "\n========================================"
puts "Synthesis complete!"
puts "========================================"

# Summary
puts "\nSummary:"
puts "--------"
set area [get_attr [get_designs $DESIGN_NAME] area]
set gates [sizeof_collection [get_cells -hier -filter "is_sequential==false"]]
set regs [sizeof_collection [get_cells -hier -filter "is_sequential==true"]]
puts "Total area:    [format %.2f $area] µm²"
puts "Gate count:    $gates"
puts "Register count: $regs"

# Timing summary
set slack [get_attribute [get_timing_paths] slack]
if {$slack >= 0} {
    puts "Timing:        ✓ MET (slack: [format %.3f $slack] ns)"
} else {
    puts "Timing:        ✗ VIOLATED (slack: [format %.3f $slack] ns)"
}

puts "\nNext steps:"
puts "  1. Review reports in reports/ directory"
puts "  2. If timing met, proceed to P&R (Innovus)"
puts "  3. If timing violated, relax constraints or optimize RTL"

# Exit Genus
exit
```

**STEP 2: Run Synthesis**

```bash
# At school computer
cd ~/riscv/scripts

# Launch Genus in batch mode
genus -batch -files synthesize_cpu.tcl -log synthesis.log

# Watch progress
tail -f synthesis.log

# When done (10-30 minutes), check results
ls ../outputs/
# Should see:
#   custom_riscv_core_netlist.v  ← Gate-level netlist
#   custom_riscv_core.sdc        ← Timing constraints
#   custom_riscv_core.sdf        ← Delay information
```

**STEP 3: Review Reports**

```bash
cd ../reports

# 1. Check timing
cat timing.rpt | grep "Slack"
# Look for: Slack (MET) : 2.345ns  ← GOOD (positive slack)
#       or: Slack (VIOLATED) : -0.5ns ← BAD (negative slack)

# 2. Check area
cat area.rpt | grep "Total cell area"
# Example: Total cell area: 12345.67 µm²

# 3. Check gate count
cat gates.rpt | grep "Total"
# Example: Total gates: 5234

# 4. Check power
cat power.rpt | grep "Total Power"
# Example: Total Power: 12.34 mW

# 5. Overall QoR
cat qor.rpt
# Shows summary of everything
```

**Success Criteria:**
- ✅ Timing slack > 0 (timing met)
- ✅ Area < 0.02 mm² (reasonable for CPU)
- ✅ Gate count: 3,000-8,000 (expected range)
- ✅ No errors or critical warnings in log

**If Timing Violated:**

```tcl
# Option 1: Relax clock period (lower frequency)
set CLK_PERIOD 25.0  ;# Was 20.0, now 40 MHz instead of 50 MHz

# Option 2: Add more optimization effort
syn_opt -effort high

# Option 3: Enable compile-time optimizations
set_attribute syn_map_effort high
set_attribute syn_opt_effort high
```

### 5.4 Full SoC Synthesis

**For Full SoC (if attempting Option C):**

File: `scripts/synthesize_soc.tcl`

```tcl
#===============================================================================
# Genus Synthesis Script for Complete SoC
#===============================================================================

set DESIGN_NAME "soc_top"
set CLK_PERIOD 20.0

# Read ALL RTL files
read_hdl -sv [list \
    # Core
    ${RTL_DIR}/core/riscv_defines.vh \
    ${RTL_DIR}/core/regfile.v \
    ${RTL_DIR}/core/alu.v \
    ${RTL_DIR}/core/decoder.v \
    ${RTL_DIR}/core/control_fsm.v \
    ${RTL_DIR}/core/custom_riscv_core.v \
    # Bus
    ${RTL_DIR}/bus/wishbone_interconnect.v \
    # Peripherals
    ${RTL_DIR}/peripherals/pwm_generator.v \
    ${RTL_DIR}/peripherals/adc_interface.v \
    ${RTL_DIR}/peripherals/uart.v \
    ${RTL_DIR}/peripherals/gpio.v \
    ${RTL_DIR}/peripherals/timer.v \
    ${RTL_DIR}/peripherals/protection.v \
    # Top level
    ${RTL_DIR}/soc_top.v \
]

# NOTE: Exclude RAM/ROM (will be replaced with SRAM macros)

elaborate $DESIGN_NAME

# Apply constraints (same as before)
create_clock -name clk -period $CLK_PERIOD [get_ports clk]
# ... (same constraint commands)

# Synthesize
syn_generic
syn_map
syn_opt

# Reports
report_timing > ../reports/soc_timing.rpt
report_area > ../reports/soc_area.rpt
report_power > ../reports/soc_power.rpt

# Write outputs
write_hdl > ../outputs/soc_top_netlist.v
write_sdc > ../outputs/soc_top.sdc

exit
```

**Expected Full SoC Results:**
- Gate count: 40,000-60,000
- Area: 0.8-1.2 mm²
- Timing: May require 40 MHz instead of 50 MHz
- Synthesis time: 1-3 hours

---

## 6. Memory Strategy

### 6.1 The Memory Problem

**Issue:** Behavioral RAM/ROM models don't synthesize well.

```verilog
// This WON'T work in synthesis:
module rom (
    input  wire [31:0] addr,
    output reg  [31:0] data
);
    reg [31:0] memory [0:8191];  // 32KB ROM

    initial begin
        $readmemh("program.hex", memory);  // ← Synthesis can't handle this!
    end

    always @(*) begin
        data = memory[addr[14:2]];  // ← This becomes 8192 muxes! (huge)
    end
endmodule
```

**Why It's Bad:**
- ❌ Synthesizes to giant mux tree (8192:1 mux!)
- ❌ Massive area (100,000+ gates just for ROM)
- ❌ Very slow (long mux chain)
- ❌ Not how real chips work

### 6.2 Solution: Use SRAM Macros

**Real chips use memory compilers:**

```
Your school's PDK includes:
- SRAM Generator Tool
- Pre-designed memory blocks (macros)
- Example: 32KB SRAM = one compact block

How it works:
1. You specify size (e.g., 32KB, 32-bit wide)
2. Memory compiler generates optimized layout
3. You instantiate macro in your design
```

**SRAM Macro Instantiation:**

```verilog
// Use SRAM macro instead of behavioral memory
module soc_with_sram (
    input  wire        clk,
    input  wire        rst_n,
    // ... other ports ...
);

    // Instantiate SRAM macro from library
    // (Exact name/port depends on your school's PDK)
    sram_sp_32kx32 u_rom (
        .clk(clk),
        .addr(rom_addr[14:2]),   // Word-addressed
        .din(32'h0),             // ROM: no writes
        .dout(rom_data),
        .we(1'b0),               // Write enable = 0 (read-only)
        .ce(rom_ce)              // Chip enable
    );

    sram_sp_64kx32 u_ram (
        .clk(clk),
        .addr(ram_addr[15:2]),   // Word-addressed
        .din(ram_wdata),
        .dout(ram_rdata),
        .we(ram_we),
        .ce(ram_ce)
    );

    // Your CPU core
    custom_riscv_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        // Connect to SRAM via wishbone
        // ...
    );

endmodule
```

### 6.3 Practical Approach for Homework

**Three-Tier Strategy:**

**Tier 1: Simulation (At Home)**
```verilog
// Use behavioral model for fast simulation
`ifdef SIMULATION
    `include "rom_behavioral.v"
    `include "ram_behavioral.v"
`endif
```

**Tier 2: Synthesis (CPU Only)**
```
Synthesize ONLY the CPU core
Don't include memories at all
Memory ports become top-level I/O

This is Option A: CPU-only synthesis
```

**Tier 3: Synthesis (Full SoC with Real Memories)**
```verilog
// Use SRAM macros for real synthesis
`ifdef SYNTHESIS
    `include "sram_macros.v"
`endif
```

**Conditional Compilation:**

```verilog
// soc_top.v

module soc_top (
    input  wire clk,
    input  wire rst_n,
    // ... ports ...
);

`ifdef SIMULATION
    //===========================================================================
    // Behavioral Memory (for simulation only)
    //===========================================================================

    reg [31:0] rom [0:8191];    // 32KB ROM
    reg [31:0] ram [0:16383];   // 64KB RAM

    initial begin
        $readmemh("firmware.hex", rom);
    end

    always @(*) begin
        rom_data = rom[rom_addr[14:2]];
    end

    always @(posedge clk) begin
        if (ram_we) ram[ram_addr[15:2]] <= ram_wdata;
        ram_rdata <= ram[ram_addr[15:2]];
    end

`else // SYNTHESIS
    //===========================================================================
    // SRAM Macros (for synthesis)
    //===========================================================================

    // Instantiate SRAM from PDK library
    // (Get exact module name from TA or PDK docs)

    sram_32kx32 u_rom (
        .clk(clk),
        .addr(rom_addr[14:2]),
        .dout(rom_data),
        .we(1'b0),
        .ce(rom_ce)
    );

    sram_64kx32 u_ram (
        .clk(clk),
        .addr(ram_addr[15:2]),
        .din(ram_wdata),
        .dout(ram_rdata),
        .we(ram_we),
        .ce(ram_ce)
    );

`endif

    // CPU core (synthesizes in both cases)
    custom_riscv_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        // ...
    );

endmodule
```

**Compile for Simulation:**
```bash
iverilog -DSIMULATION -o sim.out soc_top.v
```

**Compile for Synthesis:**
```tcl
# In Genus
set_attribute hdl_define SYNTHESIS
read_hdl soc_top.v
```

### 6.4 Memory Compiler Usage (at School)

**Step 1: Check Available Macros**

```bash
# List available SRAM macros
ls $PDK_ROOT/sram/
# Might show:
#   sram_16kx32.v
#   sram_32kx32.v
#   sram_64kx32.v
#   sram_128kx32.v
```

**Step 2: Read Documentation**

```bash
cat $PDK_ROOT/sram/README.txt
# Shows port list, timing, area for each macro
```

**Step 3: Instantiate in Your Design**

```verilog
// Use appropriate size
sram_32kx32 u_rom (
    .Q(rom_data),      // Output data
    .CLK(clk),
    .CEN(~rom_ce),     // Chip enable (active low)
    .WEN(1'b1),        // Write enable (active low, tie high for ROM)
    .A(rom_addr[14:2]),
    .D(32'h0)          // Input data (unused for ROM)
);
```

**Step 4: Include in Synthesis**

```tcl
# In Genus script
read_hdl [list \
    ${PDK_ROOT}/sram/sram_32kx32.v \
    ${RTL_DIR}/soc_top.v \
]
```

---

## 7. Clock and Reset Strategy

### 7.1 Single Clock Domain (Recommended for Homework)

**Keep It Simple:**

```verilog
module soc_top (
    input  wire clk,       // Single 50 MHz clock
    input  wire rst_n,     // Active-low async reset
    // ... other ports ...
);

    // All modules use same clock and reset
    custom_riscv_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        // ...
    );

    pwm_generator u_pwm (
        .clk(clk),
        .rst_n(rst_n),
        // ...
    );

    // All peripherals on same clock
    // No clock domain crossing issues!

endmodule
```

**Why Single Clock?**
- ✅ Simpler timing analysis
- ✅ No CDC (Clock Domain Crossing) issues
- ✅ Easier P&R
- ✅ Sufficient for homework
- ✅ Matches most real embedded systems

### 7.2 Reset Strategy

**Synchronous vs Asynchronous Reset:**

**Option A: Asynchronous Reset (Recommended)**

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset state
        state <= IDLE;
        counter <= 0;
    end else begin
        // Normal operation
        state <= next_state;
        counter <= counter + 1;
    end
end
```

**Pros:**
- ✅ Works immediately (no clock needed)
- ✅ Standard in industry
- ✅ Required for startup

**Cons:**
- ⚠️ Reset release must be synchronized
- ⚠️ Can cause metastability

**Option B: Synchronous Reset**

```verilog
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset state
    end else begin
        // Normal operation
    end
end
```

**Pros:**
- ✅ No metastability
- ✅ Simpler timing analysis

**Cons:**
- ❌ Requires clock to reset
- ❌ Uses more logic (reset mux in every FF)

**Recommendation: Use Asynchronous Reset with Synchronizer**

```verilog
module reset_sync (
    input  wire clk,
    input  wire rst_n_in,    // Async reset input
    output reg  rst_n_out    // Synchronized reset output
);
    reg rst_n_sync1;

    always @(posedge clk or negedge rst_n_in) begin
        if (!rst_n_in) begin
            rst_n_sync1 <= 1'b0;
            rst_n_out   <= 1'b0;
        end else begin
            rst_n_sync1 <= 1'b1;
            rst_n_out   <= rst_n_sync1;
        end
    end
endmodule

// Use in top-level
module soc_top (
    input  wire clk,
    input  wire rst_n_async,  // From external pin
    // ...
);
    wire rst_n_sync;

    reset_sync u_reset_sync (
        .clk(clk),
        .rst_n_in(rst_n_async),
        .rst_n_out(rst_n_sync)
    );

    // Use synchronized reset everywhere
    custom_riscv_core u_core (
        .clk(clk),
        .rst_n(rst_n_sync),
        // ...
    );
endmodule
```

### 7.3 Clock Constraints

**SDC (Synopsys Design Constraints):**

```tcl
# Create master clock
create_clock -name clk -period 20.0 [get_ports clk]

# Clock properties
set_clock_uncertainty 0.5 [get_clocks clk]  ;# Jitter + skew
set_clock_transition 0.3 [get_clocks clk]   ;# Rise/fall time
set_clock_latency 2.0 [get_clocks clk]      ;# Clock tree delay

# Don't optimize clock network (will be done in CTS)
set_dont_touch_network [get_clocks clk]

# Reset is asynchronous (don't analyze timing)
set_false_path -from [get_ports rst_n]
```

---

## 8. Constraint Development

### 8.1 Essential Constraints

**File: `constraints/timing.sdc`**

```tcl
#===============================================================================
# Timing Constraints for RISC-V CPU Core
#===============================================================================

# Units
set_units -time ns -capacitance pF -resistance kOhm

#===============================================================================
# Clock Definition
#===============================================================================

# Main system clock
create_clock -name clk -period 20.0 -waveform {0 10.0} [get_ports clk]

# Clock characteristics
set_clock_uncertainty -setup 0.5 [get_clocks clk]  ;# Setup uncertainty
set_clock_uncertainty -hold 0.2 [get_clocks clk]   ;# Hold uncertainty
set_clock_transition 0.3 [get_clocks clk]          ;# Rise/fall time
set_clock_latency -source 2.0 [get_clocks clk]     ;# Source latency

#===============================================================================
# Input Constraints
#===============================================================================

# All inputs except clock and reset
set input_ports [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]

# Input delay (signals arrive 2ns after clock edge)
set_input_delay -clock clk -max 2.0 $input_ports
set_input_delay -clock clk -min 0.5 $input_ports

# Input transition (external driver strength)
set_input_transition -max 0.5 $input_ports
set_input_transition -min 0.1 $input_ports

# Driving cell (assume external buffer drives inputs)
set_driving_cell -lib_cell BUFX2 -library typical $input_ports

#===============================================================================
# Output Constraints
#===============================================================================

# All outputs
set output_ports [all_outputs]

# Output delay (must be stable 2ns before next clock edge)
set_output_delay -clock clk -max 2.0 $output_ports
set_output_delay -clock clk -min 0.5 $output_ports

# Output load (external wire + input cap)
set_load -pin_load 0.01 $output_ports

#===============================================================================
# False Paths (Don't Check Timing)
#===============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

# Test mode signals (if any)
# set_false_path -from [get_ports test_mode]

#===============================================================================
# Multicycle Paths (If Needed)
#===============================================================================

# Example: Memory operations take 2 cycles
# set_multicycle_path -setup 2 -from [get_pins u_core/mem_addr*] -to [get_pins u_ram/*]
# set_multicycle_path -hold 1 -from [get_pins u_core/mem_addr*] -to [get_pins u_ram/*]

#===============================================================================
# Case Analysis (Constant Signals)
#===============================================================================

# If you have mode pins tied to constants
# set_case_analysis 0 [get_ports test_mode]

#===============================================================================
# Environment
#===============================================================================

# Operating conditions
set_operating_conditions typical

# Wire load model (if not using physical design)
# set_wire_load_model -name typical

#===============================================================================
# Optimization Goals
#===============================================================================

# Area constraint (max die area in µm²)
# set_max_area 50000

# Power constraint (max power in mW)
# set_max_dynamic_power 50

# Timing optimization
set_max_transition 1.0 [current_design]
set_max_capacitance 0.5 [all_outputs]

puts "Constraints loaded successfully"
```

### 8.2 Design Rule Constraints

**File: `constraints/design_rules.sdc`**

```tcl
#===============================================================================
# Design Rule Constraints
#===============================================================================

# Maximum transition time (prevents slow signals)
set_max_transition 1.0 [all_inputs]
set_max_transition 1.0 [all_outputs]

# Maximum fanout (one driver → many loads)
set_max_fanout 32 [all_inputs]
set_max_fanout 16 [current_design]

# Maximum capacitance
set_max_capacitance 0.5 [all_outputs]

# Load capacitance on clock (clock tree will handle)
set_load -pin_load 0.001 [get_ports clk]
```

### 8.3 Constraint Verification

**Check constraints before synthesis:**

```bash
# At home (not full check, but catches syntax errors)
grep "create_clock" constraints/timing.sdc
grep "set_input_delay" constraints/timing.sdc

# At school (in Genus)
genus> read_sdc constraints/timing.sdc
genus> report_clocks
genus> report_case_analysis
genus> check_timing
# Should show no errors
```

---

## 9. Synthesis Optimization

### 9.1 Optimization Goals

**Trade-off Triangle:**

```
        TIMING (Speed)
            /\
           /  \
          /    \
         /      \
        /        \
       /   BEST  \
      /   DESIGN  \
     /      ?      \
    /________________\
AREA              POWER
(Size)          (Energy)
```

**You can optimize for 2 out of 3:**
- Fast + Small → High power
- Fast + Low power → Large area
- Small + Low power → Slow

**For Homework:** Optimize for **Area first**, then **Timing**.
- Goal: Smallest die that meets 50 MHz
- Power is secondary (not graded)

### 9.2 Synthesis Strategies

**Strategy 1: Default (Balanced)**

```tcl
syn_generic
syn_map
syn_opt
```

Result: Balanced design, usually works

**Strategy 2: Area-Focused**

```tcl
set_attribute syn_generic_effort low
set_attribute syn_map_effort low
set_attribute syn_opt_effort medium

# Compile with area priority
syn_generic -effort low
syn_map -effort low
syn_opt -area
```

Result: Smaller, might be slower

**Strategy 3: Timing-Focused**

```tcl
set_attribute syn_generic_effort high
set_attribute syn_map_effort high
set_attribute syn_opt_effort high

# Compile with timing priority
syn_generic -effort high
syn_map -effort high
syn_opt -timing
```

Result: Faster, might be larger

**Strategy 4: Iterative (Best Results)**

```tcl
# Pass 1: Quick compile
syn_generic -effort medium
syn_map -effort medium
report_timing

# Pass 2: Fix timing violations
syn_opt -incremental
report_timing

# Pass 3: Reduce area (if timing OK)
syn_opt -area -incremental
report_timing

# Pass 4: Final cleanup
syn_opt -incremental
```

Result: Best quality, takes longer

### 9.3 Fixing Common Issues

**Issue 1: Timing Violation (Negative Slack)**

```
report_timing shows:
  Slack (VIOLATED) : -1.234ns
```

**Solutions:**

```tcl
# Option A: Lower clock frequency
set CLK_PERIOD 25.0  ;# Was 20.0 → now 40 MHz

# Option B: Increase optimization effort
syn_opt -effort high
syn_opt -incremental

# Option C: Allow longer paths
set_multicycle_path -setup 2 -from [get_pins ...] -to [get_pins ...]

# Option D: Identify slow path and fix in RTL
report_timing -nworst 1
# Look at path, optimize critical module
```

**Issue 2: Excessive Area**

```
report_area shows:
  Total area: 150000 µm² (too large for 5mm² die)
```

**Solutions:**

```tcl
# Option A: Reduce optimization effort
syn_opt -area

# Option B: Share resources in RTL
# (e.g., use one multiplier instead of two)

# Option C: Use smaller standard cells
set_attribute library [list typical_low_area.lib]

# Option D: Remove unused features
# Check RTL for dead code
```

**Issue 3: High Fanout Warnings**

```
Warning: Net 'rst_n' has fanout of 1234 (exceeds 512)
```

**Solutions:**

```tcl
# Insert buffers on high-fanout nets
set_attribute buffer_high_fanout true

# Or manually insert buffer tree
insert_buffer [get_nets rst_n] -buffer_cell BUFX8
```

### 9.4 Technology-Specific Optimization

**Use Fast vs Slow Cell Libraries:**

```tcl
# For synthesis, use typical library
set_attribute library typical.lib

# For timing analysis, use worst-case
read_libs slow.lib  ;# Slow process, high temp
report_timing

# For hold analysis, use best-case
read_libs fast.lib  ;# Fast process, low temp
report_timing -delay min

# Multi-corner analysis (advanced)
set_attribute library [list typical.lib slow.lib fast.lib]
```

---

## 10. Place and Route Strategy

### 10.1 Innovus Flow Overview

**After successful synthesis, move to physical design:**

```bash
# Start Innovus (Cadence P&R tool)
innovus

# Or batch mode
innovus -batch -files scripts/place_route.tcl
```

### 10.2 Complete P&R Script

**File: `scripts/place_route.tcl`**

```tcl
#===============================================================================
# Innovus Place & Route Script
#===============================================================================

set DESIGN_NAME "custom_riscv_core"
set PDK_ROOT "/tools/pdk/180nm"

puts "Starting P&R for $DESIGN_NAME"

#===============================================================================
# 1. Initialize Design
#===============================================================================

# Read LEF files (layer definitions, standard cells)
read_lef ${PDK_ROOT}/lef/tech.lef
read_lef ${PDK_ROOT}/lef/stdcells.lef

# Read gate-level netlist from synthesis
read_netlist ../outputs/${DESIGN_NAME}_netlist.v

# Read constraints
read_sdc ../outputs/${DESIGN_NAME}.sdc

# Initialize design
init_design

#===============================================================================
# 2. Floorplanning
#===============================================================================

puts "\n[Floorplan] Setting up die and core area..."

# Define die size (aspect ratio 1:1, 70% utilization)
floorPlan -site core -r 1.0 0.7 10 10 10 10

# Add power rings (VDD/VSS)
addRing -nets {VDD VSS} \
    -type core_rings \
    -layer {top M5 bottom M5 left M4 right M4} \
    -width 2.0 -spacing 1.0 -offset 2.0

# Add power stripes
addStripe -nets {VDD VSS} \
    -layer M4 -direction vertical \
    -width 1.0 -spacing 20.0

puts "Floorplan complete ✓"

#===============================================================================
# 3. Placement
#===============================================================================

puts "\n[Place] Placing standard cells..."

# Place standard cells
place_design

# Optimize placement
place_opt_design

puts "Placement complete ✓"

#===============================================================================
# 4. Clock Tree Synthesis
#===============================================================================

puts "\n[CTS] Building clock tree..."

# Create clock tree
create_ccopt_clock_tree_spec -file clock_spec.tcl
source clock_spec.tcl
ccopt_design

puts "Clock tree complete ✓"

#===============================================================================
# 5. Routing
#===============================================================================

puts "\n[Route] Routing nets..."

# Nano route (detailed routing)
route_design

puts "Routing complete ✓"

#===============================================================================
# 6. Optimization
#===============================================================================

puts "\n[Opt] Optimizing design..."

# Post-route optimization
opt_design -post_route

puts "Optimization complete ✓"

#===============================================================================
# 7. Fill (Metal Fill for Manufacturing)
#===============================================================================

puts "\n[Fill] Adding metal fill..."

# Add filler cells (standard cell rows)
addFiller -cell {FILL1 FILL2 FILL4 FILL8} -prefix FILLER

# Add metal fill (for DRC)
addMetalFill -layer {M1 M2 M3 M4 M5}

puts "Fill complete ✓"

#===============================================================================
# 8. Verification
#===============================================================================

puts "\n[Verify] Checking design..."

# Verify connectivity
verify_connectivity

# Verify geometry
verify_geometry

# DRC check
verify_drc

puts "Verification complete ✓"

#===============================================================================
# 9. Generate Reports
#===============================================================================

puts "\n[Report] Generating reports..."

file mkdir ../reports/pnr

report_timing > ../reports/pnr/timing.rpt
report_area > ../reports/pnr/area.rpt
report_power > ../reports/pnr/power.rpt
report_congestion > ../reports/pnr/congestion.rpt

puts "Reports generated ✓"

#===============================================================================
# 10. Write Outputs
#===============================================================================

puts "\n[Write] Writing output files..."

# Write GDSII (final layout)
streamOut ../outputs/${DESIGN_NAME}.gds \
    -mapFile ${PDK_ROOT}/streamout.map \
    -units 1000

# Write DEF (design exchange format)
defOut ../outputs/${DESIGN_NAME}.def

# Write SDF (timing for simulation)
write_sdf ../outputs/${DESIGN_NAME}_pnr.sdf

# Write netlist (with physical info)
saveNetlist ../outputs/${DESIGN_NAME}_pnr.v

puts "Outputs written ✓"

#===============================================================================
# Summary
#===============================================================================

puts "\n========================================"
puts "Place & Route Complete!"
puts "========================================"
puts "GDSII:  outputs/${DESIGN_NAME}.gds"
puts "SDF:    outputs/${DESIGN_NAME}_pnr.sdf"
puts "Netlist: outputs/${DESIGN_NAME}_pnr.v"
puts "\nReview reports in reports/pnr/ directory"

exit
```

**Run P&R:**

```bash
cd ~/riscv/scripts
innovus -batch -files place_route.tcl -log pnr.log

# Monitor (takes 30 minutes to 2 hours)
tail -f pnr.log
```

### 10.3 P&R Troubleshooting

**Common P&R Issues:**

**Issue: "Cannot fit design in floorplan"**

```tcl
# Solution: Increase die size or reduce utilization
floorPlan -site core -r 1.0 0.6 10 10 10 10
#                            ^^^
#                            Lower utilization (was 0.7)
```

**Issue: "Congestion in routing"**

```tcl
# Solution: Add more routing layers or reduce utilization
# Check congestion map
report_congestion
# Hot spots shown in red

# Add more space
floorPlan -site core -r 1.0 0.5 10 10 10 10
```

**Issue: "Setup timing violation after routing"**

```tcl
# Solution: Tighter optimization
opt_design -post_route -setup
opt_design -post_route -hold

# If still fails, relax clock
set_clock_uncertainty 1.0 [get_clocks clk]  ;# Was 0.5
```

---

## 11. Verification Strategy

### 11.1 Multi-Level Verification

```
Level 1: RTL Simulation (Home) ─────────────────────┐
  • Icarus Verilog                                   │
  • Functional correctness                           │
  • Fast iteration                                   │
                                                     │
Level 2: Lint Check (Home) ────────────────────────┤
  • Verilator                                        │
  • Catch common errors                              │
                                                     │
Level 3: Synthesis Check (School) ─────────────────┤
  • Genus                                            │
  • Gate-level netlist generated                     │
                                                     │
Level 4: Gate-Level Simulation (School) ───────────┤
  • Verify netlist matches RTL                       │
  • Check timing with SDF                            │
                                                     │
Level 5: Post-P&R Simulation (School) ─────────────┤
  • Final verification                               │
  • Real delays from layout                          │
                                                     │
Level 6: Sign-Off Checks (School) ─────────────────┘
  • DRC, LVS, STA
  • Ready for tape-out
```

### 11.2 Gate-Level Simulation

**After synthesis, simulate netlist:**

```bash
# At school (or home if you have netlist)

# Compile gate-level netlist + testbench
iverilog -o sim_gates.out \
    /tools/pdk/180nm/verilog/cells.v \    # Standard cell models
    outputs/custom_riscv_core_netlist.v \ # Your netlist
    sim/tb_core.v                         # Testbench

# Run simulation
vvp sim_gates.out

# Check: Should match RTL simulation results!
```

**With Timing (SDF Back-Annotation):**

```verilog
// In testbench
initial begin
    $sdf_annotate("../outputs/custom_riscv_core.sdf", dut);
end
```

```bash
# Compile with SDF support
iverilog -g2005-sv -o sim_timing.out \
    /tools/pdk/180nm/verilog/cells.v \
    outputs/custom_riscv_core_netlist.v \
    sim/tb_core.v

# Run (will include real gate delays)
vvp sim_timing.out
```

**What to Check:**
- ✅ Same functional behavior as RTL
- ✅ No X (unknown) values
- ✅ Timing violations (if any) are reported
- ✅ Setup/hold checks pass

### 11.3 Formal Verification (Advanced, Optional)

**Equivalence checking (RTL vs Netlist):**

```tcl
# Cadence Conformal LEC (if available)

# Read RTL
read_hdl -rtl rtl/core/custom_riscv_core.v

# Read netlist
read_hdl -impl outputs/custom_riscv_core_netlist.v

# Compare
compare

# Report
report_verification
# Should show: All points compared: EQUIVALENT ✓
```

---

## 12. Common Issues and Solutions

### 12.1 Synthesis Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Latch Inferred** | Warning: "Latch inferred" | Fix incomplete if-else or case statements |
| **Multiple Drivers** | Error: "Net has multiple drivers" | Check for conflicting assignments |
| **Cannot Resolve** | Error: "Cannot resolve reference" | Add missing module to file list |
| **Combinational Loop** | Error: "Combinational loop detected" | Fix feedback path in logic |
| **Unsynthesizable Construct** | Error: "$readmemh is not synthesizable" | Use `ifdef SIMULATION |

### 12.2 Timing Issues

| Slack Type | Meaning | Fix |
|------------|---------|-----|
| **Positive Slack** | +2.3ns | ✅ GOOD (timing met with margin) |
| **Zero Slack** | 0.0ns | ⚠️ Marginal (barely meets timing) |
| **Negative Slack** | -1.5ns | ❌ VIOLATED (fails timing) |

**Fixing Negative Slack:**

1. **Increase clock period** (easiest)
2. **Optimize critical path** (better)
3. **Pipeline design** (best, but changes RTL)

### 12.3 Area Issues

**If design is too large:**

1. Remove unused peripherals
2. Reduce memory sizes
3. Share hardware resources
4. Use smaller bit widths where possible

### 12.4 Power Issues (if checked)

**If power is too high:**

1. Clock gating (stop clock to unused blocks)
2. Lower operating frequency
3. Reduce toggle rate on buses

---

## 13. Homework Submission Checklist

### 13.1 Required Files

**Directory Structure for Submission:**

```
<YourName>_RISCV_CPU/
├── rtl/                    # RTL source code
│   ├── regfile.v
│   ├── alu.v
│   ├── decoder.v
│   ├── control_fsm.v
│   └── custom_riscv_core.v
├── sim/                    # Testbenches
│   ├── tb_regfile.v
│   ├── tb_alu.v
│   ├── tb_core.v
│   └── test_program.hex
├── scripts/                # Synthesis scripts
│   ├── synthesize_cpu.tcl
│   └── place_route.tcl
├── constraints/            # Timing constraints
│   └── timing.sdc
├── outputs/                # Generated files
│   ├── custom_riscv_core_netlist.v
│   ├── custom_riscv_core.sdc
│   ├── custom_riscv_core.sdf
│   └── custom_riscv_core.gds ★ (GDSII file)
├── reports/                # Synthesis/P&R reports
│   ├── timing.rpt
│   ├── area.rpt
│   ├── power.rpt
│   └── pnr/
│       ├── timing.rpt
│       ├── area.rpt
│       └── congestion.rpt
├── waveforms/              # Simulation results
│   ├── tb_alu.vcd
│   ├── tb_core.vcd
│   └── screenshots/
│       ├── alu_test.png
│       └── core_test.png
├── report.pdf ★            # Design report (10-20 pages)
└── README.txt              # Instructions to run
```

### 13.2 Report Structure

**Design Report (report.pdf) Should Include:**

**1. Introduction (1 page)**
- Project overview
- Design objectives
- Specifications summary

**2. Architecture (2-3 pages)**
- Block diagram
- Module hierarchy
- Datapath and control unit
- ISA implementation

**3. RTL Design (3-4 pages)**
- Register file design
- ALU design
- Decoder design
- Control FSM
- Code snippets with explanations

**4. Verification (2-3 pages)**
- Testbench methodology
- Test programs
- Waveforms (screenshots)
- Coverage analysis

**5. Synthesis Results (2-3 pages)**
- Timing report analysis
- Area breakdown
- Power estimation
- Gate count vs module

**6. Physical Design (2-3 pages)**
- Floorplan screenshot
- Placement screenshot
- Routing screenshot
- Final layout (GDSII view)
- Die photo rendering

**7. Performance Analysis (1-2 pages)**
- Clock frequency achieved
- CPI (Cycles Per Instruction)
- Area efficiency
- Comparison with requirements

**8. Challenges and Solutions (1 page)**
- Problems encountered
- How you solved them
- Lessons learned

**9. Conclusion (1 page)**
- Summary of achievements
- Future improvements

**10. Appendices**
- Complete code listings
- Full simulation logs
- Full synthesis reports

### 13.3 Grading Rubric (Typical)

| Category | Points | Criteria |
|----------|--------|----------|
| **RTL Design** | 30% | Correctness, modularity, style |
| **Verification** | 20% | Testbenches, coverage, waveforms |
| **Synthesis** | 25% | Timing met, area reasonable |
| **Physical Design** | 15% | GDSII generated, DRC clean |
| **Documentation** | 10% | Report quality, clarity |

**Bonus Points (Optional):**
- M extension implemented: +5%
- Full SoC with peripherals: +10%
- Custom ISA extension (Zpec): +5%
- Publication-quality presentation: +5%

---

## 14. Complete Genus Script Examples

### 14.1 Minimal Working Example

**File: `scripts/synth_minimal.tcl`**

```tcl
# Minimal synthesis script (10 lines)

set_attribute library typical.lib
read_hdl rtl/core/custom_riscv_core.v
elaborate custom_riscv_core
read_sdc constraints/timing.sdc
syn_generic
syn_map
syn_opt
write_hdl > outputs/netlist.v
report_qor
exit
```

### 14.2 Production-Quality Script

**(See Section 5.3 for complete production script)**

---

## 15. Timeline and Effort Estimation

### 15.1 Recommended Schedule

**Week 1-2: RTL Implementation (At Home)**
- Implement regfile.v: 2-4 hours
- Implement alu.v: 4-6 hours
- Implement decoder.v: 6-8 hours
- Debug and integrate: 4-6 hours
- **Total: 16-24 hours**

**Week 3: Verification (At Home)**
- Write testbenches: 8-12 hours
- Run simulations: 2-4 hours
- Debug failures: 4-8 hours
- **Total: 14-24 hours**

**Week 4: Synthesis (At School)**
- Setup environment: 1 hour
- First synthesis run: 30 min
- Debug issues: 2-4 hours
- Final synthesis: 30 min
- **Total: 4-6 hours**

**Week 5: P&R (At School)**
- Floorplan: 1 hour
- Place & Route: 2-3 hours
- Debug issues: 2-4 hours
- Final P&R: 1 hour
- **Total: 6-9 hours**

**Week 6: Report Writing (At Home)**
- Draft report: 8-12 hours
- Screenshots and figures: 2-4 hours
- Review and polish: 2-4 hours
- **Total: 12-20 hours**

**Grand Total: 52-83 hours (1.5-2 months part-time)**

### 15.2 Fast-Track Option (CPU Only)

If you only synthesize CPU core (no SoC):
- Week 4 synthesis: 2 hours
- Week 5 P&R: 3 hours
- **Total school time: 5 hours (one long session)**

### 15.3 Ambitious Track (Full SoC)

If you synthesize complete SoC with peripherals:
- Week 4 synthesis: 4-6 hours
- Week 5 P&R: 6-10 hours
- **Total school time: 10-16 hours (two long sessions)**

---

## Conclusion

This guide provides everything you need to take your RISC-V SoC from RTL to GDSII. Key takeaways:

1. **✅ Develop at home** using open-source tools (fast iteration)
2. **✅ Test thoroughly** before going to school (save time)
3. **✅ Start with CPU-only** synthesis (safe backup)
4. **✅ Attempt full SoC** if time permits (impressive results)
5. **✅ Document everything** (screenshots, reports, waveforms)

**Good luck with your homework!** 🚀

---

**For Questions:**
- Review specific sections as needed
- Check tool documentation (Genus User Guide, Innovus Reference)
- Ask TA/Professor for PDK-specific details
- Refer to HOMEWORK_GUIDE.md for implementation details

**Next Steps:**
1. Implement your three core modules (regfile, alu, decoder)
2. Verify with testbenches
3. Follow Section 5.3 for synthesis
4. Follow Section 10.2 for P&R
5. Write report per Section 13.2

**End of Synthesis Strategy Guide**

---
## 16. Action Plan: From Core Compliance to GDSII

This plan operationalizes the strategies outlined in this document. Now that your core is nearly compliance-complete, follow these phases to progress to a final GDSII layout.

### Phase 1: Core Finalization & RTL Freeze (1-2 Days)

**Goal:** Solidify the RISC-V core, document its state, and ensure it's ready for SoC integration.

-   **[ ] Action 1.1: Document Compliance Status**
    -   Create a new document in `docs/` named `COMPLIANCE_REPORT.md`.
    -   In this file, list the 98% of tests that pass.
    -   Clearly document the specific tests that fail. For each failure, provide a brief explanation of why it's considered an acceptable edge case for this project's scope.
    -   **Reference:** Section 11 (Verification Strategy)

-   **[ ] Action 1.2: Core RTL Code Review**
    -   Perform a final review of your core's RTL (`regfile.v`, `alu.v`, `decoder.v`, `control_fsm.v`).
    -   Check for synthesis-friendliness: synchronous logic, proper reset handling (asynchronous with synchronizer), no latches.
    -   Run a final lint check using Verilator as described in the guide.
    -   **Reference:** Section 4.3 (Verification Checklist), Section 7.2 (Reset Strategy)

-   **[ ] Action 1.3: Freeze the Core**
    -   Commit all changes with a clear message like `feat(core): Finalize RTL for v1.0, ready for SoC integration`.
    -   Create a git tag: `git tag -a v1.0-core-freeze -m "Core RTL is frozen. Next step: SoC integration."`
    -   From this point, avoid making changes to the core logic unless a critical bug is found during SoC verification.

### Phase 2: SoC Integration & Verification (3-5 Days)

**Goal:** Integrate the core into a full System-on-Chip with peripherals and verify the complete system in simulation.

-   **[ ] Action 2.1: Define SoC Architecture**
    -   Based on **Section 2.1 (Complete SoC Structure)**, decide on the final set of peripherals (e.g., UART, GPIO, Timer, PWM).
    -   Update the top-level file `rtl/soc/soc_top.v` to instantiate the core and all required peripherals.
    -   Connect all components using the provided Wishbone interconnect.
    -   Finalize the memory map in `firmware/memory_map.h`.

-   **[ ] Action 2.2: Implement Memory Strategy**
    -   Follow **Section 6.3 (Practical Approach for Homework)**.
    -   Use `SIMULATION` and `SYNTHESIS` conditional compilation flags in `soc_top.v` to switch between behavioral memory models (for home simulation) and placeholders for SRAM macros (for synthesis).

-   **[ ] Action 2.3: Full SoC Verification**
    -   Develop a comprehensive SoC-level test program in assembly or C (similar to **Section 4.4** but more extensive). This test should:
        -   Initialize all peripherals.
        -   Write to the UART and check for expected output.
        -   Toggle GPIO pins and read them back.
        -   Use the timer to create a delay.
        -   Run a simple algorithm (e.g., factorial) on the core to ensure it still works.
    -   Simulate the full SoC with this program at home using Icarus Verilog. Debug any integration issues.
    -   **Reference:** Section 4.2 (Daily Development Cycle), Section 11 (Verification Strategy)

### Phase 3: Synthesis (RTL-to-Netlist) at School (1 Day)

**Goal:** Synthesize your design into a gate-level netlist using Cadence Genus.

-   **[ ] Action 3.1: Prepare for School Visit**
    -   Ensure your project is clean and all verification passes.
    -   Push your final code to a remote repository or copy it to a USB drive.
    -   Decide whether you will attempt **Option A (CPU-Only)** first as a backup, or go directly for **Option C (Full SoC)**, as per **Section 3.3**. It is highly recommended to do the safe CPU-only version first.

-   **[ ] Action 3.2: Execute Synthesis**
    -   At the school lab, set up the environment (**Section 5.1**) and technology library (**Section 5.2**).
    -   Use the provided TCL scripts (`scripts/synthesize_cpu.tcl` or `scripts/synthesize_soc.tcl`) as a template. You will need to confirm the exact library and LEF file paths from your TA.
    -   Run Genus and generate the netlist and reports.
    -   **Reference:** Section 5.3 (Complete Genus Synthesis Flow)

-   **[ ] Action 3.3: Analyze and Iterate**
    -   Carefully review the timing, area, and power reports.
    -   If you have timing violations (negative slack), apply the techniques in **Section 9.3 (Fixing Common Issues)**. This may involve adjusting the clock period in your constraints file or, in a worst-case scenario, modifying the RTL.
    -   Your goal is to achieve positive timing slack.

### Phase 4: Physical Design (Netlist-to-GDSII) at School (1 Day)

**Goal:** Create the final physical layout of your chip using Cadence Innovus.

-   **[ ] Action 4.1: Execute Place & Route**
    -   Once synthesis is successful and timing is met, proceed to P&R.
    -   Use the `scripts/place_route.tcl` script as a template. Again, confirm paths and settings with your TA.
    -   Run the script in Innovus. This process will perform floorplanning, placement, clock tree synthesis, and routing.
    -   **Reference:** Section 10.2 (Complete P&R Script)

-   **[ ] Action 4.2: Final Sign-off Verification**
    -   After P&R completes, Innovus will run final verification checks (DRC, LVS).
    -   Review the post-P&R timing report to ensure timing is still met after accounting for real wire delays.
    -   If there are issues, use the troubleshooting tips in **Section 10.3**.

-   **[ ] Action 4.3: Generate GDSII**
    -   The final step of the P&R script is `streamOut`, which generates the `your_design.gds` file.
    -   Backup this file securely. This is the primary deliverable for your project.

