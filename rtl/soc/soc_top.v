/**
 * @file soc_top.v
 * @brief Top-level RISC-V SoC for 5-Level Inverter Control (Custom Core)
 *
 * Integrates all components of the RISC-V-based inverter control system:
 * - Custom RV32IM CPU core with Zpec extension
 * - 32 KB ROM (firmware storage)
 * - 64 KB RAM (runtime data)
 * - PWM accelerator peripheral (8 channels with dead-time)
 * - Sigma-Delta ADC peripheral (4-channel integrated)
 * - Protection/fault peripheral (OCP, OVP, E-stop, watchdog)
 * - Timer peripheral
 * - GPIO peripheral (32 pins)
 * - UART peripheral (debug/communication)
 * - Wishbone bus interconnect
 *
 * Target: Digilent Basys 3 (Xilinx Artix-7 XC7A35T)
 * Clock: 50 MHz (from 100 MHz oscillator with divider)
 * ASIC-ready: Technology-independent design
 *
 * This SoC is designed for DROP-IN replacement of VexRiscv.
 * Simply implement custom_riscv_core.v and custom_core_wrapper.v
 * to match the interface, and everything else works!
 *
 * @author Custom RISC-V Core Team
 * @date 2025-12-03
 * @version 1.0 - Adapted from VexRiscv SoC for custom core
 */

module soc_top #(
    parameter CLK_FREQ = 50_000_000,   // 50 MHz system clock
    parameter UART_BAUD = 115200       // UART baud rate
)(
    // Clock and Reset
    input  wire        clk_100mhz,     // Basys 3 100 MHz oscillator
    input  wire        rst_n,          // Active-low reset button

    // UART
    input  wire        uart_rx,
    output wire        uart_tx,

    // PWM Outputs (to H-bridge gate drivers)
    output wire [7:0]  pwm_out,

    // Sigma-Delta ADC Interface (4 channels)
    // Comparator inputs from LM339 (external quad comparator)
    input  wire [3:0]  adc_comp_in,    // Comparator inputs (1-bit per channel)
    // DAC outputs to RC filters (1-bit per channel)
    output wire [3:0]  adc_dac_out,

    // Protection Inputs
    input  wire        fault_ocp,      // Overcurrent protection
    input  wire        fault_ovp,      // Overvoltage protection
    input  wire        estop_n,        // Emergency stop (active low)

    // GPIO (LEDs, switches, debug)
    inout  wire [15:0] gpio,

    // Debug/Status LEDs
    output wire [3:0]  led             // Status indicators
);

    //==========================================================================
    // Clock Generation
    //==========================================================================

    /**
     * Generate 50 MHz system clock from 100 MHz Basys 3 oscillator.
     * For FPGA: Use PLL/MMCM for better jitter performance.
     * For ASIC: Replace with PLL or use external 50 MHz clock.
     */

    reg clk_50mhz;

    // Simple divide-by-2: toggle clk_50mhz every clk_100mhz edge
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
    // CPU (Custom RISC-V Core)
    //==========================================================================
    wire [31:0] cpu_ibus_addr;
    wire [31:0] cpu_ibus_dat_o; // Not used, CPU ibus is read-only
    wire [31:0] cpu_ibus_dat_i;
    wire        cpu_ibus_we;    // Tied low
    wire [3:0]  cpu_ibus_sel;   // Tied high
    wire        cpu_ibus_stb;
    wire        cpu_ibus_cyc;
    wire        cpu_ibus_ack;
    wire        cpu_ibus_err;

    wire [31:0] cpu_dbus_addr;
    wire [31:0] cpu_dbus_dat_o;
    wire [31:0] cpu_dbus_dat_i;
    wire        cpu_dbus_we;
    wire [3:0]  cpu_dbus_sel;
    wire        cpu_dbus_stb;
    wire        cpu_dbus_cyc;
    wire        cpu_dbus_ack;
    wire        cpu_dbus_err;

    wire [31:0] cpu_interrupts;

<<<<<<< HEAD
    // Tie off unused instruction bus signals (ibus is read-only)
    assign cpu_ibus_we = 1'b0;
    assign cpu_ibus_sel = 4'hF;
    assign cpu_ibus_dat_o = 32'h0;  // Not used
    assign cpu_ibus_err = 1'b0;      // Not supported by wrapper
=======
    assign cpu_ibus_we = 1'b0;
    assign cpu_ibus_sel = 4'hF;
