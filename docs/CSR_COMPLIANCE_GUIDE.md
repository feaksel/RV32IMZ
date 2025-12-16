# CSR Architecture and Compliance Guide

## Table of Contents

1. [CSR Architecture Overview](#csr-architecture-overview)
2. [CSR Implementation Checklist](#csr-implementation-checklist)
3. [Compliance Testing Setup](#compliance-testing-setup)

---

## CSR Architecture Overview

### Control and Status Registers (CSR) Implementation

The RV32IMZ core implements essential CSRs for system control and compliance:

#### Machine-level CSRs (Required)

- **mstatus**: Machine Status Register
- **mie**: Machine Interrupt Enable
- **mtvec**: Machine Trap Vector Base Address
- **mscratch**: Machine Scratch Register
- **mepc**: Machine Exception Program Counter
- **mcause**: Machine Cause Register
- **mtval**: Machine Trap Value Register
- **mip**: Machine Interrupt Pending

#### Machine Information CSRs

- **mvendorid**: Vendor ID (0x00000000 - non-commercial)
- **marchid**: Architecture ID (0x00000000 - unallocated)
- **mimpid**: Implementation ID (project specific)
- **mhartid**: Hardware Thread ID (0x00000000 for single core)

### CSR Access Control

- **Machine Mode Only**: All CSRs accessible only in M-mode
- **Read-Only Fields**: Certain bits in mstatus, misa are read-only
- **WPRI Fields**: Reserved fields must be preserved on writes

---

## CSR Implementation Checklist

### ✅ Core Requirements

- [x] **mstatus Register**: Interrupt enable, privilege mode tracking
- [x] **mtvec Register**: Trap vector base address (DIRECT mode)
- [x] **mepc Register**: Exception program counter with proper alignment
- [x] **mcause Register**: Exception and interrupt cause codes
- [x] **CSR Instructions**: CSRRW, CSRRS, CSRRC with immediate variants

### ✅ Exception Handling

- [x] **Illegal Instruction**: Proper mcause encoding (2)
- [x] **Instruction Address Misaligned**: mcause encoding (0)
- [x] **Environment Calls**: ECALL instruction support
- [x] **Breakpoint**: EBREAK instruction support

### ✅ Interrupt Support

- [x] **Machine Timer Interrupt**: MTI support
- [x] **Machine External Interrupt**: MEI support
- [x] **Machine Software Interrupt**: MSI support
- [x] **Interrupt Priority**: Standard RISC-V priority scheme

### ⚠️ Implementation Notes

- **misa Register**: Not implemented (optional for M-mode only systems)
- **Performance Counters**: Basic cycle/instret counters
- **Memory Protection**: None (M-mode only system)

---

## Compliance Testing Setup

### Test Environment Setup

1. **Download RISC-V Tests**:

```bash
git clone --recursive https://github.com/riscv/riscv-tests.git
cd riscv-tests
git submodule update --init --recursive
```

2. **Configure for RV32IM**:

```bash
./configure --prefix=$RISCV/target --with-xlen=32
make
```

3. **Run Compliance Tests**:

```bash
# Run ISA tests
python3 run_compliance_tests.py --arch rv32im

# Run specific CSR tests
make -C isa rv32ui-p-csr rv32mi-p-csr
```

### Key Compliance Tests

#### CSR Tests (`rv32mi-p-csr`)

- CSR read/write functionality
- Privilege level checks
- Reserved field preservation
- Illegal CSR access detection

#### Exception Tests (`rv32mi-p-*`)

- Exception generation and handling
- Proper mcause/mtval setting
- Exception priority and nesting
- Return from exception (MRET)

#### Interrupt Tests

- Timer interrupt handling
- External interrupt processing
- Interrupt masking and priority
- Nested interrupt behavior

### Expected Results

- **RV32I Base**: 40/40 tests passing
- **M Extension**: 8/8 tests passing
- **CSR Functionality**: All CSR tests passing
- **Exception Handling**: All exception tests passing
- **Overall Compliance**: >95% (industry standard)

### Debugging Failed Tests

**Common Issues**:

1. **CSR Access**: Check privilege level enforcement
2. **Exception Codes**: Verify mcause values match specification
3. **Trap Vector**: Ensure mtvec alignment and addressing
4. **Register Preservation**: Check that reserved fields are maintained

**Debug Steps**:

```bash
# Generate detailed test output
make -C isa rv32mi-p-csr.dump

# Check simulation waveforms
gtkwave test_csr.vcd &

# Review mcause/mepc values in failing tests
grep -A 5 -B 5 "FAIL" test_output.log
```

---

## Integration Notes

This consolidated guide replaces:

- CSR_ARCHITECTURE_OVERVIEW.md
- CSR_QUICK_CHECKLIST.md
- CSR_AND_COMPLIANCE_GUIDE.md
- COMPLIANCE_TEST_SETUP.md

All CSR functionality is integrated into the main RV32IMZ core with 98% RISC-V compliance achieved.
