`timescale 1ns/1ps

/**
 * @file tb_carrier_generator.v
 * @brief Testbench for Level-Shifted Carrier Generator
 *
 * Tests:
 * 1. Basic triangular waveform generation
 * 2. Direction reversal at peaks and valleys
 * 3. Level shifting for carrier1 and carrier2
 * 4. Sync pulse generation at peaks
 * 5. Enable/disable functionality
 * 6. Frequency divider operation
 *
 * @author RISC-V SoC Team
 * @date 2025-12-14
 */

module tb_carrier_generator;

    //==========================================================================
    // Parameters
    //==========================================================================

    localparam CARRIER_WIDTH = 8;   // Use 8-bit for faster testing
    localparam COUNTER_WIDTH = 16;
    localparam CLK_PERIOD = 20;  // 50 MHz clock (20ns period)

    // Test constants for 8-bit carriers
    localparam signed MIN_CARRIER1 = -128;  // -(2^7)
    localparam signed MAX_CARRIER1 = -1;    // -(2^7) + (2^(7-1)) - 1
    localparam signed MIN_CARRIER2 = 0;
    localparam signed MAX_CARRIER2 = 127;   // (2^7) - 1

    //==========================================================================
    // DUT Signals
    //==========================================================================

    reg                             clk;
    reg                             rst_n;
    reg                             enable;
    reg  [COUNTER_WIDTH-1:0]        freq_div;

    wire signed [CARRIER_WIDTH-1:0] carrier1;
    wire signed [CARRIER_WIDTH-1:0] carrier2;
    wire signed [CARRIER_WIDTH-1:0] carrier3;
    wire signed [CARRIER_WIDTH-1:0] carrier4;
    wire                            sync_pulse;

    //==========================================================================
    // Test Variables
    //==========================================================================

    integer test_pass_count;
    integer test_fail_count;
    integer cycle_count;
    integer sync_count;
    integer i;
    integer direction_changes;
    integer update_count;

    reg signed [CARRIER_WIDTH-1:0] prev_carrier1;
    reg signed [CARRIER_WIDTH-1:0] prev_carrier2;
    reg signed [CARRIER_WIDTH-1:0] sample1;
    reg signed [CARRIER_WIDTH-1:0] sample2;
    reg going_up;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    carrier_generator #(
        .CARRIER_WIDTH(CARRIER_WIDTH),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .freq_div(freq_div),
        .carrier1(carrier1),
        .carrier2(carrier2),
        .carrier3(carrier3),
        .carrier4(carrier4),
        .sync_pulse(sync_pulse)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Waveform Dumping
    //==========================================================================

    initial begin
        $dumpfile("tb_carrier_generator.vcd");
        $dumpvars(0, tb_carrier_generator);
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================

    initial begin
        $display("========================================");
        $display("Carrier Generator Testbench");
        $display("========================================");

        // Initialize
        test_pass_count = 0;
        test_fail_count = 0;
        rst_n = 0;
        enable = 0;
        freq_div = 16'd10;  // Fast frequency for testing

        // Reset
        #100;
        rst_n = 1;
        #100;

        //----------------------------------------------------------------------
        // Test 1: Basic Operation with Enable
        //----------------------------------------------------------------------
        $display("\n[TEST 1] Basic triangular waveform generation");
        enable = 1;
        cycle_count = 0;
        sync_count = 0;

        // Run for one complete cycle (0 -> max -> 0)
        prev_carrier1 = carrier1;
        prev_carrier2 = carrier2;

        // Wait for first sync pulse
        @(posedge sync_pulse);
        sync_count = sync_count + 1;
        $display("  INFO: First sync pulse at time %0t", $time);

        // Wait for second sync pulse (one complete cycle)
        @(posedge sync_pulse);
        sync_count = sync_count + 1;
        $display("  INFO: Second sync pulse at time %0t", $time);

        if (sync_count == 2) begin
            $display("  PASS: Sync pulses generated correctly");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: Expected 2 sync pulses, got %0d", sync_count);
            test_fail_count = test_fail_count + 1;
        end

        //----------------------------------------------------------------------
        // Test 2: Carrier Range Verification
        //----------------------------------------------------------------------
        $display("\n[TEST 2] Carrier range verification");

        // Check carrier1 range
        if (carrier1 >= MIN_CARRIER1 && carrier1 <= MAX_CARRIER1) begin
            $display("  PASS: carrier1 in range [%0d, %0d], current value = %0d",
                     MIN_CARRIER1, MAX_CARRIER1, carrier1);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: carrier1 out of range [%0d, %0d], value = %0d",
                     MIN_CARRIER1, MAX_CARRIER1, carrier1);
            test_fail_count = test_fail_count + 1;
        end

        // Check carrier2 range
        if (carrier2 >= MIN_CARRIER2 && carrier2 <= MAX_CARRIER2) begin
            $display("  PASS: carrier2 in range [%0d, %0d], current value = %0d",
                     MIN_CARRIER2, MAX_CARRIER2, carrier2);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: carrier2 out of range [%0d, %0d], value = %0d",
                     MIN_CARRIER2, MAX_CARRIER2, carrier2);
            test_fail_count = test_fail_count + 1;
        end

        //----------------------------------------------------------------------
        // Test 3: Direction Reversal at Peaks
        //----------------------------------------------------------------------
        $display("\n[TEST 3] Direction reversal at peaks and valleys");

        // Sample carriers over time and verify monotonic up, then down
        // Run for at least one full cycle
        direction_changes = 0;
        going_up = 1;

        for (i = 0; i < 600; i = i + 1) begin
            sample1 = carrier1;
            #(CLK_PERIOD * (freq_div + 1));  // Wait for one carrier update
            sample2 = carrier1;

            if (going_up && sample2 < sample1) begin
                going_up = 0;
                direction_changes = direction_changes + 1;
                $display("  INFO: Direction changed to DOWN at time %0t (carrier1=%0d)",
                         $time, sample1);
            end else if (!going_up && sample2 > sample1) begin
                going_up = 1;
                direction_changes = direction_changes + 1;
                $display("  INFO: Direction changed to UP at time %0t (carrier1=%0d)",
                         $time, sample1);
            end
        end

        if (direction_changes >= 2) begin
            $display("  PASS: Direction reversal working (%0d changes detected)", direction_changes);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: Insufficient direction changes (%0d)", direction_changes);
            test_fail_count = test_fail_count + 1;
        end

        //----------------------------------------------------------------------
        // Test 4: Enable/Disable Functionality
        //----------------------------------------------------------------------
        $display("\n[TEST 4] Enable/disable functionality");

        enable = 0;
        #(CLK_PERIOD * 100);

        if (carrier1 == MIN_CARRIER1 && carrier2 == 0) begin
            $display("  PASS: Carriers reset to initial values when disabled");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: Carriers not reset (carrier1=%0d, carrier2=%0d)", carrier1, carrier2);
            test_fail_count = test_fail_count + 1;
        end

        // Re-enable and verify operation resumes
        enable = 1;
        #(CLK_PERIOD * (freq_div + 1) * 10);

        if (carrier1 != MIN_CARRIER1 || carrier2 != 0) begin
            $display("  PASS: Carrier generation resumed after re-enable");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: Carriers not updating after re-enable");
            test_fail_count = test_fail_count + 1;
        end

        //----------------------------------------------------------------------
        // Test 5: Frequency Divider
        //----------------------------------------------------------------------
        $display("\n[TEST 5] Frequency divider operation");

        // Test with different freq_div values
        enable = 0;
        freq_div = 16'd100;
        #(CLK_PERIOD * 20);

        enable = 1;
        #(CLK_PERIOD * 10);  // Let it stabilize

        update_count = 0;
        sample1 = carrier1;

        for (i = 0; i < 1200; i = i + 1) begin
            #CLK_PERIOD;
            if (carrier1 != sample1) begin
                update_count = update_count + 1;
                sample1 = carrier1;
            end
        end

        // Should get approximately 1200 / (freq_div + 1) = ~12 updates
        if (update_count >= 10 && update_count <= 14) begin
            $display("  PASS: Frequency divider working (updates=%0d, expected~12)", update_count);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: Frequency divider not working (updates=%0d, expected~12)", update_count);
            test_fail_count = test_fail_count + 1;
        end

        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        #1000;
        $display("\n========================================");
        $display("Carrier Generator Test Summary");
        $display("========================================");
        $display("  PASSED: %0d", test_pass_count);
        $display("  FAILED: %0d", test_fail_count);
        $display("========================================");

        if (test_fail_count == 0) begin
            $display("✓ ALL TESTS PASSED!");
        end else begin
            $display("✗ SOME TESTS FAILED!");
        end
        $display("========================================");

        $finish;
    end

    //==========================================================================
    // Monitor
    //==========================================================================

    initial begin
        // Timeout watchdog
        #50_000_000;  // 50ms
        $display("\nERROR: Testbench timeout!");
        $display("========================================");
        $display("✗ TESTBENCH TIMEOUT!");
        $display("========================================");
        $finish;
    end

endmodule
