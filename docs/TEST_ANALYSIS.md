# Full System Test Analysis

**Date:** 2025-12-10
**Test Results:** 18/28 PASS (64%)

## Summary

The RISC-V core integration is working correctly for most basic operations. The test failures are a mix of **test bugs** and **real core issues** that need fixing.

---

## Test Failures Analysis

### ✅ Test Bugs (Tests are Wrong, Core is Correct)

#### 1. **Test 3: SUB Instruction** - TEST BUG
**Status:** FAIL (but core is correct)
**Test Code:**
```verilog
imem[3] = 32'h40208233;  // Comment says "SUB x4, x2, x1"
check_register(4, 32'd10, "SUB x4, x2, x1");
```

**Issue:**
- **Instruction encoding** `0x40208233` = `SUB x4, x1, x2` (x4 = x1 - x2 = 10 - 20 = -10)
- **Test expects** x4 = 10 (which would be x2 - x1 = 20 - 10)
- **Core returns** 0xFFFFFF6 (-10) which is **CORRECT**

**Fix:** Change instruction to `0x40110233` (SUB x4, x2, x1)

#### 2. **Tests 12-13: Branch Skip** - TEST BUG
**Status:** FAIL (but core is correct)
**Test Code:**
```verilog
imem[2] = 32'h00208463;  // BEQ x1, x2, +8 (comment says "skip next 2")
imem[3] = 32'h00100193;  // ADDI x3, x0, 1 # Should be skipped
imem[4] = 32'h00200213;  // ADDI x4, x0, 2 # Should be skipped
imem[5] = 32'h00300293;  // ADDI x5, x0, 3 # Should execute
```

**Issue:**
- BEQ at PC=0x08 with offset +8 jumps to 0x10
- This only skips imem[3] at 0x0C
- imem[4] at 0x10 **does execute** (not skipped)
- To skip BOTH and land at imem[5] (0x14), offset must be +12

**Memory Layout:**
```
0x08: BEQ x1, x2, +8  → target = 0x10
0x0C: ADDI x3 (skipped ✓)
0x10: ADDI x4 (EXECUTES - not skipped!)
0x14: ADDI x5 (target should be here)
```

**Fix:** Change offset from +8 to +12: `32'h00208663`

---

### ❌ Real Core Issues (Need Fixing)

#### 3. **Tests 15-17: JAL Return Address and Skip**
**Status:** FAIL
**Results:**
- Test 15: x1 expected 0x00000004, got 0x0000000C
- Test 16: x2 expected 0 (skipped), got 1 (executed!)
- Test 17: x3 expected 0 (skipped), got 2 (executed!)

**Issue:** JAL instruction has TWO problems:
1. Return address (PC+4) calculation is wrong
2. Instructions after JAL are executing when they should be skipped

**Root Cause:** Need to investigate JAL implementation in `custom_riscv_core.v` WRITEBACK stage

**Code Location:** `custom_riscv_core.v:406-408`

#### 4. **Test 24: CSR Read/Write**
**Status:** FAIL
**Result:** x3 expected 0x00001000, got 0x00001800

**Issue:** CSR write/read not working correctly. The value read back is different from what was written.

**Possible Causes:**
- CSR operation decode logic incorrect
- CSR unit not receiving write data correctly
- Timing issue with CSR read/write

**Code Location:**
- `custom_riscv_core.v:238-241` (CSR operation decoding)
- `csr_unit.v:199-222` (CSR write logic)

#### 5. **Tests 25-26: Exception Handling**
**Status:** FAIL
**Results:**
- Test 25: Exception handler executed - x1 expected 1, got 8
- Test 26: Instruction after exception - x2 expected 0, got 0x00100000

**Issue:** Exception handling not working. Illegal instruction trap not jumping to exception handler.

**Code Location:**
- `exception_unit.v` - Exception detection
- `custom_riscv_core.v:300-309` (Exception trap entry in EXECUTE state)

#### 6. **Test 27: Interrupt Handling**
**Status:** FAIL
**Result:** x3 expected 5, got 0

**Issue:** Interrupt not being serviced. Handler not executing.

**Possible Causes:**
- `mtvec` not set correctly
- Interrupt enable bits not set
- Interrupt request not propagating correctly

**Code Location:**
- `csr_unit.v:89-116` (Interrupt logic)
- `custom_riscv_core.v:272-280` (Interrupt trap entry in FETCH state)

---

## Core Architecture Review

### ✅ What's Working
- Basic ALU operations (ADD, AND, OR, XOR, shifts)
- Memory load/store (LW, SW)
- Immediate operations
- Decoder properly decodes all instruction types
- Exception unit detects exceptions correctly
- CSR unit registers exist and are accessible

### ❌ What Needs Fixing
1. **JAL instruction** - Return address and PC update
2. **CSR operations** - Read/write data path
3. **Exception handling** - Trap entry and handler jump
4. **Interrupt handling** - Complete flow from request to handler

---

## Recommended Next Steps

### Priority 1: Fix JAL (Critical for Control Flow)
JAL is broken in two ways - this affects all jump operations.

**Action Items:**
1. Check JAL return address calculation (should be PC+4)
2. Investigate why instructions after JAL execute (PC update timing)
3. Add `rd` write for JAL return address

### Priority 2: Fix CSR Operations
CSR read/write is partially working but data is corrupted.

**Action Items:**
1. Trace CSR write data path from decoder to CSR unit
2. Verify CSR address decoding (immediate field extraction)
3. Check CSR read data path to register file

### Priority 3: Fix Exception/Interrupt Handling
These are advanced features but critical for a complete implementation.

**Action Items:**
1. Verify `mtvec` CSR is being set by software
2. Check trap entry state machine transitions
3. Verify trap vector calculation
4. Test MRET (return from trap)

---

## Test Suite Improvements Needed

### Bugs to Fix:
1. Test 3: Fix SUB instruction encoding
2. Tests 12-13: Fix BEQ offset (+8 → +12)
3. Tests 16-17: Similar JAL offset issues (verify)

### Enhancements:
1. Add intermediate PC value checks
2. Add waveform markers for key events
3. Add CSR read-back verification after each write
4. Break down complex tests into smaller atomic tests

---

## Architecture Decisions Made

### ✅ Module Integration (Clean)
- **Decoder**: Properly outputs all system instruction decode signals
- **CSR Unit**: Handles all CSR operations and interrupt logic
- **Exception Unit**: Detects and prioritizes exceptions
- **Interrupt Controller**: ❌ REMOVED (redundant - CSR unit handles this)

### Current Data Flow
```
Decoder → Control Signals → Core State Machine
           ↓
       CSR Unit → Trap Handling
           ↓
    Exception Unit → Exception Detection
```

---

## Performance Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Tests Passing | 18/28 (64%) | 🟨 Needs Work |
| ALU Operations | 6/7 (86%)* | 🟩 Good |
| Memory Ops | 3/3 (100%) | 🟩 Perfect |
| Branches | 2/5 (40%) | 🟥 Broken |
| Shifts | 5/5 (100%) | 🟩 Perfect |
| CSR Ops | 0/1 (0%) | 🟥 Broken |
| Exceptions | 0/2 (0%) | 🟥 Not Working |
| Interrupts | 0/1 (0%) | 🟥 Not Working |

*Note: SUB "failure" is actually a test bug, so ALU is 7/7 (100%)

---

## Conclusion

The core is **partially functional** with solid ALU and memory operations. The main issues are:
1. Control flow (branches/jumps) - timing issues
2. CSR operations - data path bugs
3. Trap handling - not yet functional

With focused debugging on JAL and CSR operations, the core should reach 90%+ pass rate quickly.
