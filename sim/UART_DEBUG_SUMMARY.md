# UART Multi-Character Transmission Debug Summary

**Date:** 2025-12-14
**Status:** ✅ **RESOLVED**
**Test:** SoC Top Testbench - "Hello World!" UART transmission

---

## Problem Statement

The SoC testbench was failing when transmitting multi-character messages via UART:
- **First character 'H' (0x48)**: ✅ Received correctly
- **Second character 'e' (0x65)**: ❌ Received as 0xd9 (corrupted)
- **Subsequent characters**: Not tested due to early failure

## Investigation Process

### 1. Initial Hypothesis: UART Transmission Bug

**Theory:** UART state machine was not properly handling consecutive character transmissions.

**Test:** Added comprehensive debug to UART module to trace:
- `tx_start` pulse timing
- Data loading into `tx_shift_reg`
- Bit-by-bit transmission

**Finding:**
```
[UART] DATA write 0x65 ('e'), tx_empty=1 before write
[UART] TX_IDLE -> TX_START, loading tx_shift_reg=0x65 from tx_data
[UART] TX bit[0] = 1 (shift_reg=0x65)
[UART] TX bit[1] = 0 (shift_reg=0x32)
[UART] TX bit[2] = 1 (shift_reg=0x19)  ← Correct!
...
```

**Conclusion:** ✅ **UART was transmitting correctly!** The UART loaded 0x65 and transmitted bits 1,0,1,0,0,1,1,0 as expected.

### 2. Root Cause: Testbench Synchronization Bug

**Discovery:** Testbench was receiving incorrect bits:
```
Expected 'e' (0x65): 1,0,1,0,0,1,1,0
Received:            1,0,0,1,1,0,1,1 (0xd9)
```

UART transmitted correctly, but testbench sampled at wrong times for characters 1-12.

**Root Cause Identified:**

The testbench had a **double negedge wait** bug in the character reception loop:

```verilog
// BUGGY CODE
for (byte_count = 0; byte_count < 13; byte_count = byte_count + 1) begin
    @(negedge uart_tx);  // Line 130: Wait for start bit
    // ... sample bits ...

    if (byte_count < 12) begin
        #(UART_BIT_PERIOD / 2);
        @(negedge uart_tx);  // Line 184: Wait for NEXT start bit
    end
end
```

**Problem:** For bytes 1-12, the code would:
1. Line 184 (end of previous byte): Wait for negedge (start bit of next byte)
2. Line 130 (start of current byte): Wait for negedge **AGAIN**!

This caused the testbench to sync on a random bit transition **within** the byte instead of the actual start bit, resulting in bit sampling at incorrect times.

## Solution

**Fix:** Modified testbench to only wait for negedge once per character:

```verilog
// FIXED CODE
for (byte_count = 0; byte_count < 13; byte_count = byte_count + 1) begin
    // Only wait for first character; subsequent chars already synced
    if (byte_count == 0) begin
        @(negedge uart_tx);
    end
    $display("INFO: UART Start bit detected for byte %0d", byte_count);

    // ... sample bits ...

    if (byte_count < 12) begin
        #(UART_BIT_PERIOD / 2);
        @(negedge uart_tx);  // Sync for NEXT iteration
    end
end
```

**File Modified:** [`testbench/tb_soc_top.v`](testbench/tb_soc_top.v) lines 127-189

## Test Results

### Before Fix
```
INFO: [00] Received 0x48 'H' - OK
ERROR: [01] Received 0xd9, expected 0x65
FAIL: UART data mismatch!
```

### After Fix
```
INFO: [00] Received 0x48 'H' - OK
INFO: [01] Received 0x65 'e' - OK
INFO: [02] Received 0x6c 'l' - OK
INFO: [03] Received 0x6c 'l' - OK
INFO: [04] Received 0x6f 'o' - OK
INFO: [05] Received 0x20 ' ' - OK
INFO: [06] Received 0x57 'W' - OK
INFO: [07] Received 0x6f 'o' - OK
INFO: [08] Received 0x72 'r' - OK
INFO: [09] Received 0x6c 'l' - OK
INFO: [10] Received 0x64 'd' - OK
INFO: [11] Received 0x21 '!' - OK
INFO: [12] Received 0x0a - OK
========================================
PASS: Successfully received 'Hello World!' via UART
========================================
✓ TESTBENCH PASSED!
```

## Key Learnings

1. **Isolate the Bug:** Created minimal test cases:
   - Standalone UART test ([`test_uart_simple.v`](test_uart_simple.v)): ✅ Passed
   - Single character SoC test ([`tb_single_char.v`](testbench/tb_single_char.v)): ✅ Passed
   - Multi-character SoC test ([`tb_soc_top.v`](testbench/tb_soc_top.v)): ❌ Failed

   This proved the UART hardware was correct and narrowed the issue to testbench timing.

2. **Verify Assumptions:** Added debug to show what the UART was actually transmitting vs. what the testbench was receiving. The mismatch revealed the testbench sampling error.

3. **Systematic Debugging:** Instead of making "firmware shortcuts" or workarounds, we traced the issue to its root cause in the testbench synchronization logic.

## Related Bugs Fixed in This Session

### Bug #1: Clock Divider (CRITICAL)
**File:** [`rtl/soc/soc_top.v`](../rtl/soc/soc_top.v) lines 73-82
**Issue:** Clock divider was creating 25 MHz instead of 50 MHz (divide-by-4 instead of divide-by-2)
**Impact:** All peripherals running at half speed, UART baud rate wrong
**Fix:** Changed to simple toggle for divide-by-2:
```verilog
// BEFORE (WRONG - divide by 4)
clk_div <= ~clk_div;
if (clk_div)
    clk_50mhz <= ~clk_50mhz;

// AFTER (CORRECT - divide by 2)
clk_50mhz <= ~clk_50mhz;
```

## Files Modified

| File | Change | Lines |
|------|--------|-------|
| [`testbench/tb_soc_top.v`](testbench/tb_soc_top.v) | Fixed double negedge wait bug | 127-189 |
| [`rtl/peripherals/uart.v`](../rtl/peripherals/uart.v) | Removed verbose debug output | 120-330 |
| [`rtl/soc/soc_top.v`](../rtl/soc/soc_top.v) | Fixed clock divider (previous session) | 73-82 |

## Verification

**Test Command:**
```bash
cd /home/furka/5level-inverter/02-embedded/riscv/sim
./run_soc_top_test.sh
```

**Expected Output:**
- All 13 characters of "Hello World!\n" received correctly
- PASS message displayed
- Exit code 0

**Waveform Analysis:**
```bash
gtkwave tb_soc_top.vcd
```
Key signals: `dut.uart_tx`, `dut.uart.tx_state`, `dut.uart.tx_shift_reg`

---

**Author:** Claude Code (Systematic debugging session)
**Version:** 1.0
**Next Steps:** Proceed with peripheral testbenches (PWM, ADC, Timer, GPIO, Protection)
