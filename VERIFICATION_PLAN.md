# SoC Verification Plan

**Date**: 2025-12-13
**Status**: Pre-Synthesis Verification
**Goal**: Systematically verify all SoC functionality before moving to synthesis

---

## Overview

This document outlines a systematic approach to verify the complete RISC-V SoC for the 5-level inverter project. Each verification step builds confidence that the SoC is ready for FPGA synthesis and eventually ASIC implementation.

## Verification Phases

### Phase 1: Basic Functionality ✓ Ready to Test

**Objective**: Verify the SoC can boot and execute simple programs

#### 1.1 Basic SoC Top Test
- [x] Testbench created: `tb_soc_top.v`
- [ ] **RUN NOW**: Execute basic "Hello World" UART test
- [ ] Verify ROM loading
- [ ] Verify RAM access
- [ ] Verify clock generation (100 MHz → 50 MHz)
- [ ] Verify reset synchronization

**Command**:
```bash
cd 02-embedded/riscv/sim
./run_soc_top_test.sh
```

**Expected Result**: "Hello World!" received via UART, all LEDs functioning

**Success Criteria**:
- ✅ Firmware loads from ROM
- ✅ CPU executes instructions
- ✅ UART transmits correctly
- ✅ No bus errors
- ✅ Testbench reports PASS

---

### Phase 2: Individual Peripheral Verification

**Objective**: Test each peripheral in isolation before integration testing

#### 2.1 UART Peripheral
**Status**: ⚠️ Partially tested (TX only)

**Tests Needed**:
- [x] TX transmission (tested in Phase 1)
- [ ] RX reception
- [ ] Baud rate accuracy
- [ ] Interrupt generation (TX empty, RX full)
- [ ] FIFO operation (if implemented)
- [ ] Error handling (framing, parity)

**Test Firmware**: `uart_loopback_test.c`
- Transmit characters
- Receive and echo back
- Test interrupt-driven I/O

#### 2.2 PWM Accelerator
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] PWM frequency accuracy (10 kHz target)
- [ ] Duty cycle control (0-100%)
- [ ] Dead-time insertion (1 μs)
- [ ] Complementary output pairs
- [ ] All 8 channels independent operation
- [ ] Fault disable functionality
- [ ] Register read/write

**Test Firmware**: `pwm_test.c`
- Set various duty cycles
- Verify dead-time
- Test fault response
- Measure frequencies with testbench

#### 2.3 Sigma-Delta ADC
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] 4-channel operation
- [ ] Conversion accuracy
- [ ] Sample rate (10 kHz target)
- [ ] Interrupt on conversion complete
- [ ] CIC filter operation
- [ ] Oversampling ratio (OSR=100)

**Test Firmware**: `adc_test.c`
- Read all 4 channels
- Verify sample rate
- Test interrupt handling
- Compare with known input values (from testbench)

#### 2.4 Protection Peripheral
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] Overcurrent detection
- [ ] Overvoltage detection
- [ ] E-stop functionality
- [ ] PWM disable on fault
- [ ] Interrupt generation
- [ ] Fault status register
- [ ] Watchdog timer

**Test Firmware**: `protection_test.c`
- Trigger each fault condition
- Verify PWM disables
- Test watchdog timeout
- Test fault clearing

#### 2.5 Timer Peripheral
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] Counter operation
- [ ] Timer overflow
- [ ] Interrupt generation
- [ ] Prescaler settings
- [ ] Compare match

**Test Firmware**: `timer_test.c`
- Configure timer
- Test periodic interrupts
- Measure timing accuracy

#### 2.6 GPIO Peripheral
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] Output mode
- [ ] Input mode
- [ ] Bidirectional operation
- [ ] All 32 pins (16 physical + 16 internal)
- [ ] Output enable control

**Test Firmware**: `gpio_test.c`
- Toggle outputs
- Read inputs (from testbench)
- Test bidirectional mode

---

### Phase 3: Interrupt and Exception Handling

**Objective**: Verify CPU interrupt controller and exception unit work correctly in SoC context

#### 3.1 Interrupt Tests
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] UART interrupt (TX empty, RX full)
- [ ] Timer interrupt
- [ ] ADC conversion complete interrupt
- [ ] Protection fault interrupt
- [ ] Multiple simultaneous interrupts
- [ ] Interrupt priority (if implemented)
- [ ] Interrupt nesting
- [ ] CSR access (mstatus, mie, mip, mcause, mepc)

**Test Firmware**: `interrupt_test.c`
- Enable interrupts
- Trigger each source
- Verify ISR execution
- Test interrupt latency

