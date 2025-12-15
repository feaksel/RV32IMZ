`timescale 1ns / 1ps
`include "riscv_defines.vh"

module tb_interrupt_controller;

    reg        clk;
    reg        rst_n;
    reg        timer_int;
    reg        external_int;
    reg        software_int;
    reg [15:0] peripheral_ints;
    reg        global_int_en;
    reg [31:0] mie;
    wire [31:0] interrupt_lines;
    wire        interrupt_req;
    wire [31:0] interrupt_cause;

    // Instantiate interrupt controller
    interrupt_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .timer_int(timer_int),
        .external_int(external_int),
        .software_int(software_int),
        .peripheral_ints(peripheral_ints),
        .global_int_en(global_int_en),
        .mie(mie),
        .interrupt_lines(interrupt_lines),
        .interrupt_req(interrupt_req),
        .interrupt_cause(interrupt_cause)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
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

    initial begin
        $dumpfile("interrupt_controller.vcd");
        $dumpvars(0, tb_interrupt_controller);

        // Initialize
        rst_n = 0;
        timer_int = 0;
        external_int = 0;
        software_int = 0;
        peripheral_ints = 16'h0;
        global_int_en = 0;
        mie = 32'h0;

        #20 rst_n = 1;
        #10;

        $display("\n=== Test 1: Interrupt Lines Mapping ===");
        // Test that interrupts are mapped to correct bit positions
        timer_int = 1;
        external_int = 0;
        software_int = 0;
        peripheral_ints = 16'h0;
        #1;
        check_32bit("Timer interrupt at bit 7", 32'h00000080, interrupt_lines);

        timer_int = 0;
        external_int = 1;
        #1;
        check_32bit("External interrupt at bit 11", 32'h00000800, interrupt_lines);

        external_int = 0;
        software_int = 1;
        #1;
        check_32bit("Software interrupt at bit 3", 32'h00000008, interrupt_lines);

        software_int = 0;
        peripheral_ints = 16'hABCD;
        #1;
        check_32bit("Peripheral interrupts at bits 31:16", 32'hABCD0000, interrupt_lines);
        #10;

        $display("\n=== Test 2: No Interrupt When Disabled ===");
        // Even with interrupts pending, no request if disabled
        timer_int = 1;
        external_int = 1;
        software_int = 1;
        global_int_en = 0;  // Disabled
        mie = 32'hFFFFFFFF;  // All enabled in mask
        #1;
        check("No interrupt when globally disabled", 1'b0, interrupt_req);
        #10;

        $display("\n=== Test 3: No Interrupt When Not in MIE Mask ===");
        global_int_en = 1;  // Enable globally
        mie = 32'h00000000;  // But mask all interrupts
        #1;
        check("No interrupt when masked", 1'b0, interrupt_req);
        #10;

        $display("\n=== Test 4: Single Interrupt - Timer ===");
        timer_int = 1;
        external_int = 0;
        software_int = 0;
        peripheral_ints = 16'h0;
        global_int_en = 1;
        mie = 32'h00000088;  // Enable timer (bit 7)
        #1;
        check("Timer interrupt request", 1'b1, interrupt_req);
        check_32bit("Timer interrupt cause", `MCAUSE_TIMER_INT, interrupt_cause);
        #10;

        $display("\n=== Test 5: Single Interrupt - External ===");
        timer_int = 0;
        external_int = 1;
        mie = 32'h00000808;  // Enable external (bit 11)
        #1;
        check("External interrupt request", 1'b1, interrupt_req);
        check_32bit("External interrupt cause", `MCAUSE_EXTERNAL_INT, interrupt_cause);
        #10;

        $display("\n=== Test 6: Single Interrupt - Software ===");
        external_int = 0;
        software_int = 1;
        mie = 32'h00000008;  // Enable software (bit 3)
        #1;
        check("Software interrupt request", 1'b1, interrupt_req);
        check_32bit("Software interrupt cause", `MCAUSE_SOFTWARE_INT, interrupt_cause);
        #10;

        $display("\n=== Test 7: Interrupt Priority - External > Software ===");
        // Both pending, external should win
        timer_int = 0;
        external_int = 1;
        software_int = 1;
        mie = 32'h00000808 | 32'h00000008;  // Enable both
        #1;
        check("Priority: External over Software", 1'b1, interrupt_req);
        check_32bit("Cause: External interrupt", `MCAUSE_EXTERNAL_INT, interrupt_cause);
        #10;

        $display("\n=== Test 8: Interrupt Priority - External > Timer ===");
        timer_int = 1;
        external_int = 1;
        software_int = 0;
        mie = 32'h00000888;  // Enable both external and timer
        #1;
        check("Priority: External over Timer", 1'b1, interrupt_req);
        check_32bit("Cause: External interrupt", `MCAUSE_EXTERNAL_INT, interrupt_cause);
        #10;

        $display("\n=== Test 9: Interrupt Priority - Software > Timer ===");
        timer_int = 1;
        external_int = 0;
        software_int = 1;
        mie = 32'h00000088;  // Enable both software and timer
        #1;
        check("Priority: Software over Timer", 1'b1, interrupt_req);
        check_32bit("Cause: Software interrupt", `MCAUSE_SOFTWARE_INT, interrupt_cause);
        #10;

        $display("\n=== Test 10: All Standard Interrupts Simultaneously ===");
        // Priority should be: External > Software > Timer
        timer_int = 1;
        external_int = 1;
        software_int = 1;
        mie = 32'h00000888;  // Enable all three
        #1;
        check("All pending: External wins", 1'b1, interrupt_req);
        check_32bit("Cause: External interrupt", `MCAUSE_EXTERNAL_INT, interrupt_cause);
        #10;

        $display("\n=== Test 11: Peripheral Interrupt (Bit 16) ===");
        timer_int = 0;
        external_int = 0;
        software_int = 0;
        peripheral_ints = 16'h0001;  // Peripheral interrupt at bit 16
        mie = 32'h00010000;  // Enable bit 16
        #1;
        check("Peripheral interrupt request", 1'b1, interrupt_req);
        check_32bit("Peripheral interrupt cause", 32'h80000010, interrupt_cause);
        #10;

        $display("\n=== Test 12: Peripheral Interrupt (Bit 31) ===");
        peripheral_ints = 16'h8000;  // Peripheral interrupt at bit 31
        mie = 32'h80000000;  // Enable bit 31
        #1;
        check("High peripheral interrupt request", 1'b1, interrupt_req);
        check_32bit("High peripheral interrupt cause", 32'h8000001F, interrupt_cause);
        #10;

        $display("\n=== Test 13: Multiple Peripheral Interrupts ===");
        // Highest bit should win
        peripheral_ints = 16'hFFFF;  // All peripheral interrupts
        mie = 32'hFFFF0000;  // Enable all peripheral interrupts
        #1;
        check("Multiple peripherals: Highest wins", 1'b1, interrupt_req);
        check_32bit("Cause: Bit 31", 32'h8000001F, interrupt_cause);
        #10;

        $display("\n=== Test 14: Standard Interrupt Priority Over Peripheral ===");
        // External interrupt should have priority over peripheral
        external_int = 1;
        peripheral_ints = 16'hFFFF;
        mie = 32'hFFFF0888;  // Enable all
        #1;
        check("Standard over peripheral", 1'b1, interrupt_req);
        check_32bit("Cause: External (not peripheral)", `MCAUSE_EXTERNAL_INT, interrupt_cause);
        #10;

        $display("\n=== Test 15: Interrupt Cleared When Source Deasserted ===");
        external_int = 1;
        mie = 32'h00000800;
        #1;
        check("Interrupt pending", 1'b1, interrupt_req);
        external_int = 0;
        #1;
        check("Interrupt cleared", 1'b0, interrupt_req);
        #10;

        $display("\n=== Test 16: Dynamic MIE Mask Change ===");
        timer_int = 1;
        mie = 32'h00000080;  // Timer enabled
        #1;
        check("Timer interrupt active", 1'b1, interrupt_req);
        mie = 32'h00000000;  // Mask timer
        #1;
        check("Timer interrupt masked", 1'b0, interrupt_req);
        mie = 32'h00000080;  // Re-enable timer
        #1;
        check("Timer interrupt active again", 1'b1, interrupt_req);
        #10;

        $display("\n=== Test 17: Global Enable Toggle ===");
        timer_int = 1;
        mie = 32'h00000080;
        global_int_en = 1;
        #1;
        check("Interrupt with global enable", 1'b1, interrupt_req);
        global_int_en = 0;
        #1;
        check("Interrupt blocked by global disable", 1'b0, interrupt_req);
        global_int_en = 1;
        #1;
        check("Interrupt restored with global enable", 1'b1, interrupt_req);
        #10;

        $display("\n=== Test 18: Edge Cases - All Zeros ===");
        timer_int = 0;
        external_int = 0;
        software_int = 0;
        peripheral_ints = 16'h0;
        mie = 32'hFFFFFFFF;
        global_int_en = 1;
        #1;
        check("No interrupt when no source", 1'b0, interrupt_req);
        check_32bit("Cause is zero", 32'h00000000, interrupt_cause);
        #10;

        $display("\n=== Test 19: Stress Test - Rapid Changes ===");
        repeat (10) begin
            timer_int = $random;
            external_int = $random;
            software_int = $random;
            peripheral_ints = $random;
            mie = $random;
            global_int_en = $random;
            #10;
            // Just check no X values
            if (interrupt_req === 1'bx) begin
                $display("[FAIL] interrupt_req is X");
            end
            if (interrupt_cause === 32'hxxxxxxxx) begin
                $display("[FAIL] interrupt_cause is X");
            end
        end
        $display("Stress test: No X values");
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
