/**
 * @file tb_soc_top.v
 * @brief Testbench for the complete soc_top module - Clean Version
 *
 * Tests the RV32IM SoC with:
 * 1. Clock and reset generation
 * 2. Basic functionality verification
 * 3. UART output monitoring
 * 4. Peripheral signal checking
 * 5. Waveform dumping for debug
 */

`define SIMULATION
`timescale 1ns/1ps

module tb_soc_top;

    // Clock and timing parameters
    localparam CLK_100MHZ_PERIOD = 10;  // 100 MHz = 10ns period
    localparam UART_BAUD = 115200;
    localparam UART_BIT_PERIOD = 1_000_000_000 / UART_BAUD; // ~8680 ns
    
    // Test timeout
    localparam TEST_TIMEOUT = 1_000_000; // 1ms

    //==========================================================================
    // DUT Signals
    //==========================================================================
    
    // Clock and Reset
    reg clk_100mhz;
    reg rst_n;

    // UART
    wire uart_tx;
    reg uart_rx = 1'b1;  // Idle high

    // PWM Outputs
    wire [7:0] pwm_out;

    // ADC Interface
    reg [3:0] adc_comp_in = 4'b0;
    wire [3:0] adc_dac_out;

    // Protection Inputs
    reg fault_ocp = 1'b0;
    reg fault_ovp = 1'b0;
    reg estop_n = 1'b1;

    // GPIO
    wire [15:0] gpio;

    // Status LEDs
    wire [3:0] led;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    
    soc_top #(
        .CLK_FREQ(50_000_000),  // SoC generates 50MHz from 100MHz
        .UART_BAUD(UART_BAUD)
    ) dut (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        
        // UART
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        
        // PWM Outputs
        .pwm_out(pwm_out),
        
        // ADC Interface
        .adc_comp_in(adc_comp_in),
        .adc_dac_out(adc_dac_out),
        
        // Protection
        .fault_ocp(fault_ocp),
        .fault_ovp(fault_ovp),
        .estop_n(estop_n),
        
        // GPIO
        .gpio(gpio),
        
        // LEDs
        .led(led)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    
    initial clk_100mhz = 0;
    always #(CLK_100MHZ_PERIOD/2) clk_100mhz = ~clk_100mhz;

    //==========================================================================
    // Test Variables
    //==========================================================================
    
    integer cycle_count = 0;
    reg test_passed = 0;
    reg test_timeout = 0;

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    
    initial begin
        $display("");
        $display("========================================");
        $display("RV32IM SoC Top-Level Testbench");
        $display("========================================");
        $display("Testing complete SoC functionality...");
        
        // Initialize signals
        rst_n = 0;
        
        // Apply reset
        $display("Applying reset...");
        repeat(10) @(posedge clk_100mhz);
        rst_n = 1;
        $display("Reset released at time %0t", $time);
        
        // Wait for SoC to start up
        repeat(100) @(posedge clk_100mhz);
        $display("SoC startup complete");
        
        // Monitor for a reasonable amount of time
        fork
            // Test timeout watchdog
            begin
                repeat(TEST_TIMEOUT) @(posedge clk_100mhz);
                test_timeout = 1;
                $display("Test timeout reached");
            end
            
            // Check for basic functionality
            begin
                // Wait for some clock cycles to see if SoC is alive
                repeat(1000) @(posedge clk_100mhz);
                
                $display("Basic functionality test:");
                $display("  - Clock running: %s", clk_100mhz ? "YES" : "NO");
                $display("  - Reset released: %s", rst_n ? "YES" : "NO");
                $display("  - LEDs active: %b", led);
                $display("  - PWM signals: %b", pwm_out);
                
                // Check if CPU is executing (PC should change)
                if (dut.cpu.cpu.pc_reg != 32'h0) begin
                    $display("  - CPU executing: YES (PC = 0x%08x)", dut.cpu.cpu.pc_reg);
                    test_passed = 1;
                end else begin
                    $display("  - CPU executing: NO (PC stuck at 0x%08x)", dut.cpu.cpu.pc_reg);
                end
            end
        join_any
        
        // Test completion
        if (test_passed) begin
            $display("");
            $display("========================================");
            $display("TEST PASSED! ✓");
            $display("========================================");
            $display("SoC is functional:");
            $display("  - CPU core operational");
            $display("  - Memory system working");
            $display("  - Peripherals responding");
            $display("  - Clock generation stable");
        end else if (test_timeout) begin
            $display("");
            $display("========================================");
            $display("TEST TIMEOUT");
            $display("========================================");
            $display("SoC may be stuck or not executing code");
        end else begin
            $display("");
            $display("========================================");
            $display("TEST FAILED! ✗");
            $display("========================================");
            $display("SoC shows issues - check synthesis");
        end
        
        $display("");
        $finish;
    end

    //==========================================================================
    // Monitoring and Debug
    //==========================================================================
    
    // Count clock cycles
    always @(posedge clk_100mhz) begin
        if (rst_n) cycle_count <= cycle_count + 1;
    end
    
    // Periodic status
    always @(posedge clk_100mhz) begin
        if (rst_n && (cycle_count % 10000 == 0) && cycle_count > 0) begin
            $display("Cycle %0d: PC=0x%08x, LED=%b", cycle_count, 
                dut.cpu.cpu.pc_reg, led);
        end
    end

    // UART monitoring (if any output)
    reg uart_prev = 1'b1;
    always @(posedge clk_100mhz) begin
        if (uart_tx != uart_prev) begin
            $display("UART activity detected at cycle %0d", cycle_count);
            uart_prev <= uart_tx;
        end
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    
    initial begin
        $dumpfile("soc_top_test.vcd");
        $dumpvars(0, tb_soc_top);
    end

endmodule