#### 3.2 Exception Tests
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] Illegal instruction exception
- [ ] Misaligned access exception
- [ ] Breakpoint (EBREAK)
- [ ] Environment call (ECALL)
- [ ] Exception handler execution
- [ ] Return from exception (MRET)

**Test Firmware**: `exception_test.c`
- Trigger each exception type
- Verify handler execution
- Test exception recovery

---

### Phase 4: Memory Subsystem Verification

**Objective**: Thoroughly test ROM, RAM, and memory access patterns

#### 4.1 ROM Tests
**Status**: ⚠️ Basic test only

**Tests Needed**:
- [ ] Full address range (0x00000000 - 0x00007FFF)
- [ ] Word, halfword, byte reads
- [ ] Boundary conditions
- [ ] Access timing (combinatorial read)

**Test Firmware**: Built into other tests

#### 4.2 RAM Tests
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] Full address range (0x00010000 - 0x0001FFFF)
- [ ] Word read/write
- [ ] Halfword read/write (signed/unsigned)
- [ ] Byte read/write (signed/unsigned)
- [ ] Misaligned access handling
- [ ] Read-modify-write operations
- [ ] Memory barriers (if needed)

**Test Firmware**: `memory_test.c`
- Walking 1s/0s pattern
- Address uniqueness test
- Random read/write
- Stress test

#### 4.3 Wishbone Bus Tests
**Status**: ⚠️ Not tested

**Tests Needed**:
- [ ] Arbiter priority (ibus vs dbus)
- [ ] Simultaneous access
- [ ] Bus timeout handling
- [ ] Error responses
- [ ] Back-to-back transactions
- [ ] Address decoding

**Test Firmware**: `bus_stress_test.c`
- Simultaneous instruction and data access
- Peripheral access patterns
- Boundary cases

---

### Phase 5: Integration Testing

**Objective**: Test realistic use cases combining multiple peripherals

#### 5.1 Control Loop Test
**Status**: ⚠️ Not created

**Test Description**:
Implement a simple control loop that mimics the inverter control:
1. Read ADC values (voltage/current)
2. Run control algorithm (PI/PR)
3. Update PWM duty cycles
4. Check protection limits
5. Repeat at 10 kHz

**Test Firmware**: `control_loop_test.c`

**Verification**:
- [ ] Control loop frequency (10 kHz)
- [ ] ADC sampling synchronized with PWM
- [ ] ISR execution time < 50 μs
- [ ] No missed interrupts
- [ ] Correct PWM updates
- [ ] Protection triggers on fault

#### 5.2 Communication Test
**Status**: ⚠️ Not created

**Test Description**:
Test UART communication while control loop is running:
1. Run control loop in background (timer interrupt)
2. Transmit status via UART
3. Receive commands via UART
4. Parse and execute commands

**Test Firmware**: `uart_command_test.c`

**Verification**:
- [ ] UART doesn't interfere with control timing
- [ ] Commands processed correctly
- [ ] Status updates sent periodically
- [ ] No data corruption

#### 5.3 Fault Handling Test
**Status**: ⚠️ Not created

**Test Description**:
Test complete fault response:
1. Run control loop
2. Trigger overcurrent fault
3. Verify immediate PWM disable
4. Verify interrupt generated
5. Log fault to UART
6. Test recovery procedure

**Test Firmware**: `fault_test.c`

**Verification**:
- [ ] PWM disabled within 1 μs of fault
- [ ] Interrupt latency measured
- [ ] Fault logged correctly
- [ ] Manual recovery only (no auto-restart)

---

### Phase 6: RISC-V Compliance

**Objective**: Verify CPU core remains compliant when integrated in SoC

#### 6.1 ISA Compliance
**Status**: ⚠️ Not run on SoC

**Tests**:
- [ ] RV32I base instruction set
- [ ] RV32M multiplication/division
- [ ] All tests from `riscv-tests/isa/rv32ui-p-*`
- [ ] All tests from `riscv-tests/isa/rv32um-p-*`

**Note**: You mentioned 98% compliance - verify this on the integrated SoC, not just the isolated core

#### 6.2 CSR Compliance
**Status**: ⚠️ Needs verification

**Tests**:
- [ ] Machine-mode CSRs
- [ ] Interrupt CSRs with real interrupts
- [ ] Exception CSRs with real exceptions
- [ ] Performance counters (if implemented)

---

### Phase 7: Performance and Stress Testing

**Objective**: Verify SoC meets real-time requirements

#### 7.1 Timing Analysis
**Status**: ⚠️ Not performed

