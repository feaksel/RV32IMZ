// Complete RV32IM SoC with Hierarchical Core + Peripherals
// Integrates: Core Macro (MDU + Pipeline) + All Peripherals + Bus Interconnect

module rv32im_soc_complete (
    // System signals
    input  wire clk,
    input  wire rst_n,
    
    // External memory interface (for bootloader/external memory)
    output wire [31:0] ext_mem_adr_o,
    output wire [31:0] ext_mem_dat_o,
    input  wire [31:0] ext_mem_dat_i,
    output wire        ext_mem_we_o,
    output wire [3:0]  ext_mem_sel_o,
    output wire        ext_mem_cyc_o,
    output wire        ext_mem_stb_o,
    input  wire        ext_mem_ack_i,
    input  wire        ext_mem_err_i,
    
    // UART interface
    output wire uart_tx,
    input  wire uart_rx,
    
    // SPI interface
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire spi_cs_n,
    
    // PWM outputs
    output wire [7:0] pwm_out,
    
    // GPIO
    inout  wire [15:0] gpio,
    
    // ADC interface (Sigma-Delta)
    input  wire adc_data_in,
    output wire adc_clk_out,
    
    // Thermal monitoring
    output wire thermal_alert,
    
    // Interrupts from external sources
    input  wire [7:0] ext_interrupts,
    
    // Debug interface
    output wire debug_uart_tx,
    input  wire debug_uart_rx
);

//==============================================================================
// Internal Wishbone Bus Signals
//==============================================================================

// Instruction bus from core to memory
wire [31:0] iwb_adr;
wire [31:0] iwb_dat_mosi;
wire [31:0] iwb_dat_miso;
wire        iwb_we;
wire [3:0]  iwb_sel;
wire        iwb_cyc;
wire        iwb_stb;
wire        iwb_ack;
wire        iwb_err;

// Data bus from core to peripherals/memory
wire [31:0] dwb_adr;
wire [31:0] dwb_dat_mosi;
wire [31:0] dwb_dat_miso;
wire        dwb_we;
wire [3:0]  dwb_sel;
wire        dwb_cyc;
wire        dwb_stb;
wire        dwb_ack;
wire        dwb_err;

// Peripheral wishbone buses
wire [31:0] uart_wb_dat_miso;
wire        uart_wb_ack;
wire        uart_wb_err;

wire [31:0] spi_wb_dat_miso;
wire        spi_wb_ack;
wire        spi_wb_err;

wire [31:0] pwm_wb_dat_miso;
wire        pwm_wb_ack;
wire        pwm_wb_err;

wire [31:0] gpio_wb_dat_miso;
wire        gpio_wb_ack;
wire        gpio_wb_err;

wire [31:0] adc_wb_dat_miso;
wire        adc_wb_ack;
wire        adc_wb_err;

wire [31:0] thermal_wb_dat_miso;
wire        thermal_wb_ack;
wire        thermal_wb_err;

// Memory controller signals
wire [31:0] mem_ctrl_wb_dat_miso;
wire        mem_ctrl_wb_ack;
wire        mem_ctrl_wb_err;

//==============================================================================
// Interrupt Management
//==============================================================================

wire [15:0] internal_interrupts;
wire [15:0] combined_interrupts;

assign internal_interrupts[0] = uart_interrupt;
assign internal_interrupts[1] = spi_interrupt;
assign internal_interrupts[2] = pwm_interrupt;
assign internal_interrupts[3] = gpio_interrupt;
assign internal_interrupts[4] = adc_interrupt;
assign internal_interrupts[5] = thermal_interrupt;
assign internal_interrupts[6] = timer_interrupt;
assign internal_interrupts[7] = 1'b0; // Reserved
assign internal_interrupts[15:8] = ext_interrupts;

assign combined_interrupts = internal_interrupts;

// Individual interrupt signals
wire uart_interrupt;
wire spi_interrupt;
wire pwm_interrupt;
wire gpio_interrupt;
wire adc_interrupt;
wire thermal_interrupt;
wire timer_interrupt;

//==============================================================================
// Address Decode and Bus Arbitration
//==============================================================================

