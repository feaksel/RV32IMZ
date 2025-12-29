// Complete Macro-Based RV32IM SoC - Using Integrated Core
// Uses rv32im_integrated_macro (single IP) + peripherals
// This is the RECOMMENDED architecture for reusable IP deployment

module rv32im_soc_with_integrated_core (
    // System signals
    input  wire clk,
    input  wire rst_n,
    
    // External memory interface
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
    
    // External interrupts
    input  wire [7:0]  ext_interrupts
);

//==============================================================================
// Internal Wishbone Bus Matrix
//==============================================================================

// CPU instruction and data buses
wire [31:0] iwb_adr;
wire [31:0] iwb_dat_miso;
wire        iwb_cyc;
wire        iwb_stb;
wire        iwb_ack;

wire [31:0] dwb_adr;
wire [31:0] dwb_dat_mosi;
wire [31:0] dwb_dat_miso;
wire        dwb_we;
wire [3:0]  dwb_sel;
wire        dwb_cyc;
wire        dwb_stb;
wire        dwb_ack;
wire        dwb_err;

// Peripheral acknowledgments
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
// Address Decode
//==============================================================================

wire mem_sel = dwb_cyc && dwb_stb && (dwb_adr[31:29] == 3'b000);
wire pwm_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4000);
wire adc_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4001);
wire prot_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4002);
wire comm_sel = dwb_cyc && dwb_stb && (dwb_adr[31:16] == 16'h4003);

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
// Interrupt Aggregation
//==============================================================================

wire [15:0] internal_interrupts;
wire pwm_irq;
wire adc_irq;
wire prot_irq;
wire comm_irq;

assign internal_interrupts[0] = comm_irq;
assign internal_interrupts[1] = timer_interrupt;
assign internal_interrupts[2] = pwm_irq;
assign internal_interrupts[3] = adc_irq;
assign internal_interrupts[4] = prot_irq;
assign internal_interrupts[5] = watchdog_timeout;
assign internal_interrupts[6] = emergency_stop;
assign internal_interrupts[7] = 1'b0;
assign internal_interrupts[15:8] = ext_interrupts;

//==============================================================================
// RV32IM Integrated Core Macro (Core + MDU in ONE macro)
//==============================================================================

rv32im_integrated_macro u_cpu_core (
    .clk                (clk),
    .rst_n              (rst_n && !system_reset),
    
    // Instruction Wishbone Bus
    .iwb_adr_o          (iwb_adr),
    .iwb_dat_i          (iwb_dat_miso),
    .iwb_cyc_o          (iwb_cyc),
    .iwb_stb_o          (iwb_stb),
    .iwb_ack_i          (iwb_ack),
    
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
    .interrupts         ({16'b0, internal_interrupts})
);

//==============================================================================
// Memory Macro (same as before)
//==============================================================================

memory_macro u_memory (
    .clk                (clk),
    .rst_n              (rst_n),
    .iwb_adr_i          (iwb_adr),
    .iwb_dat_o          (iwb_dat_miso),
    .iwb_dat_i          (32'h0),
    .iwb_we_i           (1'b0),
    .iwb_sel_i          (4'hF),
    .iwb_cyc_i          (iwb_cyc),
    .iwb_stb_i          (iwb_stb),
    .iwb_ack_o          (iwb_ack),
    .iwb_err_o          (),
    .dwb_adr_i          (mem_sel ? dwb_adr : 32'h0),
    .dwb_dat_o          (mem_wb_dat_miso),
    .dwb_dat_i          (mem_sel ? dwb_dat_mosi : 32'h0),
    .dwb_we_i           (mem_sel ? dwb_we : 1'b0),
    .dwb_sel_i          (mem_sel ? dwb_sel : 4'h0),
    .dwb_cyc_i          (mem_sel ? dwb_cyc : 1'b0),
    .dwb_stb_i          (mem_sel ? dwb_stb : 1'b0),
    .dwb_ack_o          (mem_wb_ack),
    .dwb_err_o          (mem_wb_err)
);

//==============================================================================
// Peripheral Macros (same as before)
//==============================================================================

pwm_accelerator_macro u_pwm (
    .clk(clk), .rst_n(rst_n),
    .wb_adr_i(pwm_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o(pwm_wb_dat_miso),
    .wb_dat_i(pwm_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i(pwm_sel ? dwb_we : 1'b0),
    .wb_sel_i(pwm_sel ? dwb_sel : 4'h0),
    .wb_cyc_i(pwm_sel ? dwb_cyc : 1'b0),
    .wb_stb_i(pwm_sel ? dwb_stb : 1'b0),
    .wb_ack_o(pwm_wb_ack),
    .wb_err_o(pwm_wb_err),
    .pwm_out(pwm_out),
    .pwm_out_n(pwm_out_n),
    .irq(pwm_irq)
);

adc_subsystem_macro u_adc (
    .clk(clk), .rst_n(rst_n),
    .wb_adr_i(adc_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o(adc_wb_dat_miso),
    .wb_dat_i(adc_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i(adc_sel ? dwb_we : 1'b0),
    .wb_sel_i(adc_sel ? dwb_sel : 4'h0),
    .wb_cyc_i(adc_sel ? dwb_cyc : 1'b0),
    .wb_stb_i(adc_sel ? dwb_stb : 1'b0),
    .wb_ack_o(adc_wb_ack),
    .wb_err_o(adc_wb_err),
    .adc_data_in(adc_data_in),
    .adc_clk_out(adc_clk_out),
    .ch0_data(ch0_data),
    .ch1_data(ch1_data),
    .ch2_data(ch2_data),
    .ch3_data(ch3_data),
    .adc_data_valid(adc_data_valid),
    .irq(adc_irq)
);

protection_macro u_protection (
    .clk(clk), .rst_n(rst_n),
    .wb_adr_i(prot_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o(prot_wb_dat_miso),
    .wb_dat_i(prot_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i(prot_sel ? dwb_we : 1'b0),
    .wb_sel_i(prot_sel ? dwb_sel : 4'h0),
    .wb_cyc_i(prot_sel ? dwb_cyc : 1'b0),
    .wb_stb_i(prot_sel ? dwb_stb : 1'b0),
    .wb_ack_o(prot_wb_ack),
    .wb_err_o(prot_wb_err),
    .current_sense(current_sense),
    .voltage_sense(voltage_sense),
    .thermal_alert_in(thermal_alert_in),
    .emergency_stop(emergency_stop),
    .channel_disable(channel_disable),
    .system_reset(system_reset),
    .watchdog_timeout(watchdog_timeout),
    .irq(prot_irq)
);

communication_macro u_communication (
    .clk(clk), .rst_n(rst_n),
    .wb_adr_i(comm_sel ? dwb_adr[15:0] : 16'h0),
    .wb_dat_o(comm_wb_dat_miso),
    .wb_dat_i(comm_sel ? dwb_dat_mosi : 32'h0),
    .wb_we_i(comm_sel ? dwb_we : 1'b0),
    .wb_sel_i(comm_sel ? dwb_sel : 4'h0),
    .wb_cyc_i(comm_sel ? dwb_cyc : 1'b0),
    .wb_stb_i(comm_sel ? dwb_stb : 1'b0),
    .wb_ack_o(comm_wb_ack),
    .wb_err_o(comm_wb_err),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_cs_n(spi_cs_n),
    .gpio(gpio),
    .irq(comm_irq)
);

assign timer_interrupt = 1'b0;
assign timer_compare_out = 4'b0;

endmodule
