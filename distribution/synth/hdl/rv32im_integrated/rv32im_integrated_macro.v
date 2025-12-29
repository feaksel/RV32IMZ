/**
 * @file rv32im_integrated_macro.v
 * @brief Complete RV32IM Core - Single Integrated IP Macro
 *
 * This macro hierarchically integrates TWO pre-built macros:
 * 1. core_macro - The RV32I pipeline with external MDU interface
 * 2. mdu_macro - The multiply/divide unit
 *
 * These are wired together to create a single RV32IM IP block.
 * Both sub-macros are synthesized separately, then this wrapper
 * places and routes them together as a single deliverable.
 *
 * IMPORTANT: No parameters - sub-macros are pre-built netlists!
 * RESET_VECTOR was set when core_macro was originally built.
 *
 * Target: SKY130 technology, optimized for timing closure
 * Estimated: ~11,000-14,000 cells (core 8K + MDU 3K)
 *
 * @author Custom RISC-V Core Team
 * @date 2025-12-20
 * @version 2.1 - Fixed for black box integration (no parameters)
 */

module rv32im_integrated_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    //==========================================================================
    // Instruction Wishbone Bus (Master)
    //==========================================================================

    output wire [31:0] iwb_adr_o,   // Instruction address
    input  wire [31:0] iwb_dat_i,   // Instruction data from memory
    output wire        iwb_cyc_o,   // Cycle active
    output wire        iwb_stb_o,   // Strobe
    input  wire        iwb_ack_i,   // Acknowledge

    //==========================================================================
    // Data Wishbone Bus (Master)
    //==========================================================================

    output wire [31:0] dwb_adr_o,   // Data address
    output wire [31:0] dwb_dat_o,   // Data to write
    input  wire [31:0] dwb_dat_i,   // Data read from memory/peripheral
    output wire        dwb_we_o,    // Write enable (1=write, 0=read)
    output wire [3:0]  dwb_sel_o,   // Byte select
    output wire        dwb_cyc_o,   // Cycle active
    output wire        dwb_stb_o,   // Strobe
    input  wire        dwb_ack_i,   // Acknowledge
    input  wire        dwb_err_i,   // Error

    //==========================================================================
    // System Interface
    //==========================================================================

    input  wire [31:0] interrupts
);

    //==========================================================================
    // Internal MDU Interface Signals (between core and MDU macros)
    //==========================================================================

    wire        mdu_start;
    wire        mdu_ack;
    wire [2:0]  mdu_funct3;
    wire [31:0] mdu_operand_a;
    wire [31:0] mdu_operand_b;
    wire        mdu_busy;
    wire        mdu_done;
    wire [63:0] mdu_product;
    wire [31:0] mdu_quotient;
    wire [31:0] mdu_remainder;

    //==========================================================================
    // Core Macro Instantiation (pre-built macro - black box)
    // NOTE: Parameters cannot be passed to pre-built netlists!
    //       RESET_VECTOR was set when core_macro was built separately.
    //==========================================================================

    core_macro u_core_macro (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Instruction Wishbone Bus
        .iwb_adr_o          (iwb_adr_o),
        .iwb_dat_i          (iwb_dat_i),
        .iwb_cyc_o          (iwb_cyc_o),
        .iwb_stb_o          (iwb_stb_o),
        .iwb_ack_i          (iwb_ack_i),
        
        // Data Wishbone Bus
        .dwb_adr_o          (dwb_adr_o),
        .dwb_dat_o          (dwb_dat_o),
        .dwb_dat_i          (dwb_dat_i),
        .dwb_we_o           (dwb_we_o),
        .dwb_sel_o          (dwb_sel_o),
        .dwb_cyc_o          (dwb_cyc_o),
        .dwb_stb_o          (dwb_stb_o),
        .dwb_ack_i          (dwb_ack_i),
        .dwb_err_i          (dwb_err_i),
        
        // MDU Interface (connected to MDU macro below)
        .mdu_start          (mdu_start),
        .mdu_ack            (mdu_ack),
        .mdu_funct3         (mdu_funct3),
        .mdu_operand_a      (mdu_operand_a),
        .mdu_operand_b      (mdu_operand_b),
        .mdu_busy           (mdu_busy),
        .mdu_done           (mdu_done),
        .mdu_product        (mdu_product),
        .mdu_quotient       (mdu_quotient),
        .mdu_remainder      (mdu_remainder),
        
        // Interrupts
        .interrupts         (interrupts)
    );

    //==========================================================================
    // MDU Macro Instantiation (pre-built macro - black box)
    //==========================================================================

    mdu_macro u_mdu_macro (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Control Interface
        .start              (mdu_start),
        .ack                (mdu_ack),
        .funct3             (mdu_funct3),
        
        // Data Interface
        .operand_a          (mdu_operand_a),
        .operand_b          (mdu_operand_b),
        
        // Status and Results
        .busy               (mdu_busy),
        .done               (mdu_done),
        .product            (mdu_product),
        .quotient           (mdu_quotient),
        .remainder          (mdu_remainder)
    );

endmodule
