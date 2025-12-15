`timescale 1ns/1ps

// Simple standalone UART test
module test_uart_simple;

reg clk, rst_n;
reg [7:0] wb_addr;
reg [31:0] wb_dat_i;
wire [31:0] wb_dat_o;
reg wb_we;
reg [3:0] wb_sel;
reg wb_stb;
wire wb_ack;
wire uart_tx;
wire irq;

// Instantiate UART
uart #(
    .ADDR_WIDTH(8),
    .CLK_FREQ(50_000_000),
    .DEFAULT_BAUD(115200)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .wb_addr(wb_addr),
    .wb_dat_i(wb_dat_i),
    .wb_dat_o(wb_dat_o),
    .wb_we(wb_we),
    .wb_sel(wb_sel),
    .wb_stb(wb_stb),
    .wb_ack(wb_ack),
    .uart_rx(1'b1),
    .uart_tx(uart_tx),
    .irq(irq)
);

// Clock
initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50 MHz
end

// Test
initial begin
    $dumpfile("test_uart_simple.vcd");
    $dumpvars(0, test_uart_simple);

    // Reset
    rst_n = 0;
    wb_addr = 0;
    wb_dat_i = 0;
    wb_we = 0;
    wb_sel = 4'hF;
    wb_stb = 0;
    #100;
    rst_n = 1;
    #100;

    $display("=== Writing 0x48 ('H') to UART ===");
    // Write data
    @(posedge clk);
    wb_addr = 8'h00;  // DATA register
    wb_dat_i = 32'h00000048;  // 'H'
    wb_we = 1'b1;
    wb_stb = 1'b1;

    // Wait for ack
    @(posedge clk);
    while (!wb_ack) @(posedge clk);

    // Deassert
    wb_stb = 1'b0;
    wb_we = 1'b0;

    // Wait for transmission to complete
    #200000;

    $display("=== Test complete ===");
    $finish;
end

endmodule
