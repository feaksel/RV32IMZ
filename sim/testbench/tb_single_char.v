`timescale 1ns/1ps
`define SIMULATION

// Simple testbench to receive one character from UART
module tb_single_char;

    localparam CLK_100MHZ_PERIOD = 10; // 100 MHz clock
    localparam UART_BAUD = 115200;
    localparam UART_BIT_PERIOD = (1_000_000_000 / UART_BAUD); // ~8680 ns

    reg clk_100mhz;
    reg rst_n;
    wire uart_tx;
    wire [7:0] pwm_out;
    wire [3:0] adc_dac_out;
    wire [15:0] gpio;
    wire [3:0] led;

    // Instantiate the DUT
    soc_top #(
        .CLK_FREQ(50_000_000), // soc_top generates 50MHz from 100MHz
        .UART_BAUD(UART_BAUD)
    ) dut (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        .uart_rx(1'b1),
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
        rst_n = 0;
        #200;
        rst_n = 1;
    end

    // UART receiver
    integer bit_count;
    reg [7:0] byte_received;

    initial begin
        $dumpfile("tb_single_char.vcd");
        $dumpvars(0, tb_single_char);

        $display("========================================");
        $display("INFO: Single Character UART Test");
        $display("INFO: Expecting 'A' (0x41)");
        $display("INFO: UART_BIT_PERIOD = %0d ns", UART_BIT_PERIOD);
        $display("========================================");

        @(posedge rst_n);
        #100;

        // Wait for start bit
        $display("INFO: Waiting for UART start bit...");
        @(negedge uart_tx);
        $display("INFO: Start bit detected at time %0t", $time);

        // Move to center of start bit
        #(UART_BIT_PERIOD / 2);
        if (uart_tx !== 0) begin
            $display("ERROR: Start bit is not 0");
            $finish;
        end
        $display("INFO: Start bit confirmed");

        // Read 8 data bits (LSB first)
        byte_received = 0;
        for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
            #(UART_BIT_PERIOD);
            byte_received[bit_count] = uart_tx;
            $display("INFO: bit[%0d] = %b at time %0t", bit_count, uart_tx, $time);
        end

        $display("========================================");
        $display("INFO: Received byte = 0x%02h (binary: %08b, char: '%c')",
                 byte_received, byte_received, byte_received);
        $display("========================================");

        // Check stop bit
        #(UART_BIT_PERIOD);
        if (uart_tx !== 1) begin
            $display("ERROR: Stop bit is not 1 (value = %b)", uart_tx);
            $finish;
        end
        $display("INFO: Stop bit confirmed");

        // Verify
        if (byte_received == 8'h41) begin
            $display("========================================");
            $display("PASS: Received 'A' (0x41) correctly!");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAIL: Expected 0x41, got 0x%02h", byte_received);
            $display("========================================");
        end

        #10000;
        $finish;
    end

    // Timeout
    initial begin
        #50_000_000; // 50ms timeout
        $display("ERROR: Timeout waiting for UART transmission");
        $finish;
    end

endmodule
