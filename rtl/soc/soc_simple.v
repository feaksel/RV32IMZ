/**
 * @file soc_simple.v
 * @brief Simplified RV32IM SoC for Academic Synthesis
 *
 * This is a simplified version of soc_top.v that:
 * - Uses standard memory modules (not SKY130 macros)
 * - Includes only essential peripherals
 * - Focuses on synthesizable academic design
 * - Perfect for homework/university projects
 *
 * @author Custom RISC-V Core Team
 * @date 2025-12-15
 * @version 1.0 - Academic Synthesis Version
 */

module soc_simple #(
    parameter CLK_FREQ = 50_000_000,   // 50 MHz system clock
    parameter UART_BAUD = 115200       // UART baud rate
)(
    // Clock and Reset
    input  wire        clk_100mhz,     // 100 MHz input clock
    input  wire        rst_n,          // Active-low reset

    // UART
    input  wire        uart_rx,
    output wire        uart_tx,

    // GPIO (simplified to 8 bits)
    inout  wire [7:0]  gpio,

    // Status LEDs
    output wire [3:0]  led
);

    //==========================================================================
    // Clock Generation (Simple)
    //==========================================================================

    // Generate 50 MHz from 100 MHz
    reg clk_50mhz;
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            clk_50mhz <= 1'b0;
        end else begin
            clk_50mhz <= ~clk_50mhz;
        end
    end

    wire clk = clk_50mhz;  // System clock

    //==========================================================================
    // Reset Synchronization
    //==========================================================================

    reg [2:0] rst_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rst_sync <= 3'b000;
        else
            rst_sync <= {rst_sync[1:0], 1'b1};
    end

    wire rst_n_sync = rst_sync[2];

    //==========================================================================
    // CPU Wishbone Interfaces
    //==========================================================================
    
    wire [31:0] cpu_ibus_addr;
    wire [31:0] cpu_ibus_dat_i;
    wire        cpu_ibus_stb;
    wire        cpu_ibus_cyc;
    wire        cpu_ibus_ack;

    wire [31:0] cpu_dbus_addr;
    wire [31:0] cpu_dbus_dat_o;
    wire [31:0] cpu_dbus_dat_i;
    wire        cpu_dbus_we;
    wire [3:0]  cpu_dbus_sel;
    wire        cpu_dbus_stb;
    wire        cpu_dbus_cyc;
    wire        cpu_dbus_ack;
    wire        cpu_dbus_err;

    wire [31:0] cpu_interrupts = 32'h0; // No interrupts for simple version

    //==========================================================================
    // CPU Core
    //==========================================================================
    
    custom_core_wrapper cpu (
        .clk(clk),
        .rst_n(rst_n_sync),

        // Instruction bus
        .ibus_addr(cpu_ibus_addr),
        .ibus_dat_i(cpu_ibus_dat_i),
        .ibus_cyc(cpu_ibus_cyc),
        .ibus_stb(cpu_ibus_stb),
        .ibus_ack(cpu_ibus_ack),

        // Data bus
        .dbus_addr(cpu_dbus_addr),
        .dbus_dat_o(cpu_dbus_dat_o),
        .dbus_dat_i(cpu_dbus_dat_i),
        .dbus_we(cpu_dbus_we),
        .dbus_sel(cpu_dbus_sel),
        .dbus_cyc(cpu_dbus_cyc),
        .dbus_stb(cpu_dbus_stb),
        .dbus_ack(cpu_dbus_ack),
        .dbus_err(cpu_dbus_err),

        // Interrupts
        .external_interrupt(cpu_interrupts)
    );

    //==========================================================================
    // Memory System
    //==========================================================================

    // ROM (32KB at 0x00000000-0x00007FFF)
    wire [31:0] rom_wb_dat_o;
    wire        rom_wb_ack;

    rom_32kb #(
        .MEM_FILE("firmware/firmware.hex")
    ) rom_inst (
        .clk(clk),
        .rst_n(rst_n_sync),
        .addr(cpu_ibus_addr),
        .data_out(rom_wb_dat_o),
        .stb(cpu_ibus_stb & (cpu_ibus_addr[31:15] == 17'h0)), // 0x0000_0000-0x0000_7FFF
        .ack(rom_wb_ack)
    );

    // Connect ROM to instruction bus
    assign cpu_ibus_dat_i = rom_wb_dat_o;
    assign cpu_ibus_ack = rom_wb_ack;

    // RAM (64KB at 0x10000000-0x1000FFFF)  
    wire [31:0] ram_wb_dat_o;
    wire        ram_wb_ack;

    ram_64kb ram_inst (
        .clk(clk),
        .rst_n(rst_n_sync),
        .addr(cpu_dbus_addr),
        .data_in(cpu_dbus_dat_o),
        .data_out(ram_wb_dat_o),
        .we(cpu_dbus_we),
        .sel(cpu_dbus_sel),
        .stb(cpu_dbus_stb & (cpu_dbus_addr[31:16] == 16'h1000)), // 0x1000_0000-0x1000_FFFF
        .ack(ram_wb_ack)
    );

    //==========================================================================
    // Peripheral System  
    //==========================================================================

    // UART (at 0x80000000)
    wire [31:0] uart_wb_dat_o;
    wire        uart_wb_ack;

    uart #(
        .CLK_FREQ(CLK_FREQ),
        .DEFAULT_BAUD(UART_BAUD)
    ) uart_inst (
        .clk(clk),
        .rst_n(rst_n_sync),
        
        // Wishbone interface
        .wb_addr(cpu_dbus_addr[7:0]),
        .wb_dat_i(cpu_dbus_dat_o),
        .wb_dat_o(uart_wb_dat_o),
        .wb_we(cpu_dbus_we),
        .wb_sel(cpu_dbus_sel),
        .wb_stb(cpu_dbus_stb & (cpu_dbus_addr[31:8] == 24'h800000)), // 0x8000_0000-0x8000_00FF
        .wb_ack(uart_wb_ack),
        
        // UART interface
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

    // GPIO (at 0x80001000)
    wire [31:0] gpio_wb_dat_o;
    wire        gpio_wb_ack;
    wire [15:0] gpio_in;
    wire [15:0] gpio_out;
    wire [15:0] gpio_oe;

    gpio #(
        .NUM_GPIOS(16)
    ) gpio_inst (
        .clk(clk),
        .rst_n(rst_n_sync),
        
        // Wishbone interface
        .wb_addr(cpu_dbus_addr[7:0]),
        .wb_dat_i(cpu_dbus_dat_o),
        .wb_dat_o(gpio_wb_dat_o),
        .wb_we(cpu_dbus_we),
        .wb_sel(cpu_dbus_sel),
        .wb_stb(cpu_dbus_stb & (cpu_dbus_addr[31:8] == 24'h800010)), // 0x8000_1000-0x8000_10FF
        .wb_ack(gpio_wb_ack),
        
        // GPIO pins
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe)
    );

    // Connect external GPIO (8-bit bidirectional)
    assign gpio = gpio_oe[7:0] ? gpio_out[7:0] : 8'bz;
    assign gpio_in = {{8{1'b0}}, gpio};

    // Timer (at 0x80002000)
    wire [31:0] timer_wb_dat_o;
    wire        timer_wb_ack;
    wire        timer_irq; // Not used in simple version

    timer #(
        .CLK_FREQ(CLK_FREQ)
    ) timer_inst (
        .clk(clk),
        .rst_n(rst_n_sync),
        
        // Wishbone interface
        .wb_addr(cpu_dbus_addr[7:0]),
        .wb_dat_i(cpu_dbus_dat_o),
        .wb_dat_o(timer_wb_dat_o),
        .wb_we(cpu_dbus_we),
        .wb_sel(cpu_dbus_sel),
        .wb_stb(cpu_dbus_stb & (cpu_dbus_addr[31:8] == 24'h800020)), // 0x8000_2000-0x8000_20FF
        .wb_ack(timer_wb_ack),
        
        .irq(timer_irq)
    );

    //==========================================================================
    // Data Bus Multiplexing
    //==========================================================================

    // Simple address decoding and data multiplexing
    reg [31:0] dbus_dat_muxed;
    reg        dbus_ack_muxed;
    reg        dbus_err_muxed;

    always @(*) begin
        // Default values
        dbus_dat_muxed = 32'h0;
        dbus_ack_muxed = 1'b0;
        dbus_err_muxed = 1'b0;

        // Address decoding
        casez (cpu_dbus_addr[31:16])
            16'h1000: begin // RAM
                dbus_dat_muxed = ram_wb_dat_o;
                dbus_ack_muxed = ram_wb_ack;
            end
            16'h8000: begin // Peripherals
                case (cpu_dbus_addr[15:8])
                    8'h00: begin // UART
                        dbus_dat_muxed = uart_wb_dat_o;
                        dbus_ack_muxed = uart_wb_ack;
                    end
                    8'h10: begin // GPIO
                        dbus_dat_muxed = gpio_wb_dat_o;
                        dbus_ack_muxed = gpio_wb_ack;
                    end
                    8'h20: begin // Timer
                        dbus_dat_muxed = timer_wb_dat_o;
                        dbus_ack_muxed = timer_wb_ack;
                    end
                    default: begin
                        dbus_err_muxed = cpu_dbus_stb; // Bus error for unmapped addresses
                    end
                endcase
            end
            default: begin
                dbus_err_muxed = cpu_dbus_stb; // Bus error for unmapped addresses
            end
        endcase
    end

    // Connect to CPU
    assign cpu_dbus_dat_i = dbus_dat_muxed;
    assign cpu_dbus_ack = dbus_ack_muxed;
    assign cpu_dbus_err = dbus_err_muxed;

    //==========================================================================
    // Status and Debug
    //==========================================================================

    // Simple LED status indicators
    assign led[0] = rst_n_sync;           // Power/reset indicator
    assign led[1] = uart_tx;              // UART activity
    assign led[2] = |gpio_out[7:0];       // GPIO activity
    assign led[3] = timer_irq;            // Timer activity

    //==========================================================================
    // Synthesis Attributes
    //==========================================================================

    // synthesis translate_off
    initial begin
        $display("");
        $display("========================================");
        $display("RV32IM Simple SoC for Academic Synthesis");
        $display("========================================");
        $display("Clock frequency: %0d MHz", CLK_FREQ/1_000_000);
        $display("UART baud rate: %0d", UART_BAUD);
        $display("");
        $display("Memory map:");
        $display("  0x0000_0000 - 0x0000_7FFF: ROM (32KB)");
        $display("  0x1000_0000 - 0x1000_FFFF: RAM (64KB)");
        $display("  0x8000_0000 - 0x8000_00FF: UART");
        $display("  0x8000_1000 - 0x8000_10FF: GPIO");
        $display("  0x8000_2000 - 0x8000_20FF: Timer");
        $display("");
        $display("This SoC is optimized for academic synthesis:");
        $display("  - No complex memory macros");
        $display("  - Standard peripheral interfaces");
        $display("  - Clean synthesizable code");
        $display("  - Educational memory map");
        $display("========================================");
        $display("");
    end
    // synthesis translate_on

endmodule