**Measurements**:
- [ ] Control loop ISR execution time
- [ ] Maximum interrupt latency
- [ ] ADC conversion time
- [ ] UART baud rate accuracy
- [ ] PWM frequency accuracy
- [ ] Bus arbitration delay

**Tools**: Testbench assertions, performance counters

#### 7.2 Stress Tests
**Status**: ⚠️ Not performed

**Tests**:
- [ ] All peripherals active simultaneously
- [ ] Maximum interrupt rate
- [ ] Continuous RAM access
- [ ] Worst-case bus contention
- [ ] Long-duration test (millions of cycles)

---

## Verification Checklist Summary

### Must-Pass Before Synthesis

**Critical Path**:
- [ ] Phase 1: Basic functionality (UART test)
- [ ] Phase 2.2: PWM accelerator (core functionality)
- [ ] Phase 2.3: ADC peripheral (core functionality)
- [ ] Phase 2.4: Protection peripheral (safety critical!)
- [ ] Phase 3.1: Basic interrupt handling
- [ ] Phase 5.1: Simple control loop
- [ ] Phase 2.4: Fault handling in control context

**Important**:
- [ ] Phase 2.1: UART RX/TX complete
- [ ] Phase 2.5: Timer peripheral
- [ ] Phase 4.2: RAM comprehensive test
- [ ] Phase 5.3: Complete fault response

**Nice to Have**:
- [ ] Phase 2.6: GPIO (for debug/status)
- [ ] Phase 6: Full compliance (already 98%)
- [ ] Phase 7: Performance characterization

---

## Test Firmware Organization

Recommended directory structure:
```
02-embedded/riscv/firmware/
├── test_soc/              # Basic "Hello World" (DONE)
├── test_uart/             # UART loopback test
├── test_pwm/              # PWM peripheral test
├── test_adc/              # ADC peripheral test
├── test_protection/       # Protection peripheral test
├── test_timer/            # Timer peripheral test
├── test_gpio/             # GPIO peripheral test
├── test_interrupts/       # Interrupt handling test
├── test_exceptions/       # Exception handling test
├── test_memory/           # Memory subsystem test
├── test_control_loop/     # Integration: control loop
├── test_fault_handling/   # Integration: fault response
└── examples/              # Application examples (existing)
```

---

## Recommended Next Steps

### Immediate (Today/Tomorrow):
1. **Run the basic SoC test** we just created
   ```bash
   cd 02-embedded/riscv/sim
   ./run_soc_top_test.sh
   ```

2. **If it passes**, create individual peripheral testbenches:
   - Start with **PWM** (highest priority for inverter)
   - Then **ADC** (needed for control loop)
   - Then **Protection** (safety critical)

3. **If it fails**, debug using waveforms:
   ```bash
   gtkwave tb_soc_top.vcd
   ```

### Short Term (This Week):
4. Create comprehensive testbenches for PWM, ADC, Protection
5. Create simple firmware tests for each peripheral
6. Test basic interrupt handling
7. Create a simple control loop test

### Medium Term (Next Week):
8. Integration testing with realistic workloads
9. Fault injection and recovery testing
10. Performance characterization
11. Documentation of all test results

### Before Synthesis:
12. Review all critical test results
13. Fix any bugs found
14. Document known limitations
15. Create synthesis verification plan

---

## Success Criteria

The SoC is ready for synthesis when:

✅ **Functional**:
- All peripherals tested individually
- Integration tests pass
- Control loop runs at 10 kHz
- Fault response time < 1 μs

✅ **Reliable**:
- No bus errors or crashes
- Stable under stress testing
- Interrupts handled correctly
- Exceptions don't hang system

✅ **Safe**:
- Protection peripheral verified
- PWM disables on fault
- Watchdog functional
- No spurious PWM outputs

✅ **Documented**:
- All tests documented
- Results logged and reviewed
- Known issues listed
- Workarounds documented

---

## Timeline Estimate

**Optimistic**: 2-3 days (if everything works)
**Realistic**: 1 week (with some debugging)
**Pessimistic**: 2 weeks (if major issues found)

**Critical Path**: Phase 1 → Phase 2.2/2.3/2.4 → Phase 5.1 → Synthesis

---

## References

- [tb_soc_top.v](sim/testbench/tb_soc_top.v) - Basic SoC testbench
- [soc_top.v](rtl/soc/soc_top.v) - SoC top-level module
- [memory_map.h](firmware/memory_map.h) - Peripheral addresses
- [RISC-V Compliance Tests](riscv-tests/) - ISA compliance suite

---

**Last Updated**: 2025-12-13
**Owner**: Project Team
**Status**: Ready to begin Phase 1 testing
