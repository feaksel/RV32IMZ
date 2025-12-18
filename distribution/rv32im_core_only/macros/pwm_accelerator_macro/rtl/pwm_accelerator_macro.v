// PWM Accelerator Macro: 8-channel PWM with dead-time
// High-performance PWM generation for motor control
// Target: ~3K cells, 60×60μm

module pwm_accelerator_macro (
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
    
    // PWM outputs
    output wire [7:0] pwm_out,
    output wire [7:0] pwm_out_n, // Complementary outputs for motor drive
    
    // Interrupt
    output wire irq,
    
    // Status and sync
    output wire pwm_sync_out,
    input  wire pwm_sync_in,
    output wire [31:0] pwm_status
);

//==============================================================================
// Register Map
//==============================================================================
// 0x00: Control Register
// 0x04: Status Register  
// 0x08: Period Register (global)
// 0x0C: Deadtime Register
// 0x10-0x2C: Channel 0-7 Duty Cycle
// 0x30-0x4C: Channel 0-7 Phase Offset
// 0x50: Interrupt Enable
// 0x54: Interrupt Status

//==============================================================================
// Configuration Registers
//==============================================================================

reg [31:0] control_reg;
reg [31:0] period_reg;
reg [31:0] deadtime_reg;
reg [31:0] duty_cycle [0:7];
reg [31:0] phase_offset [0:7];
reg [31:0] int_enable;
reg [31:0] int_status;

wire pwm_enable = control_reg[0];
wire pwm_sync_enable = control_reg[1];
wire complementary_enable = control_reg[2];
wire center_aligned = control_reg[3];

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
        period_reg <= 32'h00000FFF; // Default period
        deadtime_reg <= 32'h00000010; // Default deadtime
        int_enable <= 32'h0;
        int_status <= 32'h0;
        
        // Initialize duty cycles and phases
        for (integer i = 0; i < 8; i = i + 1) begin
            duty_cycle[i] <= 32'h00000000;
            phase_offset[i] <= 32'h00000000;
        end
    end else begin
        wb_ack_reg <= wb_cyc_i && wb_stb_i;
        
        if (wb_cyc_i && wb_stb_i) begin
            if (wb_we_i) begin
                // Write operation
                case (wb_adr_i[7:2])
                    6'h00: control_reg <= wb_dat_i;
                    6'h02: period_reg <= wb_dat_i;
                    6'h03: deadtime_reg <= wb_dat_i;
                    6'h04: duty_cycle[0] <= wb_dat_i;
                    6'h05: duty_cycle[1] <= wb_dat_i;
                    6'h06: duty_cycle[2] <= wb_dat_i;
                    6'h07: duty_cycle[3] <= wb_dat_i;
                    6'h08: duty_cycle[4] <= wb_dat_i;
                    6'h09: duty_cycle[5] <= wb_dat_i;
                    6'h0A: duty_cycle[6] <= wb_dat_i;
                    6'h0B: duty_cycle[7] <= wb_dat_i;
                    6'h0C: phase_offset[0] <= wb_dat_i;
                    6'h0D: phase_offset[1] <= wb_dat_i;
                    6'h0E: phase_offset[2] <= wb_dat_i;
                    6'h0F: phase_offset[3] <= wb_dat_i;
                    6'h10: phase_offset[4] <= wb_dat_i;
                    6'h11: phase_offset[5] <= wb_dat_i;
                    6'h12: phase_offset[6] <= wb_dat_i;
                    6'h13: phase_offset[7] <= wb_dat_i;
                    6'h14: int_enable <= wb_dat_i;
                    6'h15: int_status <= int_status & ~wb_dat_i; // Clear on write
                endcase
            end else begin
                // Read operation
                case (wb_adr_i[7:2])
                    6'h00: wb_dat_reg <= control_reg;
                    6'h01: wb_dat_reg <= pwm_status;
                    6'h02: wb_dat_reg <= period_reg;
                    6'h03: wb_dat_reg <= deadtime_reg;
                    6'h04: wb_dat_reg <= duty_cycle[0];
                    6'h05: wb_dat_reg <= duty_cycle[1];
                    6'h06: wb_dat_reg <= duty_cycle[2];
                    6'h07: wb_dat_reg <= duty_cycle[3];
                    6'h08: wb_dat_reg <= duty_cycle[4];
                    6'h09: wb_dat_reg <= duty_cycle[5];
                    6'h0A: wb_dat_reg <= duty_cycle[6];
                    6'h0B: wb_dat_reg <= duty_cycle[7];
                    6'h0C: wb_dat_reg <= phase_offset[0];
                    6'h0D: wb_dat_reg <= phase_offset[1];
                    6'h0E: wb_dat_reg <= phase_offset[2];
                    6'h0F: wb_dat_reg <= phase_offset[3];
                    6'h10: wb_dat_reg <= phase_offset[4];
                    6'h11: wb_dat_reg <= phase_offset[5];
                    6'h12: wb_dat_reg <= phase_offset[6];
                    6'h13: wb_dat_reg <= phase_offset[7];
                    6'h14: wb_dat_reg <= int_enable;
                    6'h15: wb_dat_reg <= int_status;
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
// PWM Generation Core
//==============================================================================

