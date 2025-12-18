// Communication Macro: UART + GPIO + Timer
// Combined communication and timing peripherals
// Target: ~2K cells, 50×50μm

module communication_macro (
    input  wire clk,
    input  wire rst_n,
    
    // Wishbone interface
    input  wire [31:0] wb_adr_i,
    output wire [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    input  wire        wb_we_i,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output wire        wb_ack_o,
    output wire        wb_err_o,
    
    // UART interface
    output wire uart_tx,
    input  wire uart_rx,
    
    // GPIO interface  
    inout  wire [15:0] gpio,
    
    // Timer outputs
    output wire timer_interrupt,
    output wire [3:0] timer_compare_out,
    
    // SPI interface
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire spi_cs_n,
    
    // Interrupt
    output wire irq,
    
    // Status
    output wire [31:0] comm_status
);

//==============================================================================
// Address Decode
//==============================================================================
// 0x000-0x0FF: UART registers
// 0x100-0x1FF: GPIO registers  
// 0x200-0x2FF: Timer registers
// 0x300-0x3FF: SPI registers

wire uart_sel = wb_cyc_i && wb_stb_i && (wb_adr_i[9:8] == 2'b00);
wire gpio_sel = wb_cyc_i && wb_stb_i && (wb_adr_i[9:8] == 2'b01);
wire timer_sel = wb_cyc_i && wb_stb_i && (wb_adr_i[9:8] == 2'b10);
wire spi_sel = wb_cyc_i && wb_stb_i && (wb_adr_i[9:8] == 2'b11);

//==============================================================================
// Wishbone Response Mux
//==============================================================================

wire [31:0] uart_wb_dat_o;
wire        uart_wb_ack_o;
wire        uart_wb_err_o;

wire [31:0] gpio_wb_dat_o;
wire        gpio_wb_ack_o;
wire        gpio_wb_err_o;

wire [31:0] timer_wb_dat_o;
wire        timer_wb_ack_o;
wire        timer_wb_err_o;

wire [31:0] spi_wb_dat_o;
wire        spi_wb_ack_o;
wire        spi_wb_err_o;

assign wb_dat_o = uart_sel ? uart_wb_dat_o :
                  gpio_sel ? gpio_wb_dat_o :
                  timer_sel ? timer_wb_dat_o :
                  spi_sel ? spi_wb_dat_o :
                  32'h00000000;

assign wb_ack_o = uart_sel ? uart_wb_ack_o :
                  gpio_sel ? gpio_wb_ack_o :
                  timer_sel ? timer_wb_ack_o :
                  spi_sel ? spi_wb_ack_o :
                  1'b0;

assign wb_err_o = uart_sel ? uart_wb_err_o :
                  gpio_sel ? gpio_wb_err_o :
                  timer_sel ? timer_wb_err_o :
                  spi_sel ? spi_wb_err_o :
                  1'b0;

//==============================================================================
// UART Module
//==============================================================================

wire uart_irq;

uart_core u_uart (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (uart_sel ? wb_adr_i[7:0] : 8'h0),
    .wb_dat_o       (uart_wb_dat_o),
    .wb_dat_i       (uart_sel ? wb_dat_i : 32'h0),
    .wb_we_i        (uart_sel ? wb_we_i : 1'b0),
    .wb_sel_i       (uart_sel ? wb_sel_i : 4'h0),
    .wb_cyc_i       (uart_sel ? wb_cyc_i : 1'b0),
    .wb_stb_i       (uart_sel ? wb_stb_i : 1'b0),
    .wb_ack_o       (uart_wb_ack_o),
    .wb_err_o       (uart_wb_err_o),
    
    // UART signals
    .uart_tx        (uart_tx),
    .uart_rx        (uart_rx),
    
    // Interrupt
    .irq            (uart_irq)
);

//==============================================================================
// GPIO Module
//==============================================================================

wire gpio_irq;

gpio_core u_gpio (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (gpio_sel ? wb_adr_i[7:0] : 8'h0),
    .wb_dat_o       (gpio_wb_dat_o),
    .wb_dat_i       (gpio_sel ? wb_dat_i : 32'h0),
    .wb_we_i        (gpio_sel ? wb_we_i : 1'b0),
    .wb_sel_i       (gpio_sel ? wb_sel_i : 4'h0),
    .wb_cyc_i       (gpio_sel ? wb_cyc_i : 1'b0),
    .wb_stb_i       (gpio_sel ? wb_stb_i : 1'b0),
    .wb_ack_o       (gpio_wb_ack_o),
    .wb_err_o       (gpio_wb_err_o),
    
    // GPIO signals
    .gpio           (gpio),
    
    // Interrupt
    .irq            (gpio_irq)
);

//==============================================================================
// Timer Module
//==============================================================================

timer_core u_timer (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (timer_sel ? wb_adr_i[7:0] : 8'h0),
    .wb_dat_o       (timer_wb_dat_o),
    .wb_dat_i       (timer_sel ? wb_dat_i : 32'h0),
    .wb_we_i        (timer_sel ? wb_we_i : 1'b0),
    .wb_sel_i       (timer_sel ? wb_sel_i : 4'h0),
    .wb_cyc_i       (timer_sel ? wb_cyc_i : 1'b0),
    .wb_stb_i       (timer_sel ? wb_stb_i : 1'b0),
    .wb_ack_o       (timer_wb_ack_o),
    .wb_err_o       (timer_wb_err_o),
    
    // Timer outputs
    .timer_interrupt (timer_interrupt),
    .compare_out     (timer_compare_out)
);

//==============================================================================
// SPI Module
//==============================================================================

wire spi_irq;

spi_core u_spi (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Wishbone interface
    .wb_adr_i       (spi_sel ? wb_adr_i[7:0] : 8'h0),
    .wb_dat_o       (spi_wb_dat_o),
    .wb_dat_i       (spi_sel ? wb_dat_i : 32'h0),
    .wb_we_i        (spi_sel ? wb_we_i : 1'b0),
    .wb_sel_i       (spi_sel ? wb_sel_i : 4'h0),
    .wb_cyc_i       (spi_sel ? wb_cyc_i : 1'b0),
    .wb_stb_i       (spi_sel ? wb_stb_i : 1'b0),
    .wb_ack_o       (spi_wb_ack_o),
    .wb_err_o       (spi_wb_err_o),
    
    // SPI signals
    .spi_sclk       (spi_sclk),
    .spi_mosi       (spi_mosi),
    .spi_miso       (spi_miso),
    .spi_cs_n       (spi_cs_n),
    
    // Interrupt
    .irq            (spi_irq)
);

//==============================================================================
// Interrupt Combination
//==============================================================================

assign irq = uart_irq || gpio_irq || timer_interrupt || spi_irq;

//==============================================================================
// Status Register
//==============================================================================

assign comm_status = {
    16'h0000,           // [31:16] Reserved
    4'h0,               // [15:12] Reserved
    spi_irq,            // [11] SPI interrupt
    timer_interrupt,    // [10] Timer interrupt
    gpio_irq,           // [9] GPIO interrupt  
    uart_irq,           // [8] UART interrupt
    timer_compare_out,  // [7:4] Timer compare outputs
    2'b00,              // [3:2] Reserved
    uart_tx,            // [1] UART TX state
    spi_cs_n            // [0] SPI chip select state
};

endmodule

//==============================================================================
// UART Core Implementation
//==============================================================================

module uart_core (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] wb_adr_i,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    input  wire wb_we_i,
    input  wire [3:0] wb_sel_i,
    input  wire wb_cyc_i,
    input  wire wb_stb_i,
    output reg  wb_ack_o,
    output wire wb_err_o,
    output wire uart_tx,
    input  wire uart_rx,
    output reg  irq
);

// UART registers
reg [31:0] control_reg;
reg [31:0] baud_div_reg;
reg [31:0] status_reg;
reg [7:0] tx_data_reg;
reg [7:0] rx_data_reg;

// UART implementation (simplified)
reg [15:0] baud_counter;
reg [3:0] bit_counter;
reg [9:0] tx_shift_reg;
reg [9:0] rx_shift_reg;
reg tx_busy, rx_busy;
reg tx_start, rx_start;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'h0;
        control_reg <= 32'h0;
        baud_div_reg <= 32'd434; // 115200 baud default
        irq <= 1'b0;
    end else begin
        wb_ack_o <= wb_cyc_i && wb_stb_i;
        if (wb_cyc_i && wb_stb_i && wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: control_reg <= wb_dat_i;
                6'h01: baud_div_reg <= wb_dat_i;
                6'h03: tx_data_reg <= wb_dat_i[7:0];
            endcase
        end else if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: wb_dat_o <= control_reg;
                6'h01: wb_dat_o <= baud_div_reg;
                6'h02: wb_dat_o <= status_reg;
                6'h03: wb_dat_o <= {24'h0, rx_data_reg};
                default: wb_dat_o <= 32'h0;
            endcase
        end
    end
end

assign wb_err_o = 1'b0;
assign uart_tx = tx_shift_reg[0];

endmodule

//==============================================================================
// GPIO Core Implementation
//==============================================================================

module gpio_core (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] wb_adr_i,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    input  wire wb_we_i,
    input  wire [3:0] wb_sel_i,
    input  wire wb_cyc_i,
    input  wire wb_stb_i,
    output reg  wb_ack_o,
    output wire wb_err_o,
    inout  wire [15:0] gpio,
    output reg  irq
);

reg [15:0] gpio_out_reg;
reg [15:0] gpio_dir_reg; // 1=output, 0=input
reg [15:0] gpio_in_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'h0;
        gpio_out_reg <= 16'h0;
        gpio_dir_reg <= 16'h0;
        irq <= 1'b0;
    end else begin
        wb_ack_o <= wb_cyc_i && wb_stb_i;
        gpio_in_reg <= gpio;
        
        if (wb_cyc_i && wb_stb_i && wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: gpio_out_reg <= wb_dat_i[15:0];
                6'h01: gpio_dir_reg <= wb_dat_i[15:0];
            endcase
        end else if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: wb_dat_o <= {16'h0, gpio_out_reg};
                6'h01: wb_dat_o <= {16'h0, gpio_dir_reg};
                6'h02: wb_dat_o <= {16'h0, gpio_in_reg};
                default: wb_dat_o <= 32'h0;
            endcase
        end
    end
end

assign wb_err_o = 1'b0;
genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : gpio_bidir
        assign gpio[i] = gpio_dir_reg[i] ? gpio_out_reg[i] : 1'bz;
    end
endgenerate

endmodule

//==============================================================================
// Timer Core Implementation
//==============================================================================

module timer_core (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] wb_adr_i,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    input  wire wb_we_i,
    input  wire [3:0] wb_sel_i,
    input  wire wb_cyc_i,
    input  wire wb_stb_i,
    output reg  wb_ack_o,
    output wire wb_err_o,
    output reg  timer_interrupt,
    output reg  [3:0] compare_out
);

reg [31:0] timer_counter;
reg [31:0] timer_period;
reg [31:0] compare_val [0:3];
reg [31:0] control_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'h0;
        timer_counter <= 32'h0;
        timer_period <= 32'hFFFFFFFF;
        timer_interrupt <= 1'b0;
        compare_out <= 4'h0;
        control_reg <= 32'h0;
    end else begin
        wb_ack_o <= wb_cyc_i && wb_stb_i;
        
        // Timer counting
        if (control_reg[0]) begin // Timer enable
            if (timer_counter >= timer_period) begin
                timer_counter <= 32'h0;
                timer_interrupt <= 1'b1;
            end else begin
                timer_counter <= timer_counter + 1;
            end
            
            // Compare outputs
            for (integer i = 0; i < 4; i = i + 1) begin
                compare_out[i] <= (timer_counter >= compare_val[i]);
            end
        end
        
        if (wb_cyc_i && wb_stb_i && wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: control_reg <= wb_dat_i;
                6'h01: timer_period <= wb_dat_i;
                6'h03: compare_val[0] <= wb_dat_i;
                6'h04: compare_val[1] <= wb_dat_i;
                6'h05: compare_val[2] <= wb_dat_i;
                6'h06: compare_val[3] <= wb_dat_i;
            endcase
        end else if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: wb_dat_o <= control_reg;
                6'h01: wb_dat_o <= timer_period;
                6'h02: wb_dat_o <= timer_counter;
                6'h03: wb_dat_o <= compare_val[0];
                6'h04: wb_dat_o <= compare_val[1];
                6'h05: wb_dat_o <= compare_val[2];
                6'h06: wb_dat_o <= compare_val[3];
                default: wb_dat_o <= 32'h0;
            endcase
        end
    end
end

assign wb_err_o = 1'b0;

endmodule

//==============================================================================
// SPI Core Implementation  
//==============================================================================

module spi_core (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] wb_adr_i,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    input  wire wb_we_i,
    input  wire [3:0] wb_sel_i,
    input  wire wb_cyc_i,
    input  wire wb_stb_i,
    output reg  wb_ack_o,
    output wire wb_err_o,
    output reg  spi_sclk,
    output reg  spi_mosi,
    input  wire spi_miso,
    output reg  spi_cs_n,
    output reg  irq
);

reg [31:0] control_reg;
reg [7:0] tx_data;
reg [7:0] rx_data;
reg [7:0] shift_reg;
reg [3:0] bit_count;
reg spi_busy;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'h0;
        spi_cs_n <= 1'b1;
        spi_sclk <= 1'b0;
        spi_mosi <= 1'b0;
        control_reg <= 32'h0;
        irq <= 1'b0;
    end else begin
        wb_ack_o <= wb_cyc_i && wb_stb_i;
        
        if (wb_cyc_i && wb_stb_i && wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: control_reg <= wb_dat_i;
                6'h02: tx_data <= wb_dat_i[7:0];
            endcase
        end else if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[7:2])
                6'h00: wb_dat_o <= control_reg;
                6'h01: wb_dat_o <= {24'h0, rx_data};
                6'h02: wb_dat_o <= {24'h0, tx_data};
                default: wb_dat_o <= 32'h0;
            endcase
        end
    end
end

assign wb_err_o = 1'b0;

endmodule