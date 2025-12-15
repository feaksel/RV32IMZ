`include "riscv_defines.vh"

module interrupt_controller (
    input  wire        clk,
    input  wire        rst_n,

    //==========================================================================
    // External Interrupt Inputs
    //==========================================================================

    input  wire        timer_int,       // Timer interrupt (highest priority)
    input  wire        external_int,    // External interrupt
    input  wire        software_int,    // Software interrupt (lowest priority)
    input  wire [15:0] peripheral_ints, // Additional peripheral interrupts

    //==========================================================================
    // From CSR Unit
    //==========================================================================

    input  wire        global_int_en,   // mstatus.MIE
    input  wire [31:0] mie,             // Which interrupts are enabled

    //==========================================================================
    // To CSR Unit
    //==========================================================================

    output reg  [31:0] interrupt_lines, // Interrupt request lines

    //==========================================================================
    // To Core
    //==========================================================================

    output reg         interrupt_req,   // Interrupt request to core
    output reg  [31:0] interrupt_cause  // Which interrupt (for mcause)
);

    // Standard RISC-V interrupt bit positions:
    // Bit 3:  Machine software interrupt
    // Bit 7:  Machine timer interrupt
    // Bit 11: Machine external interrupt
    // Bits 16-31: Custom/platform-specific

    always @(*) begin
        // Combine all interrupt sources into interrupt_lines
        interrupt_lines = 32'h0;
        interrupt_lines[3]  = software_int;
        interrupt_lines[7]  = timer_int;
        interrupt_lines[11] = external_int;
        interrupt_lines[31:16] = peripheral_ints;
    end

    // Determine which interrupts are both pending and enabled
    wire [31:0] pending_and_enabled = interrupt_lines & mie;

    // Priority encoder: select highest priority interrupt
    always @(*) begin
        interrupt_req = 1'b0;
        interrupt_cause = 32'h0;

        if (global_int_en && (|pending_and_enabled)) begin
            interrupt_req = 1'b1;

            // Priority order (high to low):
            // 1. Machine external interrupt (bit 11)
            // 2. Machine software interrupt (bit 3)
            // 3. Machine timer interrupt (bit 7)
            // 4. Platform-specific (bits 16-31)

            if (pending_and_enabled[11]) begin
                interrupt_cause = `MCAUSE_EXTERNAL_INT;  // 0x8000000B
            end else if (pending_and_enabled[3]) begin
                interrupt_cause = `MCAUSE_SOFTWARE_INT;  // 0x80000003
            end else if (pending_and_enabled[7]) begin
                interrupt_cause = `MCAUSE_TIMER_INT;     // 0x80000007
            end else begin
                // Find first set bit in platform-specific range
                integer i;
                for (i = 31; i >= 16; i = i - 1) begin
                    if (pending_and_enabled[i]) begin
                        interrupt_cause = 32'h80000000 | i;
                        i=-1; // Break the loop
                    end
                end
            end
        end
    end

endmodule