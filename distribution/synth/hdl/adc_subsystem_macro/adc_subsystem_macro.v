// ADC Subsystem Macro: 4-channel Σ-Δ ADC + filters
// Sigma-Delta ADC with digital filtering
// Target: ~4K cells, 70×70μm

module adc_subsystem_macro (
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
    
    // ADC analog inputs
    input  wire [3:0] adc_data_in,
    output wire [3:0] adc_clk_out,
    
    // Filtered digital outputs
    output wire [15:0] ch0_data,
    output wire [15:0] ch1_data,
    output wire [15:0] ch2_data,
    output wire [15:0] ch3_data,
    output wire [3:0]  data_valid,
    
    // Interrupt
    output wire irq,
    
    // Status
    output wire [31:0] adc_status
);

//==============================================================================
// Register Map  
//==============================================================================
// 0x00: Control Register
// 0x04: Status Register
// 0x08: Channel 0 Configuration
// 0x0C: Channel 1 Configuration
// 0x10: Channel 2 Configuration
// 0x14: Channel 3 Configuration
// 0x18: Channel 0 Data
// 0x1C: Channel 1 Data
// 0x20: Channel 2 Data
// 0x24: Channel 3 Data
// 0x28: Interrupt Enable
// 0x2C: Interrupt Status

//==============================================================================
// Configuration Registers
//==============================================================================

reg [31:0] control_reg;
reg [31:0] ch_config [0:3];
reg [31:0] int_enable;
reg [31:0] int_status;

wire adc_enable = control_reg[0];
wire [1:0] decimation_rate = control_reg[3:2]; // 00=64, 01=128, 10=256, 11=512
wire auto_scan = control_reg[4];
wire [1:0] current_channel = control_reg[7:6];

//==============================================================================
// Wishbone Interface
//==============================================================================

reg wb_ack_reg;
reg [31:0] wb_dat_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_ack_reg <= 1'b0;
        wb_dat_reg <= 32'h0;
        control_reg <= 32'h0;
        int_enable <= 32'h0;
        int_status <= 32'h0;
        
        // Initialize channel configurations
        for (integer i = 0; i < 4; i = i + 1) begin
            ch_config[i] <= 32'h0000_0040; // Default decimation = 64
        end
    end else begin
        wb_ack_reg <= wb_cyc_i && wb_stb_i;
        
        if (wb_cyc_i && wb_stb_i) begin
            if (wb_we_i) begin
                // Write operation
                case (wb_adr_i[7:2])
                    6'h00: control_reg <= wb_dat_i;
                    6'h02: ch_config[0] <= wb_dat_i;
                    6'h03: ch_config[1] <= wb_dat_i;
                    6'h04: ch_config[2] <= wb_dat_i;
                    6'h05: ch_config[3] <= wb_dat_i;
                    6'h0A: int_enable <= wb_dat_i;
                    6'h0B: int_status <= int_status & ~wb_dat_i; // Clear on write
                endcase
            end else begin
                // Read operation
                case (wb_adr_i[7:2])
                    6'h00: wb_dat_reg <= control_reg;
                    6'h01: wb_dat_reg <= adc_status;
                    6'h02: wb_dat_reg <= ch_config[0];
                    6'h03: wb_dat_reg <= ch_config[1];
                    6'h04: wb_dat_reg <= ch_config[2];
                    6'h05: wb_dat_reg <= ch_config[3];
                    6'h06: wb_dat_reg <= {16'h0000, ch0_data};
                    6'h07: wb_dat_reg <= {16'h0000, ch1_data};
                    6'h08: wb_dat_reg <= {16'h0000, ch2_data};
                    6'h09: wb_dat_reg <= {16'h0000, ch3_data};
                    6'h0A: wb_dat_reg <= int_enable;
                    6'h0B: wb_dat_reg <= int_status;
                    default: wb_dat_reg <= 32'h00000000;
                endcase
            end
        end
    end
end

