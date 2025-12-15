// tb_soc_top.v
//
// Testbench for the complete soc_top module.
//
// 1. Instantiates the SoC.
// 2. Provides clock and reset.
// 3. Defines `SIMULATION` to enable behavioral memory.
// 4. Monitors the UART TX line for a "Hello World!" message.
// 5. Reports PASS or FAIL based on the UART output.
<<<<<<< HEAD
// 6. Dumps waveforms for debugging.
// 7. Monitors SoC signals (PWM, GPIO, LEDs, etc.)
=======
>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767

`define SIMULATION
`timescale 1ns/1ps

module tb_soc_top;

    // SoC Parameters
    localparam CLK_100MHZ_PERIOD = 10; // 100 MHz clock
    localparam UART_BAUD = 115200;
<<<<<<< HEAD
    localparam UART_BIT_PERIOD = 1_000_000_000 / UART_BAUD; // ~8680 ns
=======
    localparam UART_BIT_PERIOD = 1_000_000_000 / UART_BAUD;
>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767

    // Signals
    reg clk_100mhz;
    reg rst_n;

    wire uart_tx;
    wire [7:0] pwm_out;
    wire [3:0] adc_dac_out;
    wire [15:0] gpio;
    wire [3:0] led;

    // Instantiate the DUT (Design Under Test)
    soc_top #(
        .CLK_FREQ(50_000_000), // soc_top generates 50MHz from 100MHz
        .UART_BAUD(UART_BAUD)
    ) dut (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        .uart_rx(1'b1), // Keep UART RX idle
        .uart_tx(uart_tx),
        .pwm_out(pwm_out),
        .adc_comp_in(4'b0),
        .adc_dac_out(adc_dac_out),
        .fault_ocp(1'b0),
        .fault_ovp(1'b0),
        .estop_n(1'b1),
        .gpio(gpio),
        .led(led)
    );

    // Clock generation
    initial begin
        clk_100mhz = 0;
        forever #(CLK_100MHZ_PERIOD / 2) clk_100mhz = ~clk_100mhz;
    end

    // Reset generation
    initial begin
<<<<<<< HEAD
        $display("========================================");
        $display("INFO: Starting SoC Top Testbench");
        $display("========================================");
        $display("INFO: CLK_100MHZ_PERIOD = %0d ns", CLK_100MHZ_PERIOD);
        $display("INFO: UART_BAUD = %0d", UART_BAUD);
        $display("INFO: UART_BIT_PERIOD = %0d ns", UART_BIT_PERIOD);

        rst_n = 1'b0;
        #200;
        rst_n = 1'b1;
        $display("INFO: Reset released at time %0t", $time);
    end

    // Waveform dumping
    initial begin
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0, tb_soc_top);
        $display("INFO: Waveform dumping enabled (tb_soc_top.vcd)");
    end

    // Monitor SoC signals
    initial begin
        @(posedge rst_n);
        $display("========================================");
        $display("INFO: Monitoring SoC Signals");
        $display("========================================");

        // Monitor for a while to show initial state
        #1000;
        $display("INFO: Initial LED state = 4'b%b", led);
        $display("INFO: Initial PWM state = 8'b%b", pwm_out);
=======
        $display("INFO: Starting testbench for soc_top.");
        rst_n = 1'b0;
        #200;
        rst_n = 1'b1;
        $display("INFO: Reset released.");
>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767
    end

    // Test monitoring and UART receiver
    initial begin
<<<<<<< HEAD
        // Expected message: "Hello World!\n" (13 characters)
        reg [7:0] expected_msg [0:12];
        integer byte_count;
        integer bit_count;
        integer i;
        reg [7:0] byte_received;

        // Initialize expected message
        expected_msg[0]  = 8'h48; // 'H'
        expected_msg[1]  = 8'h65; // 'e'
        expected_msg[2]  = 8'h6C; // 'l'
        expected_msg[3]  = 8'h6C; // 'l'
        expected_msg[4]  = 8'h6F; // 'o'
        expected_msg[5]  = 8'h20; // ' '
        expected_msg[6]  = 8'h57; // 'W'
        expected_msg[7]  = 8'h6F; // 'o'
        expected_msg[8]  = 8'h72; // 'r'
        expected_msg[9]  = 8'h6C; // 'l'
        expected_msg[10] = 8'h64; // 'd'
        expected_msg[11] = 8'h21; // '!'
        expected_msg[12] = 8'h0A; // '\n'

        byte_count = 0;

        // Wait for reset to be released
        @(posedge rst_n);
        #100; // Small delay after reset

        $display("========================================");
        $display("INFO: Waiting for UART transmission...");
        $display("========================================");

        // Process all 13 characters
        for (byte_count = 0; byte_count < 13; byte_count = byte_count + 1) begin
            // Wait for the start bit (falling edge of uart_tx)
            // Note: For byte 0, we wait here. For subsequent bytes,
            // we already waited at the end of the previous iteration.
            if (byte_count == 0) begin
                @(negedge uart_tx);
            end
            $display("INFO: UART Start bit detected for byte %0d at time %0t", byte_count, $time);

            // Move to center of start bit
            #(UART_BIT_PERIOD / 2);

            if (uart_tx !== 0) begin
                $display("ERROR: Start bit is not 0 at time %0t", $time);
                $display("FAIL: UART framing error on byte %0d", byte_count);
                $finish;
            end

            // Read 8 data bits (LSB first)
            byte_received = 0;
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                #(UART_BIT_PERIOD); // Move to next bit center
                byte_received[bit_count] = uart_tx;
            end

            // Check stop bit
            #(UART_BIT_PERIOD); // Move to stop bit center
            if (uart_tx !== 1) begin
                $display("ERROR: Stop bit is not 1 at time %0t (value = %b)", $time, uart_tx);
                $display("FAIL: UART stop bit not found on byte %0d!", byte_count);
=======
        string expected_string = "Hello World!\n";
        integer byte_count = 0;
        integer bit_count;
        reg [7:0] byte_received;

        // Wait for reset to be released
        @(posedge rst_n);

        $display("INFO: Waiting for UART transmission...");

        // Wait for the start bit
        wait (uart_tx == 0);
        $display("INFO: UART Start bit detected.");

        while (byte_count < expected_string.len()) begin
            // Center of start bit
            #(UART_BIT_PERIOD);

            // Read 8 data bits
            byte_received = 0;
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                byte_received = {uart_tx, byte_received[7:1]};
                #(UART_BIT_PERIOD);
            end

            // Check stop bit
            if (uart_tx != 1) begin
                $error("FAIL: UART stop bit not found!");
>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767
                $finish;
            end

            // Check received character
<<<<<<< HEAD
            if (byte_received == expected_msg[byte_count]) begin
                if (byte_received >= 32 && byte_received < 127)
                    $display("INFO: [%02d] Received 0x%02h '%c' - OK",
                             byte_count, byte_received, byte_received);
                else
                    $display("INFO: [%02d] Received 0x%02h - OK",
                             byte_count, byte_received);
            end else begin
                if (byte_received >= 32 && byte_received < 127)
                    $display("ERROR: [%02d] Received 0x%02h '%c', expected 0x%02h '%c'",
                             byte_count, byte_received, byte_received,
                             expected_msg[byte_count], expected_msg[byte_count]);
                else
                    $display("ERROR: [%02d] Received 0x%02h, expected 0x%02h",
                             byte_count, byte_received, expected_msg[byte_count]);
                $display("FAIL: UART data mismatch!");
                $finish;
            end

            // Wait for next start bit if not the last character
            if (byte_count < 12) begin
                // Move to end of stop bit, then wait for next start bit
                #(UART_BIT_PERIOD / 2);
                @(negedge uart_tx);
            end
        end

        // Success!
        #1000; // Small delay before finishing
        $display("========================================");
        $display("PASS: Successfully received 'Hello World!' via UART");
        $display("========================================");
        $display("INFO: Total simulation time: %0t", $time);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10_000_000; // 10ms timeout
        $display("========================================");
        $display("ERROR: Test timed out after 10ms");
        $display("FAIL: No complete UART message received");
        $display("========================================");
        $finish;
    end

    // Optional: Monitor PWM activity
    reg [7:0] pwm_prev;
    initial begin
        pwm_prev = 8'h00;
        @(posedge rst_n);
        forever begin
            @(pwm_out);
            if (pwm_out !== pwm_prev) begin
                $display("INFO: PWM changed: 8'b%b -> 8'b%b at time %0t",
                         pwm_prev, pwm_out, $time);
                pwm_prev = pwm_out;
            end
        end
    end

    // Optional: Monitor LED changes
    reg [3:0] led_prev;
    initial begin
        led_prev = 4'h0;
        @(posedge rst_n);
        #10; // Small delay to get initial state
        led_prev = led;
        forever begin
            @(led);
            if (led !== led_prev) begin
                $display("INFO: LED changed: 4'b%b -> 4'b%b at time %0t",
                         led_prev, led, $time);
                led_prev = led;
            end
        end
    end

=======
            if (byte_received == expected_string[byte_count]) begin
                $display("INFO: Received char '%s' (0x%02h), matches expected '%s'.", byte_received, byte_received, expected_string[byte_count]);
            end else begin
                $error("FAIL: Received char '%s' (0x%02h), expected '%s'.", byte_received, byte_received, expected_string[byte_count]);
                $finish;
            end

            byte_count = byte_count + 1;
        end

        $display("----------------------------------------");
        $display("PASS: Successfully received 'Hello World!'.");
        $display("----------------------------------------");
        $finish;

    end

    // Timeout
    initial begin
        #5000000; // 5ms timeout
        $error("FAIL: Test timed out. No UART message received.");
        $finish;
    end

>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767
endmodule