>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767

    custom_core_wrapper cpu (
        .clk(clk),
        .rst_n(rst_n_sync),

        // Instruction bus (Wishbone) - Read-only
        .ibus_addr(cpu_ibus_addr),
<<<<<<< HEAD
        .ibus_dat_i(cpu_ibus_dat_i),
        .ibus_stb(cpu_ibus_stb),
        .ibus_cyc(cpu_ibus_cyc),
        .ibus_ack(cpu_ibus_ack),
=======
        .ibus_dat_o(cpu_ibus_dat_o),
        .ibus_dat_i(cpu_ibus_dat_i),
        .ibus_we(cpu_ibus_we),
        .ibus_sel(cpu_ibus_sel),
        .ibus_stb(cpu_ibus_stb),
        .ibus_cyc(cpu_ibus_cyc),
        .ibus_ack(cpu_ibus_ack),
        .ibus_err(cpu_ibus_err),
>>>>>>> 014932e0bf99694e514378b62e54c0b8b3600767

        // Data bus (Wishbone)
        .dbus_addr(cpu_dbus_addr),
        .dbus_dat_o(cpu_dbus_dat_o),
        .dbus_dat_i(cpu_dbus_dat_i),
        .dbus_we(cpu_dbus_we),
        .dbus_sel(cpu_dbus_sel),
        .dbus_stb(cpu_dbus_stb),
        .dbus_cyc(cpu_dbus_cyc),
        .dbus_ack(cpu_dbus_ack),
        .dbus_err(cpu_dbus_err),

        // Interrupts
        .external_interrupt(cpu_interrupts)
    );

    //==========================================================================
    // Wishbone Arbiter (2-to-1)
    //==========================================================================
    wire [31:0] arbiter_m_wb_addr;
    wire [31:0] arbiter_m_wb_dat_o;
    wire [31:0] arbiter_m_wb_dat_i;
    wire        arbiter_m_wb_we;
    wire [3:0]  arbiter_m_wb_sel;
    wire        arbiter_m_wb_stb;
    wire        arbiter_m_wb_cyc;
    wire        arbiter_m_wb_ack;
    wire        arbiter_m_wb_err;

    wishbone_arbiter_2x1 arbiter (
        .clk(clk),
        .rst_n(rst_n_sync),

        // Slave 0: CPU Instruction Bus (High Priority)
        .s0_wb_addr(cpu_ibus_addr),
        .s0_wb_dat_i(cpu_ibus_dat_o),
        .s0_wb_dat_o(cpu_ibus_dat_i),
        .s0_wb_we(cpu_ibus_we),
        .s0_wb_sel(cpu_ibus_sel),
        .s0_wb_stb(cpu_ibus_stb),
        .s0_wb_cyc(cpu_ibus_cyc),
        .s0_wb_ack(cpu_ibus_ack),
        .s0_wb_err(cpu_ibus_err),

        // Slave 1: CPU Data Bus (Low Priority)
        .s1_wb_addr(cpu_dbus_addr),
        .s1_wb_dat_i(cpu_dbus_dat_o),
        .s1_wb_dat_o(cpu_dbus_dat_i),
        .s1_wb_we(cpu_dbus_we),
        .s1_wb_sel(cpu_dbus_sel),
        .s1_wb_stb(cpu_dbus_stb),
        .s1_wb_cyc(cpu_dbus_cyc),
        .s1_wb_ack(cpu_dbus_ack),
        .s1_wb_err(cpu_dbus_err),

        // Master: To Bus Interconnect
        .m_wb_addr(arbiter_m_wb_addr),
        .m_wb_dat_o(arbiter_m_wb_dat_o),
        .m_wb_dat_i(arbiter_m_wb_dat_i),
        .m_wb_we(arbiter_m_wb_we),
        .m_wb_sel(arbiter_m_wb_sel),
        .m_wb_stb(arbiter_m_wb_stb),
        .m_wb_cyc(arbiter_m_wb_cyc),
        .m_wb_ack(arbiter_m_wb_ack),
        .m_wb_err(arbiter_m_wb_err)
    );

    //==========================================================================
    // Memory Subsystem
    //==========================================================================
    // Slaves from interconnect
    wire [14:0] rom_addr;
    wire        rom_stb;
    wire [31:0] rom_dat_o;
    wire        rom_ack;

    wire [15:0] ram_addr;
    wire [31:0] ram_dat_i;
    wire [31:0] ram_dat_o;
    wire        ram_we;
    wire [3:0]  ram_sel;
    wire        ram_stb;
    wire        ram_ack;

