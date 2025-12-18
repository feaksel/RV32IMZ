// Complete Macro-Based RV32IM SoC
// Integrates all macros: CPU Core + Memory + PWM + ADC + Protection + Communication
// Single package with individual GDS files for each macro plus integrated SoC

module rv32im_macro_soc_complete (
    // System signals
    input  wire clk,
    input  wire rst_n,
    
    // External memory interface (for bootloader/external storage)
    output wire [31:0] ext_mem_adr_o,
    output wire [31:0] ext_mem_dat_o,
    input  wire [31:0] ext_mem_dat_i,
    output wire        ext_mem_we_o,
    output wire [3:0]  ext_mem_sel_o,
    output wire        ext_mem_cyc_o,
    output wire        ext_mem_stb_o,
    input  wire        ext_mem_ack_i,
    input  wire        ext_mem_err_i,
    
    // Communication interfaces
    output wire uart_tx,
    input  wire uart_rx,
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire spi_cs_n,
    inout  wire [15:0] gpio,
    
    // PWM outputs
    output wire [7:0] pwm_out,
    output wire [7:0] pwm_out_n,
    
    // ADC interface
    input  wire [3:0] adc_data_in,
    output wire [3:0] adc_clk_out,
    output wire [15:0] ch0_data,
    output wire [15:0] ch1_data,
    output wire [15:0] ch2_data,
    output wire [15:0] ch3_data,
    output wire [3:0]  adc_data_valid,
    
    // Protection interface
    input  wire [3:0] current_sense,
    input  wire [3:0] voltage_sense,
    input  wire       thermal_alert_in,
    output wire       emergency_stop,
    output wire [3:0] channel_disable,
    output wire       system_reset,
    output wire       watchdog_timeout,
    
    // Timer outputs
    output wire       timer_interrupt,
    output wire [3:0] timer_compare_out,
    
    // System status and debug
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire        debug_valid,
    output wire [31:0] cycle_count,
    output wire [31:0] instr_count,
    
    // External interrupts
    input  wire [7:0]  ext_interrupts
);

//==============================================================================
// Internal Wishbone Bus Matrix
//==============================================================================

// CPU instruction and data buses
wire [31:0] iwb_adr;
wire [31:0] iwb_dat_mosi;
wire [31:0] iwb_dat_miso;
wire        iwb_we;
wire [3:0]  iwb_sel;
wire        iwb_cyc;
wire        iwb_stb;
wire        iwb_ack;
wire        iwb_err;

wire [31:0] dwb_adr;
wire [31:0] dwb_dat_mosi;
wire [31:0] dwb_dat_miso;
wire        dwb_we;
wire [3:0]  dwb_sel;
wire        dwb_cyc;
wire        dwb_stb;
wire        dwb_ack;
wire        dwb_err;

// Macro interface signals
wire [31:0] mem_wb_dat_miso;
wire        mem_wb_ack;
wire        mem_wb_err;

wire [31:0] pwm_wb_dat_miso;
wire        pwm_wb_ack;
wire        pwm_wb_err;

wire [31:0] adc_wb_dat_miso;
wire        adc_wb_ack;
wire        adc_wb_err;

wire [31:0] prot_wb_dat_miso;
wire        prot_wb_ack;
wire        prot_wb_err;

wire [31:0] comm_wb_dat_miso;
wire        comm_wb_ack;
wire        comm_wb_err;

//==============================================================================
// Address Decode for Macro Selection
//==============================================================================

// Memory map:
// 0x00000000-0x1FFFFFFF: Memory Macro (ROM/RAM/External)
// 0x40000000-0x4000FFFF: PWM Accelerator Macro
// 0x40010000-0x4001FFFF: ADC Subsystem Macro
// 0x40020000-0x4002FFFF: Protection Macro
// 0x40030000-0x4003FFFF: Communication Macro

wire mem_sel = dwb_cyc && dwb_stb && (dwb_adr[31:29] == 3'b000); // 0x00000000-0x1FFFFFFF
wire pwm_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4000); // 0x40000000-0x4000FFFF
wire adc_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4001); // 0x40010000-0x4001FFFF
wire prot_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4002); // 0x40020000-0x4002FFFF
wire comm_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4003); // 0x40030000-0x4003FFFF

//==============================================================================
// Data Bus Response Multiplexer
//==============================================================================

assign dwb_dat_miso = mem_sel ? mem_wb_dat_miso :
                     pwm_sel ? pwm_wb_dat_miso :
                     adc_sel ? adc_wb_dat_miso :
                     prot_sel ? prot_wb_dat_miso :
                     comm_sel ? comm_wb_dat_miso :
                     32'h00000000;

assign dwb_ack = mem_sel ? mem_wb_ack :
                pwm_sel ? pwm_wb_ack :
                adc_sel ? adc_wb_ack :
                prot_sel ? prot_wb_ack :
                comm_sel ? comm_wb_ack :
                1'b0;

