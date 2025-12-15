# RISC-V Compliance Test Setup and Results

**Date:** 2025-12-10
**Status:** Initial compliance testing setup complete
**Pass Rate:** 42.0% (21/50 tests)

---

## Executive Summary

Successfully set up official RISC-V compliance testing infrastructure for the custom RV32IM core. The test suite now automatically runs 50 official tests from the riscv-tests repository, validating ISA compliance.

**Key Achievements:**
- ✅ RISC-V compliance test suite integrated (50 tests for RV32IM)
- ✅ Automated test runner script created
- ✅ FENCE instruction support added to core
- ✅ 21/50 tests passing (42%)
- ✅ Test infrastructure ready for continuous validation

---

## Test Suite Setup

### 1. Test Repository

Cloned official RISC-V compliance tests:
```bash
cd /home/furka/5level-inverter/02-embedded/riscv
git clone https://github.com/riscv-software-src/riscv-tests.git
git submodule update --init --recursive
```

### 2. Build Configuration

Built tests for RV32 (32-bit RISC-V):
```bash
export RISCV=/opt/riscv
export PATH=/opt/riscv/bin:$PATH
./configure --prefix=$RISCV/target
make isa XLEN=32
```

This generates test binaries for:
- **rv32ui-p-*** - RV32I base integer instruction tests (user mode, physical memory)
- **rv32um-p-*** - RV32M multiply/divide extension tests

### 3. Test Infrastructure

Created automated test runner: [run_compliance_tests.py](../run_compliance_tests.py)

**Features:**
- Converts ELF test binaries to hex format
- Generates Verilog testbenches automatically
- Compiles and runs tests in simulation
- Monitors `tohost` register for pass/fail
- Reports detailed results

**Usage:**
```bash
python3 run_compliance_tests.py
```

---

## Test Results Summary

### Overall Results
| Metric | Value |
|--------|-------|
| Total Tests | 50 |
| Passed | 21 |
| Failed | 29 |
| Pass Rate | 42.0% |

### Detailed Results by Category

#### ✅ **Passing Tests (21)**
| Test | Category | Description |
|------|----------|-------------|
| rv32ui-p-simple | Basic | Simple sanity test |
| rv32ui-p-add | ALU | Integer addition |
| rv32ui-p-addi | ALU | Add immediate |
| rv32ui-p-andi | ALU | AND immediate |
| rv32ui-p-auipc | PC | Add upper immediate to PC |
| rv32ui-p-beq | Branch | Branch if equal |
| rv32ui-p-bge | Branch | Branch if greater/equal (signed) |
| rv32ui-p-blt | Branch | Branch if less than (signed) |
| rv32ui-p-bne | Branch | Branch if not equal |
| rv32ui-p-jal | Jump | Jump and link |
| rv32ui-p-jalr | Jump | Jump and link register |
| rv32ui-p-lui | Immediate | Load upper immediate |
| rv32ui-p-ori | ALU | OR immediate |
| rv32ui-p-sll | Shift | Shift left logical |
| rv32ui-p-slli | Shift | Shift left logical immediate |
| rv32ui-p-slt | Compare | Set less than (signed) |
| rv32ui-p-slti | Compare | Set less than immediate (signed) |
| rv32ui-p-sltiu | Compare | Set less than immediate (unsigned) |
| rv32ui-p-sltu | Compare | Set less than (unsigned) |
| rv32ui-p-sub | ALU | Integer subtraction |
| rv32ui-p-xori | ALU | XOR immediate |

**Analysis:** Basic ALU operations, branching, jumping, and most comparison instructions work correctly.

---

#### ❌ **Failing Tests (29)**