`ifdef SIMULATION
    //--------------------------------------------------------------------------
    // Behavioral Memory for Simulation
    //--------------------------------------------------------------------------
    // 32 KB ROM
    reg [31:0] rom_mem [0:8191]; // 8192 entries * 4 bytes = 32 KB
    assign rom_dat_o = rom_mem[rom_addr[14:2]];
    assign rom_ack = rom_stb; // Combinatorial read

    initial begin
        $display("SIMULATION: Loading behavioral ROM from firmware/firmware.hex");
        $readmemh("firmware/firmware.hex", rom_mem);
    end

    // 64 KB RAM
    reg [31:0] ram_mem [0:16383]; // 16384 entries * 4 bytes = 64 KB
    reg [31:0] ram_read_data;
    assign ram_dat_o = ram_read_data;
    reg ram_ack_reg;
    assign ram_ack = ram_ack_reg;

    always @(posedge clk) begin
        ram_ack_reg <= ram_stb;
        if (ram_stb) begin
            if (ram_we) begin
                if (ram_sel[0]) ram_mem[ram_addr[15:2]][7:0]   <= ram_dat_i[7:0];
                if (ram_sel[1]) ram_mem[ram_addr[15:2]][15:8]  <= ram_dat_i[15:8];
                if (ram_sel[2]) ram_mem[ram_addr[15:2]][23:16] <= ram_dat_i[23:16];
                if (ram_sel[3]) ram_mem[ram_addr[15:2]][31:24] <= ram_dat_i[31:24];
            end
            ram_read_data <= ram_mem[ram_addr[15:2]];
        end
    end

`else // SYNTHESIS
    //--------------------------------------------------------------------------
    // Synthesizable SRAM Macros for SKY130 PDK
    //--------------------------------------------------------------------------
    // This implementation creates a 32KB ROM and a 64KB RAM by banking
    // multiple instances of the sky130_sram_2kbyte_1rw1r_32x512_8 macro.
    // This is a standard technique for building larger memories.

    // --- 32KB ROM Generation (16 x 2KB macros) ---
    localparam ROM_NUM_MACROS = 16;
    wire [31:0] rom_data_from_macros [0:ROM_NUM_MACROS-1];
    reg  [31:0] rom_data_muxed;

    genvar i;
    generate
        for (i = 0; i < ROM_NUM_MACROS; i = i + 1) begin : rom_bank
            sky130_sram_2kbyte_1rw1r_32x512_8 sram_rom (
                .VPWR(1'b1), .VGND(1'b0), .vpb(1'b1), .vnb(1'b0), // Power
                // Port 0 (Unused, tied off for ROM)
                .clk0(clk),
                .csb0(1'b1),
                .web0(1'b1),
                .wmask0(4'h0),
                .addr0(9'h0),
                .din0(32'h0),
                .dout0(), // Unconnected
                // Port 1 (Read-only port)
                .clk1(clk),
                .csb1(!(rom_stb && (rom_addr[14:11] == i[3:0]))), // Chip select for this macro
                .addr1(rom_addr[10:2]), // 9-bit address for 512 entries
                .dout1(rom_data_from_macros[i])
            );
        end
    endgenerate

    // Mux the outputs from the ROM macros
    always @(*) begin
        casex (rom_addr[14:11])
            4'd0:    rom_data_muxed = rom_data_from_macros[0];
            4'd1:    rom_data_muxed = rom_data_from_macros[1];
            4'd2:    rom_data_muxed = rom_data_from_macros[2];
            4'd3:    rom_data_muxed = rom_data_from_macros[3];
            4'd4:    rom_data_muxed = rom_data_from_macros[4];
            4'd5:    rom_data_muxed = rom_data_from_macros[5];
            4'd6:    rom_data_muxed = rom_data_from_macros[6];
            4'd7:    rom_data_muxed = rom_data_from_macros[7];
            4'd8:    rom_data_muxed = rom_data_from_macros[8];
            4'd9:    rom_data_muxed = rom_data_from_macros[9];
            4'd10:   rom_data_muxed = rom_data_from_macros[10];
            4'd11:   rom_data_muxed = rom_data_from_macros[11];
            4'd12:   rom_data_muxed = rom_data_from_macros[12];
            4'd13:   rom_data_muxed = rom_data_from_macros[13];
            4'd14:   rom_data_muxed = rom_data_from_macros[14];
            4'd15:   rom_data_muxed = rom_data_from_macros[15];
            default: rom_data_muxed = 32'h0;
        endcase
    end
    assign rom_dat_o = rom_data_muxed;
    assign rom_ack = rom_stb; // Assume 1-cycle latency


    // --- 64KB RAM Generation (32 x 2KB macros) ---
    localparam RAM_NUM_MACROS = 32;
    wire [31:0] ram_data_from_macros [0:RAM_NUM_MACROS-1];
    reg  [31:0] ram_data_muxed;
    reg         ram_ack_reg;

    generate
        for (i = 0; i < RAM_NUM_MACROS; i = i + 1) begin : ram_bank
            sky130_sram_2kbyte_1rw1r_32x512_8 sram_ram (
                .VPWR(1'b1), .VGND(1'b0), .vpb(1'b1), .vnb(1'b0), // Power
                // Port 0 (Read/Write Port)
                .clk0(clk),
                .csb0(!(ram_stb && (ram_addr[15:11] == i[4:0]))), // Chip select
                .web0(!ram_we),
                .wmask0(!ram_sel),
                .addr0(ram_addr[10:2]),
                .din0(ram_dat_i),
                .dout0(ram_data_from_macros[i]),
                // Port 1 (Unused Read-only port, tied off)
                .clk1(clk),
                .csb1(1'b1),
                .addr1(9'h0),
                .dout1()
            );
        end
    endgenerate

    // Mux the outputs from the RAM macros
    always @(*) begin
        casex (ram_addr[15:11])
             5'd0: ram_data_muxed = ram_data_from_macros[0];
             5'd1: ram_data_muxed = ram_data_from_macros[1];
             5'd2: ram_data_muxed = ram_data_from_macros[2];
             5_d3: ram_data_muxed = ram_data_from_macros[3];
             5_d4: ram_data_muxed = ram_data_from_macros[4];
             5'd5: ram_data_muxed = ram_data_from_macros[5];
             5'd6: ram_data_muxed = ram_data_from_macros[6];
             5'd7: ram_data_muxed = ram_data_from_macros[7];
             5'd8: ram_data_muxed = ram_data_from_macros[8];
             5'd9: ram_data_muxed = ram_data_from_macros[9];
             5'd10: ram_data_muxed = ram_data_from_macros[10];
             5'd11: ram_data_muxed = ram_data_from_macros[11];
             5'd12: ram_data_muxed = ram_data_from_macros[12];
             5'd13: ram_data_muxed = ram_data_from_macros[13];
             14: ram_data_muxed = ram_data_from_macros[14];
             15: ram_data_muxed = ram_data_from_macros[15];
             16: ram_data_muxed = ram_data_from_macros[16];
             17: ram_data_muxed = ram_data_from_macros[17];
             18: ram_data_muxed = ram_data_from_macros[18];
             19: ram_data_muxed = ram_data_from_macros[19];
             20: ram_data_muxed = ram_data_from_macros[20];
             21: ram_data_muxed = ram_data_from_macros[21];
             22: ram_data_muxed = ram_data_from_macros[22];
             23: ram_data_muxed = ram_data_from_macros[23];
             24: ram_data_muxed = ram_data_from_macros[24];
             25: ram_data_muxed = ram_data_from_macros[25];
             26: ram_data_muxed = ram_data_from_macros[26];
             27: ram_data_muxed = ram_data_from_macros[27];
             28: ram_data_muxed = ram_data_from_macros[28];
             29: ram_data_muxed = ram_data_from_macros[29];
             30: ram_data_muxed = ram_data_from_macros[30];
             31: ram_data_muxed = ram_data_from_macros[31];
            default: ram_data_muxed = 32'h0;
        endcase
    end
    assign ram_dat_o = ram_data_muxed;

    // The SRAM macro has a 1-cycle read latency.
    always @(posedge clk) begin
        ram_ack_reg <= ram_stb;
    end
    assign ram_ack = ram_ack_reg;

`endif

    //==========================================================================
    // Peripherals: PWM Accelerator
    //==========================================================================

    wire [7:0]  pwm_addr;
    wire [31:0] pwm_dat_i;
    wire [31:0] pwm_dat_o;
    wire        pwm_we;
    wire [3:0]  pwm_sel;
    wire        pwm_stb;
    wire        pwm_ack;
    wire        pwm_disable;

    pwm_accelerator #(
        .CLK_FREQ(CLK_FREQ)
    ) pwm_periph (
        .clk(clk),
        .rst_n(rst_n_sync),
        .wb_addr(pwm_addr),
        .wb_dat_i(pwm_dat_i),
        .wb_dat_o(pwm_dat_o),
        .wb_we(pwm_we),
        .wb_sel(pwm_sel),
        .wb_stb(pwm_stb),
        .wb_ack(pwm_ack),
        .pwm_out(pwm_out),
        .fault(pwm_disable)
    );

    //==========================================================================
    // Peripherals: Sigma-Delta ADC (4-Channel)
    //==========================================================================

    wire [7:0]  adc_addr;
    wire [31:0] adc_dat_i;
    wire [31:0] adc_dat_o;
    wire        adc_we;
    wire [3:0]  adc_sel;
    wire        adc_stb;
    wire        adc_ack;
    wire        adc_irq;

    sigma_delta_adc #(
        .CLK_FREQ(CLK_FREQ),
        .OSR(100),              // 100× oversampling (1 MHz → 10 kHz)
        .CIC_ORDER(3)           // 3rd-order CIC filter
    ) adc_periph (
        .clk(clk),
        .rst_n(rst_n_sync),
        .wb_addr(adc_addr),
        .wb_dat_i(adc_dat_i),
        .wb_dat_o(adc_dat_o),
        .wb_we(adc_we),
        .wb_sel(adc_sel),
        .wb_stb(adc_stb),
        .wb_ack(adc_ack),
        .comp_in(adc_comp_in),     // External comparator inputs
        .dac_out(adc_dac_out),     // 1-bit DAC outputs
        .irq(adc_irq)
    );

    //==========================================================================
    // Peripherals: Protection/Fault
    //==========================================================================

    wire [7:0]  prot_addr;
    wire [31:0] prot_dat_i;
    wire [31:0] prot_dat_o;
    wire        prot_we;
    wire [3:0]  prot_sel;
    wire        prot_stb;
    wire        prot_ack;
    wire        prot_irq;

    protection prot_periph (
        .clk(clk),
        .rst_n(rst_n_sync),
        .wb_addr(prot_addr),
        .wb_dat_i(prot_dat_i),
        .wb_dat_o(prot_dat_o),
        .wb_we(prot_we),
        .wb_sel(prot_sel),
        .wb_stb(prot_stb),
        .wb_ack(prot_ack),
        .fault_ocp(fault_ocp),
        .fault_ovp(fault_ovp),
        .estop_n(estop_n),
        .pwm_disable(pwm_disable),
        .irq(prot_irq)
    );

    //==========================================================================
    // Peripherals: Timer
    //==========================================================================

    wire [7:0]  timer_addr;
    wire [31:0] timer_dat_i;
    wire [31:0] timer_dat_o;
    wire        timer_we;
    wire [3:0]  timer_sel;
    wire        timer_stb;
    wire        timer_ack;
    wire        timer_irq;

    timer #(
        .CLK_FREQ(CLK_FREQ)
    ) timer_periph (
        .clk(clk),
        .rst_n(rst_n_sync),
        .wb_addr(timer_addr),
        .wb_dat_i(timer_dat_i),
        .wb_dat_o(timer_dat_o),
        .wb_we(timer_we),
        .wb_sel(timer_sel),
        .wb_stb(timer_stb),
        .wb_ack(timer_ack),
        .irq(timer_irq)
    );

    //==========================================================================
    // Peripherals: GPIO
    //==========================================================================

    wire [7:0]  gpio_addr;
    wire [31:0] gpio_dat_i_bus;
    wire [31:0] gpio_dat_o_bus;
    wire        gpio_we;
    wire [3:0]  gpio_sel;
    wire        gpio_stb;
    wire        gpio_ack;

    wire [31:0] gpio_in;
    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;

    gpio gpio_periph (
        .clk(clk),
        .rst_n(rst_n_sync),
        .wb_addr(gpio_addr),
        .wb_dat_i(gpio_dat_i_bus),
        .wb_dat_o(gpio_dat_o_bus),
        .wb_we(gpio_we),
        .wb_sel(gpio_sel),
        .wb_stb(gpio_stb),
        .wb_ack(gpio_ack),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe)
    );

    // Connect GPIO pins (bidirectional)
    assign gpio = gpio_oe[15:0] ? gpio_out[15:0] : 16'hZZZZ;
    assign gpio_in[15:0] = gpio;
    assign gpio_in[31:16] = 16'd0;  // Unused pins

    //==========================================================================
    // Peripherals: UART
    //==========================================================================

    wire [7:0]  uart_addr;
    wire [31:0] uart_dat_i_bus;
    wire [31:0] uart_dat_o_bus;
    wire        uart_we;
    wire [3:0]  uart_sel;
    wire        uart_stb;
    wire        uart_ack;
    wire        uart_irq;

    uart #(
        .CLK_FREQ(CLK_FREQ),
        .DEFAULT_BAUD(UART_BAUD)
    ) uart_periph (
        .clk(clk),
        .rst_n(rst_n_sync),
        .wb_addr(uart_addr),
        .wb_dat_i(uart_dat_i_bus),
        .wb_dat_o(uart_dat_o_bus),
        .wb_we(uart_we),
        .wb_sel(uart_sel),
        .wb_stb(uart_stb),
        .wb_ack(uart_ack),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .irq(uart_irq)
    );

    //==========================================================================
    // Wishbone Bus Interconnect
    //==========================================================================

    wishbone_interconnect bus_interconnect (
        .clk(clk),
        .rst_n(rst_n_sync),

        // Master (from Arbiter)
        .m_wb_addr(arbiter_m_wb_addr),
        .m_wb_dat_i(arbiter_m_wb_dat_o),
        .m_wb_dat_o(arbiter_m_wb_dat_i),
        .m_wb_we(arbiter_m_wb_we),
        .m_wb_sel(arbiter_m_wb_sel),
        .m_wb_stb(arbiter_m_wb_stb),
        .m_wb_cyc(arbiter_m_wb_cyc),
        .m_wb_ack(arbiter_m_wb_ack),
        .m_wb_err(arbiter_m_wb_err),

        // Slave: ROM
        .rom_addr(rom_addr),
        .rom_stb(rom_stb),
        .rom_dat_o(rom_dat_o),
        .rom_ack(rom_ack),

        // Slave: RAM
        .ram_addr(ram_addr),
        .ram_dat_i(ram_dat_i),
        .ram_dat_o(ram_dat_o),
        .ram_we(ram_we),
        .ram_sel(ram_sel),
        .ram_stb(ram_stb),
        .ram_ack(ram_ack),


        // Slave: PWM
        .pwm_addr(pwm_addr),
        .pwm_dat_i(pwm_dat_i),
        .pwm_dat_o(pwm_dat_o),
        .pwm_we(pwm_we),
        .pwm_sel(pwm_sel),
        .pwm_stb(pwm_stb),
        .pwm_ack(pwm_ack),

        // Slave: ADC
        .adc_addr(adc_addr),
        .adc_dat_i(adc_dat_i),
        .adc_dat_o(adc_dat_o),
        .adc_we(adc_we),
        .adc_sel(adc_sel),
        .adc_stb(adc_stb),
        .adc_ack(adc_ack),

        // Slave: Protection
        .prot_addr(prot_addr),
        .prot_dat_i(prot_dat_i),
        .prot_dat_o(prot_dat_o),
        .prot_we(prot_we),
        .prot_sel(prot_sel),
        .prot_stb(prot_stb),
        .prot_ack(prot_ack),

        // Slave: Timer
        .timer_addr(timer_addr),
        .timer_dat_i(timer_dat_i),
        .timer_dat_o(timer_dat_o),
        .timer_we(timer_we),
        .timer_sel(timer_sel),
        .timer_stb(timer_stb),
        .timer_ack(timer_ack),

        // Slave: GPIO
        .gpio_addr(gpio_addr),
        .gpio_dat_i(gpio_dat_i_bus),
        .gpio_dat_o(gpio_dat_o_bus),
        .gpio_we(gpio_we),
        .gpio_sel(gpio_sel),
        .gpio_stb(gpio_stb),
        .gpio_ack(gpio_ack),

        // Slave: UART
        .uart_addr(uart_addr),
        .uart_dat_i(uart_dat_i_bus),
        .uart_dat_o(uart_dat_o_bus),
        .uart_we(uart_we),
        .uart_sel(uart_sel),
        .uart_stb(uart_stb),
        .uart_ack(uart_ack)
    );

    //==========================================================================
    // Interrupt Aggregation
    //==========================================================================

    assign cpu_interrupts = {
        27'd0,
        uart_irq,      // [4]
        timer_irq,     // [3]
        prot_irq,      // [2]
        adc_irq,       // [1]
        1'b0           // [0] - reserved
    };

    //==========================================================================
    // Status LEDs
    //==========================================================================

    assign led[0] = rst_n_sync;         // Power indicator
    assign led[1] = pwm_disable;        // Fault indicator
    assign led[2] = uart_tx;            // UART TX activity
    assign led[3] = |cpu_interrupts;    // Interrupt active

endmodule