reg [31:0] main_counter;
reg [31:0] sync_counter;
wire [31:0] effective_period = period_reg;

// Main PWM counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        main_counter <= 32'h0;
        sync_counter <= 32'h0;
    end else if (pwm_enable) begin
        if (pwm_sync_enable && pwm_sync_in) begin
            main_counter <= 32'h0; // External sync reset
        end else if (main_counter >= effective_period) begin
            main_counter <= 32'h0;
        end else begin
            main_counter <= main_counter + 1;
        end
        
        // Sync output generation
        sync_counter <= sync_counter + 1;
    end
end

// Generate PWM outputs for each channel
reg [7:0] pwm_raw;
reg [7:0] pwm_raw_n;

genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : pwm_channel
        wire [31:0] phase_adjusted_counter = main_counter + phase_offset[i];
        wire [31:0] effective_counter = (phase_adjusted_counter >= effective_period) ? 
                                       (phase_adjusted_counter - effective_period) : 
                                       phase_adjusted_counter;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pwm_raw[i] <= 1'b0;
            end else if (pwm_enable) begin
                if (center_aligned) begin
                    // Center-aligned PWM
                    if (effective_counter <= (effective_period >> 1)) begin
                        pwm_raw[i] <= (effective_counter < duty_cycle[i]);
                    end else begin
                        pwm_raw[i] <= ((effective_period - effective_counter) < duty_cycle[i]);
                    end
                end else begin
                    // Edge-aligned PWM
                    pwm_raw[i] <= (effective_counter < duty_cycle[i]);
                end
            end else begin
                pwm_raw[i] <= 1'b0;
            end
        end
    end
endgenerate

//==============================================================================
// Dead-time Generation
//==============================================================================

reg [31:0] deadtime_counter [0:7];
reg [7:0] pwm_delayed;

generate
    for (i = 0; i < 8; i = i + 1) begin : deadtime_gen
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                deadtime_counter[i] <= 32'h0;
                pwm_delayed[i] <= 1'b0;
            end else begin
                if (pwm_raw[i] != pwm_delayed[i]) begin
                    deadtime_counter[i] <= deadtime_reg;
                end else if (deadtime_counter[i] > 0) begin
                    deadtime_counter[i] <= deadtime_counter[i] - 1;
                end
                
                if (deadtime_counter[i] == 0) begin
                    pwm_delayed[i] <= pwm_raw[i];
                end
            end
        end
        
        // Generate complementary outputs with dead-time
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pwm_raw_n[i] <= 1'b0;
            end else if (complementary_enable) begin
                if (deadtime_counter[i] > 0) begin
                    pwm_raw_n[i] <= 1'b0; // Both outputs low during dead-time
                end else begin
                    pwm_raw_n[i] <= ~pwm_delayed[i];
                end
            end else begin
                pwm_raw_n[i] <= 1'b0;
            end
        end
    end
endgenerate

//==============================================================================
// Output Assignment
//==============================================================================

assign pwm_out = pwm_enable ? pwm_delayed : 8'h00;
assign pwm_out_n = pwm_enable ? pwm_raw_n : 8'h00;

// Sync output every period
assign pwm_sync_out = (main_counter == 0) && pwm_enable;

//==============================================================================
// Interrupt Generation
//==============================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        int_status[0] <= 1'b0;
    end else begin
        if (main_counter == 0 && pwm_enable) begin
            int_status[0] <= 1'b1; // Period complete interrupt
        end
    end
end

assign irq = |(int_status & int_enable);

//==============================================================================
// Status Register
//==============================================================================

assign pwm_status = {
    16'h0000,           // [31:16] Reserved
    main_counter[15:0]  // [15:0] Current counter value
};

endmodule