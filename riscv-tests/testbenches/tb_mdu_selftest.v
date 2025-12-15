`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_mdu_selftest;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;

    reg start;
    reg [2:0] funct3;
    reg [31:0] a, b;
    wire busy, done;
    wire [63:0] product;
    wire [31:0] quotient, remainder;

    mdu dut (
        .clk(clk), .rst_n(rst_n), .start(start), .funct3(funct3), .a(a), .b(b),
        .busy(busy), .done(done), .product(product), .quotient(quotient), .remainder(remainder)
    );

    task run_op(input [2:0] op, input [31:0] aa, input [31:0] bb);
        begin
            funct3 = op;
            a = aa; b = bb;
            start = 1;
            @(posedge clk);
            start = 0;
            // wait for done pulse
            wait (done == 1);
            @(posedge clk); // allow product to settle
            $display("OP=%0d a=0x%08h b=0x%08h product=0x%016h", op, aa, bb, product);
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #10 rst_n = 1;

        // Test vectors
        run_op(`FUNCT3_MUL, 32'h00000001, 32'h00000001); // 1*1
        run_op(`FUNCT3_MULH, 32'h80000000, 32'h00000001); // -2^31 * 1
        run_op(`FUNCT3_MULHSU, 32'hffffffff, 32'h00000002); // -1 * 2
        run_op(`FUNCT3_MULHU, 32'hffffffff, 32'h00000002); // 0xffffffff * 2 unsigned
        run_op(`FUNCT3_MULHSU, 32'h00000003, 32'h00000007); // 3 * 7
        run_op(`FUNCT3_MULHSU, 32'h00000000, 32'hffff8000); // 0 * 0xffff8000

        $display("MDU selftest done");
        $finish;
    end
endmodule