assign wb_ack_o = wb_ack_reg;
assign wb_err_o = 1'b0;
assign wb_dat_o = wb_dat_reg;

//==============================================================================
// Sigma-Delta Modulator Clock Generation
//==============================================================================

reg [7:0] clk_divider;
reg [3:0] adc_clk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_divider <= 8'h0;
        adc_clk <= 4'h0;
    end else if (adc_enable) begin
        clk_divider <= clk_divider + 1;
        if (clk_divider[3:0] == 4'hF) begin // Divide by 16
            adc_clk <= ~adc_clk;
        end
    end else begin
        adc_clk <= 4'h0;
    end
end

assign adc_clk_out = adc_clk;

//==============================================================================
// Digital Filters (CIC + FIR)
//==============================================================================

// Channel data storage
reg [15:0] channel_data [0:3];
reg [3:0] data_ready;

genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : adc_channel
        
        // Sigma-Delta bit stream integration (CIC filter)
        reg [31:0] integrator1, integrator2, integrator3;
        reg [31:0] comb1, comb2, comb3;
        reg [31:0] comb1_d1, comb2_d1, comb3_d1;
        
        // Decimation counter
        reg [8:0] decimation_count;
        wire [8:0] decimation_target = (decimation_rate == 2'b00) ? 9'd63 :
                                      (decimation_rate == 2'b01) ? 9'd127 :
                                      (decimation_rate == 2'b10) ? 9'd255 : 9'd511;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                integrator1 <= 32'h0;
                integrator2 <= 32'h0;
                integrator3 <= 32'h0;
                comb1 <= 32'h0;
                comb2 <= 32'h0;
                comb3 <= 32'h0;
                comb1_d1 <= 32'h0;
                comb2_d1 <= 32'h0;
                comb3_d1 <= 32'h0;
                decimation_count <= 9'h0;
                channel_data[i] <= 16'h0;
                data_ready[i] <= 1'b0;
            end else if (adc_enable && adc_clk[i]) begin
                // CIC Integrator stages
                integrator1 <= integrator1 + {31'h0, adc_data_in[i]};
                integrator2 <= integrator2 + integrator1;
                integrator3 <= integrator3 + integrator2;
                
                // Decimation
                if (decimation_count >= decimation_target) begin
                    decimation_count <= 9'h0;
                    
                    // CIC Comb stages
                    comb1 <= integrator3 - comb1_d1;
                    comb1_d1 <= integrator3;
                    
                    comb2 <= comb1 - comb2_d1;
                    comb2_d1 <= comb1;
                    
                    comb3 <= comb2 - comb3_d1;
                    comb3_d1 <= comb2;
                    
                    // Scale and output (take middle 16 bits)
                    channel_data[i] <= comb3[23:8];
                    data_ready[i] <= 1'b1;
                    
                    // Generate interrupt
                    int_status[i] <= 1'b1;
                end else begin
                    decimation_count <= decimation_count + 1;
                    data_ready[i] <= 1'b0;
                end
            end else begin
                data_ready[i] <= 1'b0;
            end
        end
    end
endgenerate

//==============================================================================
// Output Assignment
//==============================================================================

assign ch0_data = channel_data[0];
assign ch1_data = channel_data[1];
assign ch2_data = channel_data[2];
assign ch3_data = channel_data[3];
assign data_valid = data_ready;

//==============================================================================
// Interrupt Generation
//==============================================================================

assign irq = |(int_status & int_enable);

//==============================================================================
// Status Register
//==============================================================================

// Combine data_ready signals into a vector
wire [3:0] data_ready_vec = data_ready;

assign adc_status = {
    16'h0000,           // [31:16] Reserved
    4'h0,               // [15:12] Reserved
    data_ready_vec,     // [11:8] Data ready flags
    2'b00,              // [7:6] Reserved
    current_channel,    // [5:4] Current channel
    2'b00,              // [3:2] Reserved  
    decimation_rate     // [1:0] Decimation rate
};

endmodule