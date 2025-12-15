`timescale 1ns/1ps

// Simple test to verify memory access
module test_simple;

reg clk_100mhz, rst_n;

wire uart_tx;
wire [7:0] pwm_out;
wire [3:0] adc_dac_out;
wire [15:0] gpio;
wire [3:0] led;

soc_top #(
    .CLK_FREQ(50_000_000),
    .UART_BAUD(115200)
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

// Clock
initial begin
    clk_100mhz = 0;
    forever #5 clk_100mhz = ~clk_100mhz;
end

// Reset
initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
end

// Monitor data bus accesses
always @(posedge dut.clk) begin
    if (dut.cpu_dbus_stb && dut.cpu_dbus_ack) begin
        $display("[DBUS] addr=0x%08x we=%b sel=%b dat_o=0x%08x dat_i=0x%08x",
                 dut.cpu_dbus_addr, dut.cpu_dbus_we, dut.cpu_dbus_sel,
                 dut.cpu_dbus_dat_o, dut.cpu_dbus_dat_i);
    end

    if (dut.rom_stb && dut.rom_ack) begin
        $display("[ROM ] addr=0x%05x (word %0d) data=0x%08x",
                 dut.rom_addr, dut.rom_addr[14:2], dut.rom_dat_o);
    end
end

// Finish after a bit
initial begin
    $dumpfile("test_simple.vcd");
    $dumpvars(0, test_simple);
    #100000;
    $display("Test complete");
    $finish;
end

endmodule
