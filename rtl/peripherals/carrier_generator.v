/**
 * @file carrier_generator.v
 * @brief Level-Shifted Carrier Generator for 5-Level Inverter
 *
 * Generates 4 triangular carrier waveforms with level-shifting for
 * cascaded H-bridge topology. Each carrier operates in a different
 * voltage range to create 5 distinct output levels.
 *
 * Carrier Ranges (16-bit signed):
 * - Carrier 1: -32768 to 0      (for H-bridge 1, levels -2, -1, 0)
 * - Carrier 2: 0 to +32767      (for H-bridge 2, levels 0, +1, +2)
 *
 * For 2 H-bridges (8 switches) this creates 5 levels: -2, -1, 0, +1, +2
 *
 * @author RISC-V SoC Team
 * @date 2025-12-13
 */

module carrier_generator #(
    parameter CARRIER_WIDTH = 16,
    parameter COUNTER_WIDTH = 16
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         enable,
    input  wire [COUNTER_WIDTH-1:0]     freq_div,        // Frequency divider

    output wire signed [CARRIER_WIDTH-1:0] carrier1,     // -32768 to 0
    output wire signed [CARRIER_WIDTH-1:0] carrier2,     // 0 to +32767
    output wire signed [CARRIER_WIDTH-1:0] carrier3,     // (future expansion)
    output wire signed [CARRIER_WIDTH-1:0] carrier4,     // (future expansion)
    output reg                          sync_pulse       // Pulse at carrier peak
);

    //==========================================================================
    // Counter and Direction
    //==========================================================================

    reg [COUNTER_WIDTH-1:0] freq_counter;
    reg [CARRIER_WIDTH-1:0] carrier_counter;  // Full unsigned range
    reg                     direction;        // 0 = up, 1 = down

    // Carrier frequency clock enable
    wire carrier_clk_en = (freq_counter == freq_div);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_counter <= 0;
        end else if (enable) begin
            if (carrier_clk_en)
                freq_counter <= 0;
            else
                freq_counter <= freq_counter + 1;
        end else begin
            freq_counter <= 0;
        end
    end

    //==========================================================================
    // Triangular Carrier Generation
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            carrier_counter <= 0;
            direction <= 0;
            sync_pulse <= 0;
        end else if (enable && carrier_clk_en) begin
            sync_pulse <= 0;

            if (direction == 0) begin
                // Counting up
                if (carrier_counter == {CARRIER_WIDTH{1'b1}}) begin  // Max value (255 for 8-bit, 65535 for 16-bit)
                    direction <= 1;
                    carrier_counter <= carrier_counter - 1;
                    sync_pulse <= 1;  // Sync pulse at peak
                end else begin
                    carrier_counter <= carrier_counter + 1;
                end
            end else begin
                // Counting down
                if (carrier_counter == 0) begin
                    direction <= 0;
                    carrier_counter <= carrier_counter + 1;
                end else begin
                    carrier_counter <= carrier_counter - 1;
                end
            end
        end else if (!enable) begin
            carrier_counter <= 0;
            direction <= 0;
            sync_pulse <= 0;
        end
    end

    //==========================================================================
    // Level Shifting for Multiple Carriers
    //==========================================================================

    // Base carrier (unsigned, full range)
    wire [CARRIER_WIDTH-1:0] carrier_base = carrier_counter;

    // Half-range offset (2^(CARRIER_WIDTH-1))
    localparam signed [CARRIER_WIDTH-1:0] HALF_RANGE = (1 << (CARRIER_WIDTH-1));

    // Both carriers use same triangular shape (0 to 2^(N-1)-1), but vertically shifted
    wire signed [CARRIER_WIDTH-1:0] carrier_triangle = $signed({1'b0, carrier_base[CARRIER_WIDTH-1:1]});

    // Carrier 1: Negative offset triangular (-2^(N-1) to 0)
    // For 16-bit: 0-32767 offset to -32768 to -1
    // For 8-bit: 0-127 offset to -128 to -1
    assign carrier1 = carrier_triangle - $signed(HALF_RANGE);

    // Carrier 2: Positive triangular (0 to +2^(N-1)-1)
    // For 16-bit: 0 to +32767
    // For 8-bit: 0 to +127
    assign carrier2 = carrier_triangle;

    // Future expansion for 3-cell cascaded H-bridge (9 levels)
    // For now, just copy carrier2 (not used in 2-cell topology)
    assign carrier3 = carrier2;
    assign carrier4 = carrier2;

endmodule