assign dwb_err = mem_sel ? mem_wb_err :
                pwm_sel ? pwm_wb_err :
                adc_sel ? adc_wb_err :
                prot_sel ? prot_wb_err :
                comm_sel ? comm_wb_err :
                1'b0;

//==============================================================================
// Interrupt Management
//==============================================================================

wire [15:0] internal_interrupts;
wire [15:0] combined_interrupts;

wire pwm_irq;
wire adc_irq;
wire prot_irq;
wire comm_irq;

assign internal_interrupts[0] = comm_irq;      // Communication (UART/GPIO/SPI)
assign internal_interrupts[1] = timer_interrupt; // Timer
assign internal_interrupts[2] = pwm_irq;      // PWM accelerator
assign internal_interrupts[3] = adc_irq;      // ADC subsystem
assign internal_interrupts[4] = prot_irq;     // Protection system
assign internal_interrupts[5] = watchdog_timeout; // Watchdog
assign internal_interrupts[6] = emergency_stop;   // Emergency stop
assign internal_interrupts[7] = 1'b0;         // Reserved
assign internal_interrupts[15:8] = ext_interrupts; // External interrupts

assign combined_interrupts = internal_interrupts;

//==============================================================================
// CPU Core Macro (RV32IM + MDU)
//==============================================================================

cpu_core_macro u_cpu_core (
    .clk                (clk),
    .rst_n              (rst_n && !system_reset), // Include protection reset
    
    // Instruction Wishbone Bus
    .iwb_adr_o          (iwb_adr),
    .iwb_dat_o          (iwb_dat_mosi),
    .iwb_dat_i          (iwb_dat_miso),
    .iwb_we_o           (iwb_we),
    .iwb_sel_o          (iwb_sel),
    .iwb_cyc_o          (iwb_cyc),
    .iwb_stb_o          (iwb_stb),
    .iwb_ack_i          (iwb_ack),
    .iwb_err_i          (iwb_err),
    
    // Data Wishbone Bus
    .dwb_adr_o          (dwb_adr),
    .dwb_dat_o          (dwb_dat_mosi),
    .dwb_dat_i          (dwb_dat_miso),
    .dwb_we_o           (dwb_we),
    .dwb_sel_o          (dwb_sel),
    .dwb_cyc_o          (dwb_cyc),
    .dwb_stb_o          (dwb_stb),
    .dwb_ack_i          (dwb_ack),
    .dwb_err_i          (dwb_err),
    
    // Interrupts
    .interrupts         (combined_interrupts),
    
    // Debug interface
    .debug_pc           (debug_pc),
    .debug_instruction  (debug_instruction),
    .debug_valid        (debug_valid),
    
    // Performance counters
    .cycle_count        (cycle_count),
    .instr_count        (instr_count)
);

//==============================================================================
// Memory Macro (32KB ROM + 64KB RAM)
//==============================================================================