wire [31:0] peripheral_wb_adr;
wire [31:0] peripheral_wb_dat_mosi;
wire [31:0] peripheral_wb_dat_miso;
wire        peripheral_wb_we;
wire [3:0]  peripheral_wb_sel;
wire        peripheral_wb_cyc;
wire        peripheral_wb_stb;
wire        peripheral_wb_ack;
wire        peripheral_wb_err;

// Address decode enables
wire uart_sel     = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h1000);
wire spi_sel      = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h1001);
wire pwm_sel      = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h1002);
wire gpio_sel     = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h1003);
wire adc_sel      = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h1004);
wire thermal_sel  = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h1005);
wire mem_sel      = dwb_cyc && dwb_stb && (dwb_adr[31:20] == 12'h200); // 0x20000000 range

// Bus mux logic
assign peripheral_wb_adr = dwb_adr;
assign peripheral_wb_dat_mosi = dwb_dat_mosi;
assign peripheral_wb_we = dwb_we;
assign peripheral_wb_sel = dwb_sel;
assign peripheral_wb_cyc = dwb_cyc;
assign peripheral_wb_stb = dwb_stb;

// Response multiplexer
assign dwb_dat_miso = uart_sel ? uart_wb_dat_miso :
                     spi_sel ? spi_wb_dat_miso :
                     pwm_sel ? pwm_wb_dat_miso :
                     gpio_sel ? gpio_wb_dat_miso :
                     adc_sel ? adc_wb_dat_miso :
                     thermal_sel ? thermal_wb_dat_miso :
                     mem_sel ? mem_ctrl_wb_dat_miso :
                     32'h00000000;

assign dwb_ack = uart_sel ? uart_wb_ack :
                spi_sel ? spi_wb_ack :
                pwm_sel ? pwm_wb_ack :
                gpio_sel ? gpio_wb_ack :
                adc_sel ? adc_wb_ack :
                thermal_sel ? thermal_wb_ack :
                mem_sel ? mem_ctrl_wb_ack :
                1'b0;

assign dwb_err = uart_sel ? uart_wb_err :
                spi_sel ? spi_wb_err :
                pwm_sel ? pwm_wb_err :
                gpio_sel ? gpio_wb_err :
                adc_sel ? adc_wb_err :
                thermal_sel ? thermal_wb_err :
                mem_sel ? mem_ctrl_wb_err :
                1'b0;

//==============================================================================
// RV32IM Hierarchical Core (2-Macro Design)
//==============================================================================

rv32im_hierarchical_top u_core (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Instruction Wishbone Bus
    .iwb_adr_o      (iwb_adr),
    .iwb_dat_o      (iwb_dat_mosi),
    .iwb_dat_i      (iwb_dat_miso),
    .iwb_we_o       (iwb_we),
    .iwb_sel_o      (iwb_sel),
    .iwb_cyc_o      (iwb_cyc),
    .iwb_stb_o      (iwb_stb),
    .iwb_ack_i      (iwb_ack),
    .iwb_err_i      (iwb_err),
    
    // Data Wishbone Bus  
    .dwb_adr_o      (dwb_adr),
    .dwb_dat_o      (dwb_dat_mosi),
    .dwb_dat_i      (dwb_dat_miso),
    .dwb_we_o       (dwb_we),
    .dwb_sel_o      (dwb_sel),
    .dwb_cyc_o      (dwb_cyc),
    .dwb_stb_o      (dwb_stb),
    .dwb_ack_i      (dwb_ack),
    .dwb_err_i      (dwb_err),
    
    // Interrupts
    .interrupts     (combined_interrupts)
);

//==============================================================================
// Memory Controller (for External Memory)
//==============================================================================

wishbone_memory_controller u_mem_ctrl (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Instruction Wishbone (connects to core iwb)
    .iwb_adr_i      (iwb_adr),
    .iwb_dat_o      (iwb_dat_miso),
    .iwb_dat_i      (iwb_dat_mosi),
    .iwb_we_i       (iwb_we),
    .iwb_sel_i      (iwb_sel),
    .iwb_cyc_i      (iwb_cyc),
    .iwb_stb_i      (iwb_stb),
    .iwb_ack_o      (iwb_ack),
    .iwb_err_o      (iwb_err),
    
    // Data Wishbone (when accessing memory range)
    .dwb_adr_i      (mem_sel ? dwb_adr : 32'h0),
    .dwb_dat_o      (mem_ctrl_wb_dat_miso),
    .dwb_dat_i      (mem_sel ? dwb_dat_mosi : 32'h0),
    .dwb_we_i       (mem_sel ? dwb_we : 1'b0),
    .dwb_sel_i      (mem_sel ? dwb_sel : 4'h0),
    .dwb_cyc_i      (mem_sel ? dwb_cyc : 1'b0),
    .dwb_stb_i      (mem_sel ? dwb_stb : 1'b0),
    .dwb_ack_o      (mem_ctrl_wb_ack),
    .dwb_err_o      (mem_ctrl_wb_err),
    
    // External memory interface
    .ext_adr_o      (ext_mem_adr_o),
    .ext_dat_o      (ext_mem_dat_o),
    .ext_dat_i      (ext_mem_dat_i),
    .ext_we_o       (ext_mem_we_o),
    .ext_sel_o      (ext_mem_sel_o),
    .ext_cyc_o      (ext_mem_cyc_o),
    .ext_stb_o      (ext_mem_stb_o),
    .ext_ack_i      (ext_mem_ack_i),
    .ext_err_i      (ext_mem_err_i)
);

//==============================================================================
// UART Peripheral
//==============================================================================

uart_peripheral u_uart (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (uart_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o       (uart_wb_dat_miso),
    .wb_dat_i       (uart_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i        (uart_sel ? dwb_we : 1'b0),
    .wb_sel_i       (uart_sel ? dwb_sel : 4'h0),
    .wb_cyc_i       (uart_sel ? dwb_cyc : 1'b0),
    .wb_stb_i       (uart_sel ? dwb_stb : 1'b0),
    .wb_ack_o       (uart_wb_ack),
    .wb_err_o       (uart_wb_err),
    
    // UART signals
    .uart_tx        (uart_tx),
    .uart_rx        (uart_rx),
    
    // Interrupt
    .irq            (uart_interrupt)
);

//==============================================================================
// SPI Peripheral
//==============================================================================

spi_peripheral u_spi (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (spi_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o       (spi_wb_dat_miso),
    .wb_dat_i       (spi_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i        (spi_sel ? dwb_we : 1'b0),
    .wb_sel_i       (spi_sel ? dwb_sel : 4'h0),
    .wb_cyc_i       (spi_sel ? dwb_cyc : 1'b0),
    .wb_stb_i       (spi_sel ? dwb_stb : 1'b0),
    .wb_ack_o       (spi_wb_ack),
    .wb_err_o       (spi_wb_err),
    
    // SPI signals
    .spi_sclk       (spi_sclk),
    .spi_mosi       (spi_mosi),
    .spi_miso       (spi_miso),
    .spi_cs_n       (spi_cs_n),
    
    // Interrupt
    .irq            (spi_interrupt)
);

//==============================================================================
// PWM Accelerator
//==============================================================================

pwm_accelerator u_pwm (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (pwm_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o       (pwm_wb_dat_miso),
    .wb_dat_i       (pwm_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i        (pwm_sel ? dwb_we : 1'b0),
    .wb_sel_i       (pwm_sel ? dwb_sel : 4'h0),
    .wb_cyc_i       (pwm_sel ? dwb_cyc : 1'b0),
    .wb_stb_i       (pwm_sel ? dwb_stb : 1'b0),
    .wb_ack_o       (pwm_wb_ack),
    .wb_err_o       (pwm_wb_err),
    
    // PWM outputs
    .pwm_out        (pwm_out),
    
    // Interrupt
    .irq            (pwm_interrupt)
);

//==============================================================================
// GPIO Controller
//==============================================================================

gpio_controller u_gpio (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (gpio_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o       (gpio_wb_dat_miso),
    .wb_dat_i       (gpio_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i        (gpio_sel ? dwb_we : 1'b0),
    .wb_sel_i       (gpio_sel ? dwb_sel : 4'h0),
    .wb_cyc_i       (gpio_sel ? dwb_cyc : 1'b0),
    .wb_stb_i       (gpio_sel ? dwb_stb : 1'b0),
    .wb_ack_o       (gpio_wb_ack),
    .wb_err_o       (gpio_wb_err),
    
    // GPIO signals
    .gpio           (gpio),
    
    // Interrupt
    .irq            (gpio_interrupt)
);

//==============================================================================
// Sigma-Delta ADC Controller
//==============================================================================

sigma_delta_adc u_adc (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (adc_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o       (adc_wb_dat_miso),
    .wb_dat_i       (adc_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i        (adc_sel ? dwb_we : 1'b0),
    .wb_sel_i       (adc_sel ? dwb_sel : 4'h0),
    .wb_cyc_i       (adc_sel ? dwb_cyc : 1'b0),
    .wb_stb_i       (adc_sel ? dwb_stb : 1'b0),
    .wb_ack_o       (adc_wb_ack),
    .wb_err_o       (adc_wb_err),
    
    // ADC interface
    .adc_data_in    (adc_data_in),
    .adc_clk_out    (adc_clk_out),
    
    // Interrupt
    .irq            (adc_interrupt)
);

//==============================================================================
// Thermal Monitor
//==============================================================================

thermal_monitor u_thermal (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (thermal_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o       (thermal_wb_dat_miso),
    .wb_dat_i       (thermal_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i        (thermal_sel ? dwb_we : 1'b0),
    .wb_sel_i       (thermal_sel ? dwb_sel : 4'h0),
    .wb_cyc_i       (thermal_sel ? dwb_cyc : 1'b0),
    .wb_stb_i       (thermal_sel ? dwb_stb : 1'b0),
    .wb_ack_o       (thermal_wb_ack),
    .wb_err_o       (thermal_wb_err),
    
    // Thermal alert
    .thermal_alert  (thermal_alert),
    
    // Interrupt
    .irq            (thermal_interrupt)
);

//==============================================================================
// Debug UART (Separate from main UART)
//==============================================================================

debug_uart u_debug_uart (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Connect to core debug interface
    .debug_data     (dwb_adr[7:0]),  // Simple debug data from address bus
    .debug_valid    (dwb_cyc && dwb_stb && (dwb_adr == 32'hFFFF_FFFC)), // Debug write address
    
    // Debug UART signals
    .debug_tx       (debug_uart_tx),
    .debug_rx       (debug_uart_rx)
);

//==============================================================================
// System Timer (for timer interrupts)
//==============================================================================

system_timer u_timer (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Timer interrupt output
    .timer_irq      (timer_interrupt)
);

endmodule

//==============================================================================
// Simplified Peripheral Modules (Placeholder implementations)
//==============================================================================

// These would be full implementations in real design
// Showing interface structure for integration

module wishbone_memory_controller (
    input clk, rst_n,
    input [31:0] iwb_adr_i, dwb_adr_i,
    output [31:0] iwb_dat_o, dwb_dat_o,
    input [31:0] iwb_dat_i, dwb_dat_i,
    input iwb_we_i, dwb_we_i,
    input [3:0] iwb_sel_i, dwb_sel_i,
    input iwb_cyc_i, iwb_stb_i, dwb_cyc_i, dwb_stb_i,
    output iwb_ack_o, iwb_err_o, dwb_ack_o, dwb_err_o,
    output [31:0] ext_adr_o, ext_dat_o,
    input [31:0] ext_dat_i,
    output ext_we_o,
    output [3:0] ext_sel_o,
    output ext_cyc_o, ext_stb_o,
    input ext_ack_i, ext_err_i
);
    // Memory controller implementation...
    assign iwb_ack_o = iwb_cyc_i && iwb_stb_i;
    assign dwb_ack_o = dwb_cyc_i && dwb_stb_i;
    assign iwb_err_o = 1'b0;
    assign dwb_err_o = 1'b0;
    assign iwb_dat_o = 32'h00000013; // NOP instruction
    assign dwb_dat_o = 32'h0;
    
    // Forward to external memory
    assign ext_adr_o = iwb_cyc_i ? iwb_adr_i : dwb_adr_i;
    assign ext_dat_o = dwb_dat_i;
    assign ext_we_o = dwb_we_i;
    assign ext_sel_o = iwb_cyc_i ? iwb_sel_i : dwb_sel_i;
    assign ext_cyc_o = iwb_cyc_i || dwb_cyc_i;
    assign ext_stb_o = iwb_stb_i || dwb_stb_i;
endmodule

module uart_peripheral (
    input clk, rst_n,
    input [15:0] wb_adr_i,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_we_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i, wb_stb_i,
    output wb_ack_o, wb_err_o,
    output uart_tx,
    input uart_rx,
    output irq
);
    assign wb_ack_o = wb_cyc_i && wb_stb_i;
    assign wb_err_o = 1'b0;
    assign wb_dat_o = 32'h0;
    assign uart_tx = 1'b1;
    assign irq = 1'b0;
endmodule

module spi_peripheral (
    input clk, rst_n,
    input [15:0] wb_adr_i,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_we_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i, wb_stb_i,
    output wb_ack_o, wb_err_o,
    output spi_sclk, spi_mosi, spi_cs_n,
    input spi_miso,
    output irq
);
    assign wb_ack_o = wb_cyc_i && wb_stb_i;
    assign wb_err_o = 1'b0;
    assign wb_dat_o = 32'h0;
    assign spi_sclk = 1'b0;
    assign spi_mosi = 1'b0;
    assign spi_cs_n = 1'b1;
    assign irq = 1'b0;
endmodule

module pwm_accelerator (
    input clk, rst_n,
    input [15:0] wb_adr_i,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_we_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i, wb_stb_i,
    output wb_ack_o, wb_err_o,
    output [7:0] pwm_out,
    output irq
);
    assign wb_ack_o = wb_cyc_i && wb_stb_i;
    assign wb_err_o = 1'b0;
    assign wb_dat_o = 32'h0;
    assign pwm_out = 8'h0;
    assign irq = 1'b0;
endmodule

module gpio_controller (
    input clk, rst_n,
    input [15:0] wb_adr_i,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_we_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i, wb_stb_i,
    output wb_ack_o, wb_err_o,
    inout [15:0] gpio,
    output irq
);
    assign wb_ack_o = wb_cyc_i && wb_stb_i;
    assign wb_err_o = 1'b0;
    assign wb_dat_o = 32'h0;
    assign irq = 1'b0;
endmodule

module sigma_delta_adc (
    input clk, rst_n,
    input [15:0] wb_adr_i,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_we_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i, wb_stb_i,
    output wb_ack_o, wb_err_o,
    input adc_data_in,
    output adc_clk_out,
    output irq
);
    assign wb_ack_o = wb_cyc_i && wb_stb_i;
    assign wb_err_o = 1'b0;
    assign wb_dat_o = 32'h0;
    assign adc_clk_out = clk;
    assign irq = 1'b0;
endmodule

module thermal_monitor (
    input clk, rst_n,
    input [15:0] wb_adr_i,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_we_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i, wb_stb_i,
    output wb_ack_o, wb_err_o,
    output thermal_alert,
    output irq
);
    assign wb_ack_o = wb_cyc_i && wb_stb_i;
    assign wb_err_o = 1'b0;
    assign wb_dat_o = 32'h0;
    assign thermal_alert = 1'b0;
    assign irq = 1'b0;
endmodule

module debug_uart (
    input clk, rst_n,
    input [7:0] debug_data,
    input debug_valid,
    output debug_tx,
    input debug_rx
);
    assign debug_tx = 1'b1;
endmodule

module system_timer (
    input clk, rst_n,
    output timer_irq
);
    reg [31:0] timer_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            timer_count <= 32'h0;
        else 
            timer_count <= timer_count + 1;
    end
    assign timer_irq = timer_count[20]; // Timer interrupt every ~1M cycles
endmodule