#!/bin/bash

echo "=== Final Division Test ==="

# Create a simple division test 
cat > test_division_final.v << 'EOF'
`timescale 1ns / 1ps

module test_division_final;
    reg clk, rst_n;
    reg start;
    reg [31:0] a, b;
    reg [2:0] funct3;
    
    wire busy, done;
    wire [31:0] quotient, remainder;
    
    // Include the defines
    `define FUNCT3_MUL    3'd0
    `define FUNCT3_MULH   3'd1
    `define FUNCT3_MULHSU 3'd2
    `define FUNCT3_MULHU  3'd3
    `define FUNCT3_DIV    3'd4
    `define FUNCT3_DIVU   3'd5
    `define FUNCT3_REM    3'd6
    `define FUNCT3_REMU   3'd7
    
    mdu uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a(a),
        .b(b),
        .funct3(funct3),
        .busy(busy),
        .done(done),
        .product(),
        .quotient(quotient),
        .remainder(remainder)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    integer test_count = 0;
    
    task run_div_test;
        input [31:0] a_val, b_val;
        input [2:0] op_val;
        input [31:0] expected_q, expected_r;
        begin
            test_count = test_count + 1;
            @(posedge clk);
            a = a_val;
            b = b_val;
            funct3 = op_val;
            start = 1;
            
            @(posedge clk);
            start = 0;
            
            // Wait for completion with timeout
            repeat(100) begin
                @(posedge clk);
                if (done) begin
                    $display("Test %0d: DIV %0d/%0d -> q=%0d r=%0d (expected q=%0d r=%0d) %s", 
                        test_count, $signed(a_val), $signed(b_val), $signed(quotient), $signed(remainder), 
                        $signed(expected_q), $signed(expected_r),
                        (quotient == expected_q && remainder == expected_r) ? "PASS" : "FAIL");
                    disable run_div_test;
                end
            end
            $display("Test %0d: TIMEOUT waiting for division", test_count);
        end
    endtask
    
    initial begin
        $dumpfile("test_division_final.vcd");
        $dumpvars(0, test_division_final);
        
        rst_n = 0;
        start = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("=== Division Unit Tests ===");
        
        // Basic positive division
        run_div_test(32'd20, 32'd4, `FUNCT3_DIV, 32'd5, 32'd0);
        run_div_test(32'd21, 32'd4, `FUNCT3_DIV, 32'd5, 32'd1);
        
        // Negative dividend
        run_div_test(-32'd20, 32'd4, `FUNCT3_DIV, -32'd5, 32'd0);
        run_div_test(-32'd21, 32'd4, `FUNCT3_DIV, -32'd5, -32'd1);
        
        // Basic unsigned
        run_div_test(32'd20, 32'd4, `FUNCT3_DIVU, 32'd5, 32'd0);
        
        repeat(10) @(posedge clk);
        $display("=== Division test complete ===");
        $finish;
    end
endmodule
EOF

echo "Compiling test..."
iverilog -I rtl/core -o test_division_final test_division_final.v rtl/core/mdu.v

if [ $? -eq 0 ]; then
    echo "Running test..."
    ./test_division_final
else
    echo "Compilation failed"
fi

echo "=== Test complete ==="