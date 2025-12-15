# RISC-V Core - Race Condition Bug Fix

**Date:** 2025-12-10
**Status:** FIXED - 4 tests recovered
**Bug Type:** Testbench race condition
**Severity:** Critical - caused 14% test failure rate

---

## Executive Summary

A race condition in the testbench was causing memory to be loaded AFTER the CPU started fetching instructions. This resulted in the CPU fetching stale NOP instructions (0x00000013) instead of the intended test program, causing:

- Branch/jump tests to fail (instructions executing when they should be skipped)
- First instruction always writing to x0 instead of intended register
- PC appearing to skip instructions

**Fix:** Reorganized all test sequences to load memory BEFORE releasing reset.

**Impact:** Improved test pass rate from 71% (20/28) to 85.7% (24/28)

---

## Bug Discovery Process

### 1. Initial Symptoms

Multiple tests were failing with consistent pattern:
- Test 12-13: BEQ should skip 2 instructions, but they execute (x3=1, x4=2 instead of 0)
- Test 16-17: JAL should skip 2 instructions, but they execute
- Simple isolated branch test PASSED, but same code in full test FAILED

### 2. Hypothesis Development

**Initial theories:**
- ❌ Branch comparison logic bug
- ❌ PC calculation bug
- ❌ EBREAK trap causing re-execution
- ✅ **Testbench initialization timing issue**

### 3. Root Cause Investigation

