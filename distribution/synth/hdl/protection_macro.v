// Protection Macro: OCP/OVP + watchdog
// Overcurrent/overvoltage protection and system watchdog
// Target: ~1K cells, 40×40μm

module protection_macro (
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
    
    // Protection inputs
    input  wire [3:0] current_sense,    // Current sense inputs
    input  wire [3:0] voltage_sense,    // Voltage sense inputs  
    input  wire       thermal_alert,    // Thermal alert input
    
    // Protection outputs
    output wire       emergency_stop,   // Emergency shutdown
    output wire [3:0] channel_disable,  // Individual channel disable
    output wire       system_reset,     // Forced system reset
    
    // Watchdog
    input  wire       watchdog_kick,    // Watchdog kick signal
    output wire       watchdog_timeout, // Watchdog timeout
    
    // Interrupt
    output wire       irq,
    
    // Status
    output wire [31:0] protection_status
);

//==============================================================================
// Register Map
//==============================================================================
// 0x00: Control Register
// 0x04: Status Register  
// 0x08: Current Threshold Register
// 0x0C: Voltage Threshold Register
// 0x10: Watchdog Control
// 0x14: Interrupt Enable
// 0x18: Interrupt Status
// 0x1C: Protection Event Log

//==============================================================================
// Configuration Registers
//==============================================================================

reg [31:0] control_reg;
reg [31:0] current_threshold;
reg [31:0] voltage_threshold;
reg [31:0] watchdog_control;
reg [31:0] int_enable;
reg [31:0] int_status;
reg [31:0] event_log;

wire protection_enable = control_reg[0];
wire watchdog_enable = control_reg[1];
wire auto_recovery = control_reg[2];
wire thermal_protection_enable = control_reg[3];

//==============================================================================
// Wishbone Interface
//==============================================================================

reg wb_ack_reg;
reg [31:0] wb_dat_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_ack_reg <= 1'b0;
        wb_dat_reg <= 32'h0;
        control_reg <= 32'h0000_000F; // All protections enabled by default
        current_threshold <= 32'h0000_0800; // Default current threshold
        voltage_threshold <= 32'h0000_0C00; // Default voltage threshold  
        watchdog_control <= 32'h0001_0000; // 64K cycle default timeout
        int_enable <= 32'h0;
        int_status <= 32'h0;
        event_log <= 32'h0;
    end else begin
        wb_ack_reg <= wb_cyc_i && wb_stb_i;
        
        if (wb_cyc_i && wb_stb_i) begin
            if (wb_we_i) begin
                // Write operation
                case (wb_adr_i[7:2])
                    6'h00: control_reg <= wb_dat_i;
                    6'h02: current_threshold <= wb_dat_i;
                    6'h03: voltage_threshold <= wb_dat_i;
                    6'h04: watchdog_control <= wb_dat_i;
                    6'h05: int_enable <= wb_dat_i;
                    6'h06: int_status <= int_status & ~wb_dat_i; // Clear on write
                    6'h07: if (wb_dat_i[0]) event_log <= 32'h0; // Clear event log
                endcase
            end else begin
                // Read operation
                case (wb_adr_i[7:2])
                    6'h00: wb_dat_reg <= control_reg;
                    6'h01: wb_dat_reg <= protection_status;
                    6'h02: wb_dat_reg <= current_threshold;
                    6'h03: wb_dat_reg <= voltage_threshold;
                    6'h04: wb_dat_reg <= watchdog_control;
                    6'h05: wb_dat_reg <= int_enable;
                    6'h06: wb_dat_reg <= int_status;
                    6'h07: wb_dat_reg <= event_log;
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
// Current Protection
//==============================================================================

reg [3:0] current_fault;
reg [3:0] current_fault_latched;

genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : current_protection
        
        // Convert sense input to digital value (simplified)
        reg [11:0] current_digital;
        always @(posedge clk) begin
            // Simulate ADC conversion of current sense
            current_digital <= {8'h00, current_sense[i], 3'b000}; // Simple scaling
        end
        
        // Current fault detection
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                current_fault[i] <= 1'b0;
                current_fault_latched[i] <= 1'b0;
            end else if (protection_enable) begin
                if (current_digital > current_threshold[11:0]) begin
                    current_fault[i] <= 1'b1;
                    current_fault_latched[i] <= 1'b1;
                    // Log the event
                    event_log[i] <= 1'b1;
                    // Generate interrupt
                    int_status[i] <= 1'b1;
                end else if (auto_recovery && current_digital < (current_threshold[11:0] >> 1)) begin
                    current_fault[i] <= 1'b0;
                    // Keep latched fault until manually cleared
                end
            end
        end
    end