memory_macro u_memory (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // Instruction Wishbone Bus
    .iwb_adr_i          (iwb_adr),
    .iwb_dat_o          (iwb_dat_miso),
    .iwb_dat_i          (iwb_dat_mosi),
    .iwb_we_i           (iwb_we),
    .iwb_sel_i          (iwb_sel),
    .iwb_cyc_i          (iwb_cyc),
    .iwb_stb_i          (iwb_stb),
    .iwb_ack_o          (iwb_ack),
    .iwb_err_o          (iwb_err),
    
    // Data Wishbone Bus (for memory range)
    .dwb_adr_i          (mem_sel ? dwb_adr : 32'h0),
    .dwb_dat_o          (mem_wb_dat_miso),
    .dwb_dat_i          (mem_sel ? dwb_dat_mosi : 32'h0),
    .dwb_we_i           (mem_sel ? dwb_we : 1'b0),
    .dwb_sel_i          (mem_sel ? dwb_sel : 4'h0),
    .dwb_cyc_i          (mem_sel ? dwb_cyc : 1'b0),
    .dwb_stb_i          (mem_sel ? dwb_stb : 1'b0),
    .dwb_ack_o          (mem_wb_ack),
    .dwb_err_o          (mem_wb_err),
    
    // External memory interface
    .ext_mem_adr_o      (ext_mem_adr_o),
    .ext_mem_dat_o      (ext_mem_dat_o),
    .ext_mem_dat_i      (ext_mem_dat_i),
    .ext_mem_we_o       (ext_mem_we_o),
    .ext_mem_sel_o      (ext_mem_sel_o),
    .ext_mem_cyc_o      (ext_mem_cyc_o),
    .ext_mem_stb_o      (ext_mem_stb_o),
    .ext_mem_ack_i      (ext_mem_ack_i),
    .ext_mem_err_i      (ext_mem_err_i),
    
    // Status
    .rom_ready          (),
    .ram_ready          (),
    .memory_status      ()
);

//==============================================================================
// PWM Accelerator Macro
//==============================================================================

wire pwm_sync_out;

pwm_accelerator_macro u_pwm_accelerator (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // Wishbone interface
    .wb_adr_i           (pwm_sel ? dwb_adr : 32'h0),
    .wb_dat_o           (pwm_wb_dat_miso),
    .wb_dat_i           (pwm_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i            (pwm_sel ? dwb_we : 1'b0),
    .wb_sel_i           (pwm_sel ? dwb_sel : 4'h0),
    .wb_cyc_i           (pwm_sel ? dwb_cyc : 1'b0),
    .wb_stb_i           (pwm_sel ? dwb_stb : 1'b0),
    .wb_ack_o           (pwm_wb_ack),
    .wb_err_o           (pwm_wb_err),
    
    // PWM outputs
    .pwm_out            (pwm_out),
    .pwm_out_n          (pwm_out_n),
    
    // Interrupt
    .irq                (pwm_irq),
    
    // Sync (can be connected between channels if needed)
    .pwm_sync_out       (pwm_sync_out),
    .pwm_sync_in        (1'b0), // Not used in this configuration
    
    // Status
    .pwm_status         ()
);

//==============================================================================
// ADC Subsystem Macro
//==============================================================================

adc_subsystem_macro u_adc_subsystem (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // Wishbone interface
    .wb_adr_i           (adc_sel ? dwb_adr : 32'h0),
    .wb_dat_o           (adc_wb_dat_miso),
    .wb_dat_i           (adc_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i            (adc_sel ? dwb_we : 1'b0),
    .wb_sel_i           (adc_sel ? dwb_sel : 4'h0),
    .wb_cyc_i           (adc_sel ? dwb_cyc : 1'b0),
    .wb_stb_i           (adc_sel ? dwb_stb : 1'b0),
    .wb_ack_o           (adc_wb_ack),
    .wb_err_o           (adc_wb_err),
    
    // ADC interface
    .adc_data_in        (adc_data_in),
    .adc_clk_out        (adc_clk_out),
    
    // Digital outputs
    .ch0_data           (ch0_data),
    .ch1_data           (ch1_data),
    .ch2_data           (ch2_data),
    .ch3_data           (ch3_data),
    .data_valid         (adc_data_valid),
    
    // Interrupt
    .irq                (adc_irq),
    
    // Status
    .adc_status         ()
);

//==============================================================================
// Protection Macro
//==============================================================================

protection_macro u_protection (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // Wishbone interface
    .wb_adr_i           (prot_sel ? dwb_adr : 32'h0),
    .wb_dat_o           (prot_wb_dat_miso),
    .wb_dat_i           (prot_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i            (prot_sel ? dwb_we : 1'b0),
    .wb_sel_i           (prot_sel ? dwb_sel : 4'h0),
    .wb_cyc_i           (prot_sel ? dwb_cyc : 1'b0),
    .wb_stb_i           (prot_sel ? dwb_stb : 1'b0),
    .wb_ack_o           (prot_wb_ack),
    .wb_err_o           (prot_wb_err),
    
    // Protection inputs
    .current_sense      (current_sense),
    .voltage_sense      (voltage_sense),
    .thermal_alert      (thermal_alert_in),
    
    // Protection outputs
    .emergency_stop     (emergency_stop),
    .channel_disable    (channel_disable),
    .system_reset       (system_reset),
    
    // Watchdog
    .watchdog_kick      (debug_valid), // CPU activity as watchdog kick
    .watchdog_timeout   (watchdog_timeout),
    
    // Interrupt
    .irq                (prot_irq),
    
    // Status
    .protection_status  ()
);

//==============================================================================
// Communication Macro (UART + GPIO + Timer + SPI)
//==============================================================================

communication_macro u_communication (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // Wishbone interface
    .wb_adr_i           (comm_sel ? dwb_adr : 32'h0),
    .wb_dat_o           (comm_wb_dat_miso),
    .wb_dat_i           (comm_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i            (comm_sel ? dwb_we : 1'b0),
    .wb_sel_i           (comm_sel ? dwb_sel : 4'h0),
    .wb_cyc_i           (comm_sel ? dwb_cyc : 1'b0),
    .wb_stb_i           (comm_sel ? dwb_stb : 1'b0),
    .wb_ack_o           (comm_wb_ack),
    .wb_err_o           (comm_wb_err),
    
    // Communication interfaces
    .uart_tx            (uart_tx),
    .uart_rx            (uart_rx),
    .gpio               (gpio),
    .spi_sclk           (spi_sclk),
    .spi_mosi           (spi_mosi),
    .spi_miso           (spi_miso),
    .spi_cs_n           (spi_cs_n),
    
    // Timer outputs
    .timer_interrupt    (timer_interrupt),
    .timer_compare_out  (timer_compare_out),
    
    // Interrupt
    .irq                (comm_irq),
    
    // Status
    .comm_status        ()
);

endmodule