Created detailed execution trace ([tb_full_trace.v:71](sim/testbench/tb_full_trace.v#L71)) showing:

```
[FETCH   ] PC=0x00000000, instr=0x00000013  ← WRONG! Should be 0x00a00093
[DECODE  ] opcode=0x13, rd=x0               ← Decoding NOP instead of ADDI x1
```

**Critical finding:** First instruction fetch returned NOP (0x00000013) instead of ADDI x1, x0, 10 (0x00a00093).

### 4. Timing Analysis

Compared working test ([tb_simple_branch.v:77-97](sim/testbench/tb_simple_branch.v#L77-L97)) with failing test:

**Working pattern:**
```verilog
rst_n = 0;               // Line 77 - Hold reset
imem[0] = 32'h00a00093;  // Line 83 - Load memory WHILE in reset
imem[1] = 32'h00a00113;  // Line 85
// ... more loads ...
#20 rst_n = 1;           // Line 97 - THEN release reset
```

**Failing pattern:**
```verilog
rst_n = 0; #20; rst_n = 1; #20;  // Release reset FIRST
imem[0] = 32'h00a00093;          // Load memory AFTER - TOO LATE!
imem[1] = 32'h00a00113;
```

**Root cause:** CPU starts fetching on first clock edge after reset release. If memory loads happen at the same simulation time but after the clock edge, the CPU fetches stale data.

---

## The Fix

### Changes Made

Modified all 7 test sequences in [tb_full_system.v](sim/testbench/tb_full_system.v):

**Tests affected:**
- Test 2: Memory Operations ([line 237](sim/testbench/tb_full_system.v#L237))
- Test 3: Branch Instructions ([line 262](sim/testbench/tb_full_system.v#L262))
- Test 4: Jump Instructions ([line 293](sim/testbench/tb_full_system.v#L293))
- Test 5: Shift Operations ([line 319](sim/testbench/tb_full_system.v#L319))
- Test 6: CSR Operations ([line 348](sim/testbench/tb_full_system.v#L348))
- Test 7: Exception Handling ([line 371](sim/testbench/tb_full_system.v#L371))
- Test 8: Interrupt Handling ([line 400](sim/testbench/tb_full_system.v#L400))

### Code Change Pattern

**BEFORE (buggy):**
```verilog
$display("\n=== TEST SUITE X ===\n");

rst_n = 0; #20; rst_n = 1; #20;  // ← BUG: Reset released too early

imem[0] = 32'h...;  // ← Memory loaded after CPU starts
imem[1] = 32'h...;
imem[2] = 32'h...;

wait_cycles(100);
```

**AFTER (fixed):**
```verilog
$display("\n=== TEST SUITE X ===\n");

rst_n = 0; #20;      // ← Hold reset

imem[0] = 32'h...;  // ← Load memory WHILE in reset
imem[1] = 32'h...;
imem[2] = 32'h...;

rst_n = 1; #20;      // ← THEN release reset
wait_cycles(100);
```

---

## Verification

### Execution Trace - Before Fix

```
[FETCH   ] PC=0x00000000, instr=0x00000013  ← NOP fetched
[DECODE  ] opcode=0x13, rd=x0, is_branch=0  ← Wrong instruction
[WBACK  ] rd_wen=1, rd_data=0x00000000

[FETCH   ] PC=0x00000004, instr=0x00a00113  ← Second test instruction at first PC
[DECODE  ] opcode=0x13, rd=x2               ← Off by one!

[FETCH   ] PC=0x00000008, instr=0x00208663  ← BEQ instruction
[EXECUTE ] alu_result=0xfffffff6, alu_zero=0 ← x1(0) != x2(10), branch NOT taken
[WBACK  ] next_pc will be 0x0000000c        ← Executes skipped instructions

Result: x1=0, x2=10, x3=1, x4=2, x5=3  ❌ FAIL
```

### Execution Trace - After Fix

```
[FETCH   ] PC=0x00000000, instr=0x00a00093  ← Correct ADDI x1
[DECODE  ] opcode=0x13, rd=x1               ← Correct decode
[WBACK  ] rd_wen=1, rd_data=0x0000000a

[FETCH   ] PC=0x00000004, instr=0x00a00113  ← Correct ADDI x2
[DECODE  ] opcode=0x13, rd=x2
[WBACK  ] rd_wen=1, rd_data=0x0000000a

[FETCH   ] PC=0x00000008, instr=0x00208663  ← BEQ instruction
[EXECUTE ] alu_result=0x00000000, alu_zero=1 ← x1(10) == x2(10), branch taken!
[WBACK  ] next_pc will be 0x00000014        ← Skips to branch target

[FETCH   ] PC=0x00000014, instr=0x00300293  ← Branch target (x5)

Result: x1=10, x2=10, x3=0, x4=0, x5=3  ✅ PASS
```

### Test Results Comparison

| Test | Description | Before | After | Status |
|------|-------------|--------|-------|--------|
| 0-11 | ALU, Memory, Branch setup | PASS | PASS | ✅ Already working |
| 12 | BEQ skip test (x3) | FAIL | PASS | ✅ Fixed |
| 13 | BEQ skip test (x4) | FAIL | PASS | ✅ Fixed |
| 14 | Branch target | PASS | PASS | ✅ Already working |
| 15 | JAL return address | PASS | PASS | ✅ Already working |
| 16 | JAL skip test (x2) | FAIL | PASS | ✅ Fixed |
| 17 | JAL skip test (x3) | FAIL | PASS | ✅ Fixed |
| 18-23 | Shifts | PASS | PASS | ✅ Already working |
| 24 | CSR read/write | FAIL | FAIL | ⚠️ Different issue |
| 25-26 | Exception handling | FAIL | FAIL | ⚠️ Different issue |
| 27 | Interrupt handling | FAIL | FAIL | ⚠️ Different issue |

**Summary:**
- **Fixed:** 4 tests (Tests 12, 13, 16, 17)
- **Pass rate:** 71% → 85.7%
- **Remaining:** 4 tests with different root causes

---

## Lessons Learned

### For Testbench Design

1. **Always load memory before releasing reset**
   - Prevents race conditions with CPU fetch logic
   - Ensures deterministic test behavior

2. **Memory initialization timing matters**
   - Even though assignments happen in "zero time", clock edges can arrive between them
   - Use explicit sequencing: reset → load → release

3. **Create isolated tests**
   - Simple tests helped identify that core logic was correct
   - Isolated the problem to testbench initialization

### For Debugging

1. **Compare working vs failing code**
   - `tb_simple_branch.v` (working) vs `tb_full_system.v` (failing)
   - Pattern matching revealed the initialization difference

2. **Add detailed tracing**
   - State-by-state execution traces ([tb_full_trace.v](sim/testbench/tb_full_trace.v))
   - Showed exactly what instruction was fetched at each PC

3. **Check assumptions early**
   - Initially assumed core logic bug
   - Should have verified testbench first

### For Hardware Verification

1. **Race conditions are subtle**
   - Tests can fail intermittently or based on initialization order
   - Always consider timing in testbench design

2. **Determinism is critical**
   - Hardware simulators execute in delta cycles
   - Explicit sequencing prevents non-deterministic behavior

---

## Remaining Issues

### Test 24 - CSR Read/Write (1 test)

**Symptom:**
- Write 0x1000 to mtvec
- Read back 0x1800 instead

**Investigation needed:**
- Check CSR write mask (are bits 11-12 being set?)
- Verify mtvec CSR implementation in [csr_unit.v](rtl/core/csr_unit.v)
- Check if mtvec has alignment requirements

### Tests 25-26 - Exception Handling (2 tests)

**Symptom:**
- Exception handler should set x1=1
- Instead x1=8, x2=0x00100000

**Investigation needed:**
- Verify illegal instruction detection
- Check exception trap entry state machine
- Verify mepc/mcause CSR updates
- Check if MRET properly restores state

### Test 27 - Interrupt Handling (1 test)

**Symptom:**
- Interrupt handler should set x3=5
- Instead x3=0 (handler never executes)

**Investigation needed:**
- Verify interrupt enable logic (mstatus.MIE)
- Check mie CSR masking
- Verify interrupt priority logic
- Check if interrupt request is sampled correctly

---

## Files Modified

1. **[tb_full_system.v](sim/testbench/tb_full_system.v)** - Fixed all 7 test sequences
2. **[tb_full_trace.v](sim/testbench/tb_full_trace.v)** - Created for detailed debugging (fixed compilation error)
3. **[tb_debug_branch.v](sim/testbench/tb_debug_branch.v)** - Created for EBREAK investigation
4. **[tb_trace_branch.v](sim/testbench/tb_trace_branch.v)** - Created to reproduce exact bug

---

## Compilation and Testing

### Compile Tests
```bash
cd /home/furka/5level-inverter/02-embedded/riscv/sim
iverilog -g2012 -I../rtl/core -o tb_full_system testbench/tb_full_system.v ../rtl/core/*.v
```

### Run Tests
```bash
vvp tb_full_system
```

### Expected Output
```
Test Summary:
  Passed: 24
  Failed: 4
  Total:  28

*** SOME TESTS FAILED ***
```

---

## Next Steps

1. **Debug CSR read/write** (Test 24)
   - Add CSR access traces
   - Check mtvec implementation
   - Verify CSR address decoding

2. **Debug exception handling** (Tests 25-26)
   - Add exception trace logging
   - Verify trap entry state machine
   - Check mepc/mcause updates

3. **Debug interrupt handling** (Test 27)
   - Add interrupt trace logging
   - Verify interrupt enable chain
   - Check interrupt sampling logic

4. **Run RISC-V compliance tests**
   - After fixing remaining 4 tests
   - Verify against official test suite

---

## References

- [TEST_ANALYSIS.md](docs/TEST_ANALYSIS.md) - Original test failure analysis
- [custom_riscv_core.v](rtl/core/custom_riscv_core.v) - Core implementation
- [decoder.v](rtl/core/decoder.v) - Instruction decoder
- [csr_unit.v](rtl/core/csr_unit.v) - CSR implementation
- [exception_unit.v](rtl/core/exception_unit.v) - Exception handling

---

**Document Status:** Complete
**Author:** Claude (AI Assistant)
**Verified:** Simulation passing 24/28 tests