**Load/Store Operations (9 failures)**
| Test | Error Code | Issue |
|------|------------|-------|
| rv32ui-p-lb | 2 | Load byte (sign-extended) |
| rv32ui-p-lbu | 2 | Load byte unsigned |
| rv32ui-p-lh | 2 | Load halfword (sign-extended) |
| rv32ui-p-lhu | 2 | Load halfword unsigned |
| rv32ui-p-lw | 2 | Load word |
| rv32ui-p-sw | 3 | Store word |
| rv32ui-p-ld_st | TIMEOUT | Load/store combinations |
| rv32ui-p-sb | TIMEOUT | Store byte |
| rv32ui-p-sh | TIMEOUT | Store halfword |

**Likely Issues:**
- Byte/halfword memory access not properly supported
- May need to implement byte-enable logic in memory interface
- Sign extension bugs in load operations

**Shift Operations (4 failures)**
| Test | Error Code | Issue |
|------|------------|-------|
| rv32ui-p-sra | 13 | Shift right arithmetic |
| rv32ui-p-srai | 13 | Shift right arithmetic immediate |
| rv32ui-p-srl | 26 | Shift right logical |
| rv32ui-p-srli | 19 | Shift right logical immediate |

**Likely Issues:**
- Right shift implementation bugs in ALU
- Possible arithmetic vs logical shift confusion
- May be shifting by wrong amount

**Logical Operations (3 failures)**
| Test | Error Code | Issue |
|------|------------|-------|
| rv32ui-p-and | 9 | Bitwise AND |
| rv32ui-p-or | 9 | Bitwise OR |
| rv32ui-p-xor | 9 | Bitwise XOR |

**Likely Issues:**
- Register-register logical ops may have bugs (immediates work!)
- Possible issue with R-type instruction decode

**Unsigned Comparisons (2 failures)**
| Test | Error Code | Issue |
|------|------------|-------|
| rv32ui-p-bgeu | 7 | Branch if greater/equal unsigned |
| rv32ui-p-bltu | 4 | Branch if less than unsigned |

**Likely Issues:**
- Unsigned comparison logic in ALU may be incorrect
- Sign handling in branch comparisons

**Multiply/Divide (8 failures - all RV32M tests)**
| Test | Error Code | Issue |
|------|------------|-------|
| rv32um-p-mul | 32 | Multiply |
| rv32um-p-mulh | 7 | Multiply high (signed × signed) |
| rv32um-p-mulhsu | 7 | Multiply high (signed × unsigned) |
| rv32um-p-mulhu | 7 | Multiply high (unsigned × unsigned) |
| rv32um-p-div | 2 | Divide (signed) |
| rv32um-p-divu | 2 | Divide unsigned |
| rv32um-p-rem | 2 | Remainder (signed) |
| rv32um-p-remu | 2 | Remainder unsigned |

**Likely Issues:**
- MDU (multiply/divide unit) has bugs
- May need comprehensive debugging of MDU operations

**Other (3 failures)**
| Test | Error Code | Issue |
|------|------------|-------|
| rv32ui-p-fence_i | TIMEOUT | FENCE.I instruction |
| rv32ui-p-ma_data | TIMEOUT | Misaligned data access |
| rv32ui-p-st_ld | TIMEOUT | Store-load combinations |

**Likely Issues:**
- FENCE.I may need special handling (cache flush on real systems)
- Misaligned access not implemented (should trap or handle correctly)

---

## Bug Fixes Applied

### 1. Added FENCE Instruction Support

