/**
 * @file pwm_comparator.v
 * @brief PWM Comparator with Dead-Time Insertion
 *
 * Compares a reference signal with a triangular carrier to generate
 * complementary PWM outputs with programmable dead-time insertion.
 *
 * Operation:
 * - When reference > carrier: pwm_raw = 1
 * - When reference ≤ carrier: pwm_raw = 0
 * - Dead-time creates a delay between turning off one switch and
 *   turning on the complementary switch to prevent shoot-through
 *
 * Dead-time Insertion:
 * - When transitioning from pwm_high=1 to pwm_high=0:
 *   Both outputs go LOW for 'deadtime' clock cycles
 * - When transitioning from pwm_low=1 to pwm_low=0:
 *   Both outputs go LOW for 'deadtime' clock cycles
 *
 * @author RISC-V SoC Team
 * @date 2025-12-13
 */

module pwm_comparator #(
    parameter DATA_WIDTH = 16
)(
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             enable,
    input  wire signed [DATA_WIDTH-1:0]     reference,    // Modulation reference
    input  wire signed [DATA_WIDTH-1:0]     carrier,      // Triangular carrier
    input  wire [15:0]                      deadtime,     // Dead-time in clock cycles

    output reg                              pwm_high,     // High-side switch
    output reg                              pwm_low       // Low-side switch (complementary)
);

    //==========================================================================
    // PWM Comparison
    //==========================================================================

    // Compare reference with carrier (signed comparison)
    wire pwm_raw = (reference > carrier) ? 1'b1 : 1'b0;

    //==========================================================================
    // Dead-Time State Machine
    //==========================================================================

    reg [15:0] deadtime_counter;
    reg [1:0]  state;

    localparam STATE_BOTH_OFF     = 2'b00;  // Dead-time active, both OFF
    localparam STATE_HIGH_ON      = 2'b01;  // High-side ON, low-side OFF
    localparam STATE_LOW_ON       = 2'b10;  // Low-side ON, high-side OFF
    localparam STATE_TRANSITIONING = 2'b11; // Dead-time transition

    reg pwm_raw_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_high <= 1'b0;
            pwm_low <= 1'b0;
            deadtime_counter <= 16'd0;
            state <= STATE_BOTH_OFF;
            pwm_raw_prev <= 1'b0;
        end else if (!enable) begin
            // Disabled: both outputs OFF
            pwm_high <= 1'b0;
            pwm_low <= 1'b0;
            deadtime_counter <= 16'd0;
            state <= STATE_BOTH_OFF;
            pwm_raw_prev <= 1'b0;
        end else begin
            pwm_raw_prev <= pwm_raw;

            case (state)
                STATE_BOTH_OFF: begin
                    // Both switches OFF (initial state or during dead-time)
                    pwm_high <= 1'b0;
                    pwm_low <= 1'b0;

                    if (deadtime_counter > 0) begin
                        deadtime_counter <= deadtime_counter - 1;
                    end else begin
                        // Dead-time expired, turn on appropriate switch
                        if (pwm_raw) begin
                            state <= STATE_HIGH_ON;
                        end else begin
                            state <= STATE_LOW_ON;
                        end
                    end
                end

                STATE_HIGH_ON: begin
                    // High-side switch ON, low-side OFF
                    pwm_high <= 1'b1;
                    pwm_low <= 1'b0;

                    // Detect falling edge of pwm_raw
                    if (pwm_raw_prev && !pwm_raw) begin
                        // Transition to both OFF for dead-time
                        pwm_high <= 1'b0;
                        deadtime_counter <= deadtime;
                        state <= STATE_BOTH_OFF;
                    end
                end

                STATE_LOW_ON: begin
                    // Low-side switch ON, high-side OFF
                    pwm_high <= 1'b0;
                    pwm_low <= 1'b1;

                    // Detect rising edge of pwm_raw
                    if (!pwm_raw_prev && pwm_raw) begin
                        // Transition to both OFF for dead-time
                        pwm_low <= 1'b0;
                        deadtime_counter <= deadtime;
                        state <= STATE_BOTH_OFF;
                    end
                end

                default: begin
                    state <= STATE_BOTH_OFF;
                    pwm_high <= 1'b0;
                    pwm_low <= 1'b0;
                end
            endcase
        end
    end

endmodule
