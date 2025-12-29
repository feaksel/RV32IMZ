module mdu (
	clk, 
	rst_n, 
	start, 
	ack, 
	funct3, 
	a, 
	b, 
	busy, 
	done, 
	product, 
	quotient, 
	remainder);
   input clk;
   input rst_n;
   input start;
   input ack;
   input [2:0] funct3;
   input [31:0] a;
   input [31:0] b;
   output busy;
   output done;
   output [63:0] product;
   output [31:0] quotient;
   output [31:0] remainder;

endmodule
