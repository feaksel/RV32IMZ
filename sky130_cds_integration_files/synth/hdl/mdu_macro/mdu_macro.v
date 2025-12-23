`include "riscv_defines.vh"

/**
 * @file mdu_macro.v
 * @brief MDU Macro for Hierarchical Implementation
 * 
 * This macro wraps the existing MDU module for hierarchical P&R flow.
 * Contains: Multiply/Divide Unit with all operations (MUL/DIV/REM variants)
 * 
 * Target: SKY130 technology, optimized for timing closure
 * Estimated: ~3,000-4,000 cells, 60×60 μm
 * 
 * @author Custom RISC-V Core Team
 * @date 2025-12-18
 * @version 1.0 - Hierarchical Macro Implementation
 */

module mdu_macro (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // MDU Control Interface
    input  wire        start,
    input  wire        ack,
    input  wire [2:0]  funct3,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    
    // MDU Output Interface
    output wire        busy,
    output wire        done,
    output wire [63:0] product,
    output wire [31:0] quotient,
    output wire [31:0] remainder
);

    //==========================================================================
    // Direct instantiation of existing MDU module
    //==========================================================================

    mdu mdu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .ack(ack),
        .funct3(funct3),
        .a(operand_a),
        .b(operand_b),
        .busy(busy),
        .done(done),
        .product(product),
        .quotient(quotient),
        .remainder(remainder)
    );

endmodule