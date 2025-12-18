// Top-level RV32IM Core with 2-Macro Hierarchical Design
// Integrates MDU macro and Core macro for better timing closure

module rv32im_hierarchical_top (
    input  wire clk,
    input  wire rst_n,
    
    // Instruction Wishbone Bus
    output wire [31:0] iwb_adr_o,
    output wire [31:0] iwb_dat_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_we_o,
    output wire [3:0]  iwb_sel_o,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,
    input  wire        iwb_err_i,
    
    // Data Wishbone Bus
    output wire [31:0] dwb_adr_o,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output wire        dwb_we_o,
    output wire [3:0]  dwb_sel_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,
    input  wire        dwb_err_i,
    
    // Interrupts
    input  wire [15:0] interrupts
);

//==============================================================================
// MDU Interface Signals
//==============================================================================

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

//==============================================================================
// MDU Macro Instantiation
//==============================================================================

mdu_macro u_mdu_macro (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Control Interface
    .start          (mdu_start),
    .ack            (mdu_ack),
    .funct3         (mdu_funct3),
    
    // Data Interface  
    .operand_a      (mdu_operand_a),
    .operand_b      (mdu_operand_b),
    
    // Status and Results
    .busy           (mdu_busy),
    .done           (mdu_done),
    .product        (mdu_product),
    .quotient       (mdu_quotient),
    .remainder      (mdu_remainder)
);

//==============================================================================
// Core Macro Instantiation
//==============================================================================

core_macro u_core_macro (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Instruction Wishbone Bus
    .iwb_adr_o      (iwb_adr_o),
    .iwb_dat_o      (iwb_dat_o),
    .iwb_dat_i      (iwb_dat_i),
    .iwb_we_o       (iwb_we_o),
    .iwb_sel_o      (iwb_sel_o),
    .iwb_cyc_o      (iwb_cyc_o),
    .iwb_stb_o      (iwb_stb_o),
    .iwb_ack_i      (iwb_ack_i),
    .iwb_err_i      (iwb_err_i),
    
    // Data Wishbone Bus
    .dwb_adr_o      (dwb_adr_o),
    .dwb_dat_o      (dwb_dat_o),
    .dwb_dat_i      (dwb_dat_i),
    .dwb_we_o       (dwb_we_o),
    .dwb_sel_o      (dwb_sel_o),
    .dwb_cyc_o      (dwb_cyc_o),
    .dwb_stb_o      (dwb_stb_o),
    .dwb_ack_i      (dwb_ack_i),
    .dwb_err_i      (dwb_err_i),
    
    // MDU Interface
    .mdu_start      (mdu_start),
    .mdu_ack        (mdu_ack),
    .mdu_funct3     (mdu_funct3),
    .mdu_operand_a  (mdu_operand_a),
    .mdu_operand_b  (mdu_operand_b),
    
    .mdu_busy       (mdu_busy),
    .mdu_done       (mdu_done),
    .mdu_product    (mdu_product),
    .mdu_quotient   (mdu_quotient),
    .mdu_remainder  (mdu_remainder),
    
    // Interrupts
    .interrupts     (interrupts)
);

endmodule