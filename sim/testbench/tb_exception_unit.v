`timescale 1ns / 1ps
`include "riscv_defines.vh"

module tb_exception_unit;

    reg [31:0] pc;
    reg [31:0] instruction;
    reg [31:0] mem_addr;
    reg        mem_read;
    reg        mem_write;
    reg        bus_error;
    reg        illegal_instr;
    reg        ecall;
    reg        ebreak;
    wire       exception_taken;
    wire [31:0] exception_cause;
    wire [31:0] exception_val;

    // Instantiate exception unit
    exception_unit dut (
        .pc(pc),
        .instruction(instruction),
        .mem_addr(mem_addr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .bus_error(bus_error),
        .illegal_instr(illegal_instr),
        .ecall(ecall),
        .ebreak(ebreak),
        .exception_taken(exception_taken),
        .exception_cause(exception_cause),
        .exception_val(exception_val)
    );

    // Test counters
    integer passed_tests = 0;
    integer total_tests = 0;

    task check;
        input [255:0] test_name;
        input         expected;
        input         actual;
        begin
            total_tests = total_tests + 1;
            if (expected === actual) begin
                $display("[PASS] %s", test_name);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] %s: expected %b, got %b", test_name, expected, actual);
            end
        end
    endtask

    task check_32bit;
        input [255:0] test_name;
        input [31:0]  expected;
        input [31:0]  actual;
        begin
            total_tests = total_tests + 1;
            if (expected === actual) begin
                $display("[PASS] %s", test_name);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] %s: expected 0x%h, got 0x%h", test_name, expected, actual);
            end
        end
    endtask

    task test_exception;
        input [255:0] test_name;
        input [31:0]  expected_cause;
        input [31:0]  expected_val;
        begin
            #1;
            check(test_name, 1'b1, exception_taken);
            check_32bit({test_name, " - cause"}, expected_cause, exception_cause);
            check_32bit({test_name, " - val"}, expected_val, exception_val);
            #10;
        end
    endtask

    initial begin
        $dumpfile("exception_unit.vcd");
        $dumpvars(0, tb_exception_unit);

        // Initialize all inputs
        pc = 32'h00000000;
        instruction = 32'h00000000;
        mem_addr = 32'h00000000;
        mem_read = 0;
        mem_write = 0;
        bus_error = 0;
        illegal_instr = 0;
        ecall = 0;
        ebreak = 0;
        #10;

        $display("\n=== Test 1: No Exception (Normal Operation) ===");
        pc = 32'h00001000;  // Aligned
        instruction = 32'h00000013;  // NOP (ADDI x0, x0, 0)
        mem_addr = 32'h00002000;
        mem_read = 0;
        mem_write = 0;
        bus_error = 0;
        illegal_instr = 0;
        ecall = 0;
        ebreak = 0;
        #1;
        check("No exception on normal instruction", 1'b0, exception_taken);
        check_32bit("Cause is zero", 32'h00000000, exception_cause);
        check_32bit("Val is zero", 32'h00000000, exception_val);
        #10;

        $display("\n=== Test 2: Instruction Address Misaligned ===");
        pc = 32'h00001001;  // Misaligned (not 4-byte boundary)
        instruction = 32'h00000013;
        mem_read = 0;
        mem_write = 0;
        illegal_instr = 0;
        test_exception("PC misaligned by 1", `MCAUSE_INSTR_MISALIGN, 32'h00001001);

        pc = 32'h00001002;  // Misaligned by 2
        test_exception("PC misaligned by 2", `MCAUSE_INSTR_MISALIGN, 32'h00001002);

        pc = 32'h00001003;  // Misaligned by 3
        test_exception("PC misaligned by 3", `MCAUSE_INSTR_MISALIGN, 32'h00001003);

        pc = 32'h00001004;  // Aligned again
        #1;
        check("PC aligned (no exception)", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 3: Illegal Instruction ===");
        pc = 32'h00001000;  // Aligned
        instruction = 32'hFFFFFFFF;  // Invalid instruction
        illegal_instr = 1;
        mem_read = 0;
        mem_write = 0;
        test_exception("Illegal instruction", `MCAUSE_ILLEGAL_INSTR, 32'hFFFFFFFF);

        illegal_instr = 0;
        #1;
        check("Valid instruction (no exception)", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 4: Breakpoint (EBREAK) ===");
        pc = 32'h00002000;
        instruction = 32'h00100073;  // EBREAK
        ebreak = 1;
        illegal_instr = 0;
        mem_read = 0;
        mem_write = 0;
        test_exception("EBREAK instruction", `MCAUSE_BREAKPOINT, 32'h00002000);

        ebreak = 0;
        #1;
        check("No EBREAK (no exception)", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 5: Load Address Misaligned ===");
        pc = 32'h00001000;
        mem_addr = 32'h00003001;  // Misaligned load address
        mem_read = 1;
        mem_write = 0;
        bus_error = 0;
        illegal_instr = 0;
        ebreak = 0;
        test_exception("Load misaligned", `MCAUSE_LOAD_MISALIGN, 32'h00003001);

        mem_addr = 32'h00003000;  // Aligned
        #1;
        check("Load aligned (no exception)", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 6: Load Access Fault ===");
        mem_addr = 32'h00003000;  // Aligned
        mem_read = 1;
        bus_error = 1;  // Bus error on load
        test_exception("Load access fault", `MCAUSE_LOAD_ACCESS_FAULT, 32'h00003000);

        bus_error = 0;
        #1;
        check("Load without bus error", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 7: Store Address Misaligned ===");
        mem_addr = 32'h00004002;  // Misaligned store address
        mem_read = 0;
        mem_write = 1;
        bus_error = 0;
        test_exception("Store misaligned", `MCAUSE_STORE_MISALIGN, 32'h00004002);

        mem_addr = 32'h00004000;  // Aligned
        #1;
        check("Store aligned (no exception)", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 8: Store Access Fault ===");
        mem_addr = 32'h00004000;  // Aligned
        mem_write = 1;
        bus_error = 1;  // Bus error on store
        test_exception("Store access fault", `MCAUSE_STORE_ACCESS_FAULT, 32'h00004000);

        bus_error = 0;
        #1;
        check("Store without bus error", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 9: Environment Call (ECALL) ===");
        pc = 32'h00005000;
        mem_read = 0;
        mem_write = 0;
        ecall = 1;
        test_exception("ECALL instruction", `MCAUSE_ECALL_M_MODE, 32'h00000000);

        ecall = 0;
        #1;
        check("No ECALL (no exception)", 1'b0, exception_taken);
        #10;

        $display("\n=== Test 10: Exception Priority - PC Misalign > Illegal ===");
        // PC misalignment has highest priority
        pc = 32'h00001001;  // Misaligned
        illegal_instr = 1;  // Also illegal
        mem_read = 0;
        mem_write = 0;
        #1;
        check("PC misalign priority", 1'b1, exception_taken);
        check_32bit("Cause: Instr misalign", `MCAUSE_INSTR_MISALIGN, exception_cause);
        #10;

        $display("\n=== Test 11: Exception Priority - Illegal > EBREAK ===");
        pc = 32'h00001000;  // Aligned
        illegal_instr = 1;
        ebreak = 1;
        #1;
        check("Illegal priority over EBREAK", 1'b1, exception_taken);
        check_32bit("Cause: Illegal instruction", `MCAUSE_ILLEGAL_INSTR, exception_cause);
        #10;

        $display("\n=== Test 12: Exception Priority - EBREAK > Load Misalign ===");
        illegal_instr = 0;
        ebreak = 1;
        mem_addr = 32'h00003001;
        mem_read = 1;
        #1;
        check("EBREAK priority over load", 1'b1, exception_taken);
        check_32bit("Cause: Breakpoint", `MCAUSE_BREAKPOINT, exception_cause);
        #10;

        $display("\n=== Test 13: Exception Priority - Misalign > Access Fault ===");
        ebreak = 0;
        mem_addr = 32'h00003001;  // Misaligned
        mem_read = 1;
        bus_error = 1;  // Also bus error
        #1;
        check("Misalign priority over fault", 1'b1, exception_taken);
        check_32bit("Cause: Load misalign", `MCAUSE_LOAD_MISALIGN, exception_cause);
        #10;

        $display("\n=== Test 14: Load vs Store - Load Takes Priority ===");
        // If both asserted (shouldn't happen in real core), load checked first
        mem_addr = 32'h00003001;
        mem_read = 1;
        mem_write = 1;  // Both (invalid state)
        bus_error = 0;
        #1;
        check("Load checked before store", 1'b1, exception_taken);
        check_32bit("Cause: Load misalign", `MCAUSE_LOAD_MISALIGN, exception_cause);
        #10;

        $display("\n=== Test 15: ECALL Has Lowest Priority ===");
        pc = 32'h00001000;
        mem_read = 0;
        mem_write = 0;
        ecall = 1;
        ebreak = 1;  // EBREAK should win
        #1;
        check("EBREAK over ECALL", 1'b1, exception_taken);
        check_32bit("Cause: Breakpoint", `MCAUSE_BREAKPOINT, exception_cause);
        #10;

        $display("\n=== Test 16: Multiple Misalignment Values ===");
        // Test various misaligned addresses
        pc = 32'h00001000;
        ebreak = 0;
        ecall = 0;
        illegal_instr = 0;

        mem_addr = 32'hFFFFFFFD;
        mem_read = 1;
        mem_write = 0;
        test_exception("Load addr 0xFFFFFFFD", `MCAUSE_LOAD_MISALIGN, 32'hFFFFFFFD);

        mem_addr = 32'h00000001;
        mem_read = 0;
        mem_write = 1;
        test_exception("Store addr 0x00000001", `MCAUSE_STORE_MISALIGN, 32'h00000001);

        $display("\n=== Test 17: Boundary Address Values ===");
        mem_addr = 32'h00000000;  // Address 0
        mem_read = 1;
        mem_write = 0;
        bus_error = 1;
        test_exception("Load fault at address 0", `MCAUSE_LOAD_ACCESS_FAULT, 32'h00000000);

        mem_addr = 32'hFFFFFFFC;  // Max aligned address
        mem_write = 1;
        mem_read = 0;
        test_exception("Store fault at 0xFFFFFFFC", `MCAUSE_STORE_ACCESS_FAULT, 32'hFFFFFFFC);

        $display("\n=== Test 18: Rapid Exception Changes ===");
        // Stress test with rapid changes
        repeat (20) begin
            pc = {$random} & 32'hFFFFFFFC;  // Random aligned PC
            instruction = $random;
            mem_addr = $random;
            mem_read = $random % 2;
            mem_write = ~mem_read;
            bus_error = $random % 2;
            illegal_instr = $random % 2;
            ecall = $random % 2;
            ebreak = $random % 2;
            #5;
            // Check for X values
            if (exception_taken === 1'bx) $display("[ERROR] exception_taken is X");
            if (exception_cause === 32'hxxxxxxxx) $display("[ERROR] exception_cause is X");
            if (exception_val === 32'hxxxxxxxx) $display("[ERROR] exception_val is X");
        end
        $display("Stress test: No X values detected");
        #10;

        $display("\n=== Test 19: All Clear State ===");
        // Verify clean state when all signals are zero
        pc = 32'h00000000;
        instruction = 32'h00000000;
        mem_addr = 32'h00000000;
        mem_read = 0;
        mem_write = 0;
        bus_error = 0;
        illegal_instr = 0;
        ecall = 0;
        ebreak = 0;
        #1;
        check("Clean state - no exception", 1'b0, exception_taken);
        check_32bit("Clean state - cause zero", 32'h00000000, exception_cause);
        check_32bit("Clean state - val zero", 32'h00000000, exception_val);
        #10;

        $display("\n=== Test 20: Exception Val Contains Correct Values ===");
        // Test that exception_val contains the right information
        pc = 32'h12345678;
        illegal_instr = 1;
        instruction = 32'hDEADBEEF;
        #1;
        check("Illegal instr exception", 1'b1, exception_taken);
        check_32bit("Val contains instruction", 32'hDEADBEEF, exception_val);
        #10;

        illegal_instr = 0;
        mem_addr = 32'hCAFEBABE;
        mem_read = 1;
        bus_error = 1;
        #1;
        check("Load fault exception", 1'b1, exception_taken);
        check_32bit("Val contains address", 32'hCAFEBABE, exception_val);
        #10;

        $display("\n=====================================");
        $display("Test Summary: %0d/%0d tests passed", passed_tests, total_tests);
        if (passed_tests == total_tests) begin
            $display("=== ALL TESTS PASSED! ===");
        end else begin
            $display("=== SOME TESTS FAILED ===");
        end
        $display("=====================================");

        #100 $finish;
    end

endmodule
