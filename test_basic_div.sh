#!/bin/bash
cd /home/furka/RV32IMZ

# Simple test to check if division operations work at all in this environment
cat > test_simple_div.v << 'EOF'
module test_simple_div;
    reg [31:0] a, b, result;
    
    initial begin
        a = 32'd100;
        b = 32'd10;
        
        // Test if basic division works
        result = a / b;
        
        $display("Simple division: %0d / %0d = %0d", a, b, result);
        
        if (result == 32'd10) begin
            $display("PASS: Basic division operator works");
        end else begin
            $display("FAIL: Basic division operator broken");
        end
        
        $finish;
    end
endmodule
EOF

echo "Testing if basic division operators work in this environment..."
iverilog -g2012 -o test_simple_div test_simple_div.v
./test_simple_div

rm -f test_simple_div.v test_simple_div