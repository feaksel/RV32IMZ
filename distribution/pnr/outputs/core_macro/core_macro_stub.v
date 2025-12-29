
module core_macro (
	clk, 
	rst_n, 
	iwb_adr_o, 
	iwb_dat_i, 
	iwb_cyc_o, 
	iwb_stb_o, 
	iwb_ack_i, 
	dwb_adr_o, 
	dwb_dat_o, 
	dwb_dat_i, 
	dwb_we_o, 
	dwb_sel_o, 
	dwb_cyc_o, 
	dwb_stb_o, 
	dwb_ack_i, 
	dwb_err_i, 
	mdu_start, 
	mdu_ack, 
	mdu_funct3, 
	mdu_operand_a, 
	mdu_operand_b, 
	mdu_busy, 
	mdu_done, 
	mdu_product, 
	mdu_quotient, 
	mdu_remainder, 
	interrupts);

   input clk;
   input rst_n;
   output [31:0] iwb_adr_o;
   input [31:0] iwb_dat_i;
   output iwb_cyc_o;
   output iwb_stb_o;
   input iwb_ack_i;
   output [31:0] dwb_adr_o;
   output [31:0] dwb_dat_o;
   input [31:0] dwb_dat_i;
   output dwb_we_o;
   output [3:0] dwb_sel_o;
   output dwb_cyc_o;
   output dwb_stb_o;
   input dwb_ack_i;
   input dwb_err_i;
   output mdu_start;
   output mdu_ack;
   output [2:0] mdu_funct3;
   output [31:0] mdu_operand_a;
   output [31:0] mdu_operand_b;
   input mdu_busy;
   input mdu_done;
   input [63:0] mdu_product;
   input [31:0] mdu_quotient;
   input [31:0] mdu_remainder;
   input [31:0] interrupts;

endmodule