endgenerate

//==============================================================================
// Voltage Protection
//==============================================================================

reg [3:0] voltage_fault;
reg [3:0] voltage_fault_latched;

generate
    for (i = 0; i < 4; i = i + 1) begin : voltage_protection
        
        // Convert sense input to digital value
        reg [11:0] voltage_digital;
        always @(posedge clk) begin
            voltage_digital <= {8'h00, voltage_sense[i], 3'b000};
        end
        
        // Voltage fault detection (overvoltage)
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                voltage_fault[i] <= 1'b0;
                voltage_fault_latched[i] <= 1'b0;
            end else if (protection_enable) begin
                if (voltage_digital > voltage_threshold[11:0]) begin
                    voltage_fault[i] <= 1'b1;
                    voltage_fault_latched[i] <= 1'b1;
                    // Log the event
                    event_log[i + 4] <= 1'b1;
                    // Generate interrupt
                    int_status[i + 4] <= 1'b1;
                end else if (auto_recovery && voltage_digital < (voltage_threshold[11:0] - 12'h100)) begin
                    voltage_fault[i] <= 1'b0;
                end
            end
        end
    end
endgenerate

//==============================================================================
// Thermal Protection
//==============================================================================

reg thermal_fault;
reg thermal_fault_latched;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        thermal_fault <= 1'b0;
        thermal_fault_latched <= 1'b0;
    end else if (thermal_protection_enable) begin
        if (thermal_alert) begin
            thermal_fault <= 1'b1;
            thermal_fault_latched <= 1'b1;
            event_log[8] <= 1'b1;
            int_status[8] <= 1'b1;
        end else if (auto_recovery) begin
            thermal_fault <= 1'b0;
        end
    end
end

//==============================================================================
// Watchdog Timer
//==============================================================================

reg [31:0] watchdog_counter;
reg watchdog_fault;
reg watchdog_kicked;
wire [31:0] watchdog_timeout_val = watchdog_control[31:16];

// Synchronize watchdog kick
reg [2:0] kick_sync;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        kick_sync <= 3'b000;
    end else begin
        kick_sync <= {kick_sync[1:0], watchdog_kick};
    end
end

wire kick_pulse = kick_sync[1] && !kick_sync[2];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        watchdog_counter <= 32'h0;
        watchdog_fault <= 1'b0;
        watchdog_kicked <= 1'b0;
    end else if (watchdog_enable) begin
        if (kick_pulse) begin
            watchdog_counter <= 32'h0;
            watchdog_kicked <= 1'b1;
            watchdog_fault <= 1'b0;
        end else if (watchdog_counter >= watchdog_timeout_val) begin
            watchdog_fault <= 1'b1;
            event_log[9] <= 1'b1;
            int_status[9] <= 1'b1;
        end else begin
            watchdog_counter <= watchdog_counter + 1;
        end
    end else begin
        watchdog_counter <= 32'h0;
        watchdog_fault <= 1'b0;
    end
end

assign watchdog_timeout = watchdog_fault;

//==============================================================================
// Protection Decision Logic
//==============================================================================

wire any_current_fault = |current_fault;
wire any_voltage_fault = |voltage_fault;
wire any_fault = any_current_fault || any_voltage_fault || thermal_fault || watchdog_fault;

// Emergency stop - immediate shutdown for critical faults
assign emergency_stop = (any_current_fault && current_threshold[31]) || // Critical current flag
                       (thermal_fault && thermal_protection_enable) ||
                       watchdog_fault;

// Individual channel disable
assign channel_disable = current_fault | voltage_fault | {4{thermal_fault}};

// System reset for severe faults
assign system_reset = watchdog_fault || (thermal_fault && control_reg[4]);

//==============================================================================
// Interrupt Generation
//==============================================================================

assign irq = |(int_status & int_enable);

//==============================================================================
// Status Register
//==============================================================================

assign protection_status = {
    8'h00,                      // [31:24] Reserved
    watchdog_counter[23:16],    // [23:16] Watchdog counter (high bits)
    4'h0,                       // [15:12] Reserved
    voltage_fault,              // [11:8] Voltage faults
    current_fault,              // [7:4] Current faults
    1'b0,                       // [3] Reserved
    watchdog_fault,             // [2] Watchdog fault
    thermal_fault,              // [1] Thermal fault
    any_fault                   // [0] Any fault active
};

endmodule