**File:** [rtl/core/decoder.v](../rtl/core/decoder.v#L289-L294)

**Issue:** FENCE and FENCE.I instructions were not recognized, causing illegal instruction exceptions.

**Fix:** Added `OPCODE_MISC_MEM` case to decoder:
```verilog
`OPCODE_MISC_MEM: begin
    // FENCE, FENCE.I instructions
    // For a single-core implementation without caches, these are NOPs
    // Just advance PC, no register write
    reg_write = 1'b0;
end
```

**Impact:** rv32ui-p-simple now passes (previously failed with code 1337/exception)

---

## Next Steps

### High Priority Fixes

1. **Fix Load/Store Operations**
   - Implement proper byte and halfword access
   - Add sign extension for signed loads
   - Implement byte-enable logic in memory interface
   - **Estimated Impact:** +9 tests

2. **Fix Right Shift Operations**
   - Debug SRA/SRL ALU implementation
   - Verify shift amount handling
   - Check arithmetic vs logical shift logic
   - **Estimated Impact:** +4 tests

3. **Fix Register-Register Logical Operations**
   - Debug AND/OR/XOR for R-type instructions
   - Verify funct3/funct7 decode
   - **Estimated Impact:** +3 tests

### Medium Priority

4. **Fix Unsigned Comparisons**
   - Fix BLTU/BGEU branch logic
   - Verify unsigned comparison in ALU
   - **Estimated Impact:** +2 tests

5. **Debug MDU Operations**
   - Comprehensive multiply/divide testing
   - Fix high multiply variants
   - **Estimated Impact:** +8 tests

### Low Priority

6. **Implement Misaligned Access**
   - Either handle or properly trap
   - **Estimated Impact:** +1 test

7. **FENCE.I Special Handling**
   - May need to flush instruction pipeline
   - **Estimated Impact:** +1 test

---

## Test Infrastructure Files

| File | Purpose |
|------|---------|
| [run_compliance_tests.py](../run_compliance_tests.py) | Automated test runner |
| [riscv-tests/](../riscv-tests/) | Official test suite (gitignored) |
| [sim/*.hex](../sim/) | Converted test binaries |
| [sim/testbench/tb_compliance_*.v](../sim/testbench/) | Auto-generated testbenches |
| [compliance_results.log](../compliance_results.log) | Latest test results |

---

## How Tests Work

### Test Structure

1. **Entry Point:** Tests start with a jump to `reset_vector`
2. **Initialization:** All registers initialized to 0
3. **Trap Setup:** mtvec set to trap handler address
4. **Test Execution:** Specific instruction patterns tested
5. **Result:** Pass/fail written to `tohost` register
   - `tohost = 1` → PASS
   - `tohost = (code << 1) | 1` → FAIL with error code

### Test Pass Criteria

Tests use self-checking code:
```assembly
TEST_CASE(2, x1, expected_value,
    instruction_under_test
)
```

If result doesn't match expected value, test fails with that test case number as the error code.

### Memory Layout

When converted to our format:
- **Code:** Starts at address 0x0 (relocated from 0x80000000)
- **Data (tohost):** At offset 0x1000 (word address 0x400)

---

## Running Individual Tests

### Quick Test
```bash
cd /home/furka/5level-inverter/02-embedded/riscv/sim
vvp tb_compliance_rv32ui_p_simple
```

### With Trace
Enable trace in testbench by uncommenting lines 179-182 in generated testbench.

### Debug Failed Test
```bash
# Example: Debug the 'and' instruction test
cd /home/furka/5level-inverter/02-embedded/riscv
python3 run_compliance_tests.py  # Run all tests
cd sim
vvp tb_compliance_rv32ui_p_and   # Run specific failing test
# Check error code to identify which test case failed
```

---

## Comparison with Integration Tests

| Test Suite | Tests | Pass Rate | Coverage |
|------------|-------|-----------|----------|
| Integration Tests | 28 | 100% | Basic functionality |
| Compliance Tests | 50 | 42% | ISA specification |

**Integration tests** validate basic core functionality with hand-written test patterns.

**Compliance tests** validate strict adherence to RISC-V ISA specification with official test suite.

---

## References

- [RISC-V Tests Repository](https://github.com/riscv-software-src/riscv-tests)
- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [Integration Test Analysis](./TEST_ANALYSIS.md)
- [Bug Fix Documentation](./BUG_FIX_RACE_CONDITION.md)

---

**Document Status:** Complete
**Last Updated:** 2025-12-10
**Next Review:** After fixing load/store operations
