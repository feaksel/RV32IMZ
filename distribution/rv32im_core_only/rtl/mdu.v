`include "riscv_defines.vh"

module mdu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        ack,        // CPU acknowledges completion
    input  wire [2:0]  funct3,     // operation select (MUL/DIV/REM variants)
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg         busy,
    output reg         done,
    output reg [63:0]  product,
    output reg [31:0]  quotient,
    output reg [31:0]  remainder
);

    // Internal state
    localparam IDLE = 2'd0;
    localparam MUL  = 2'd1;
    localparam DIV  = 2'd2;
    localparam DIV2 = 2'd3;  // Additional state for division completion

    reg [1:0] state;

    // Multiplier internals
    reg [63:0] multiplicand;
    reg [31:0] multiplier;
    reg [63:0] acc;
    reg [5:0]  mul_count;
    reg        mul_sign;

    // Division algorithm internals
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient_reg;
    reg [32:0] remainder_reg;  // 33-bit for overflow detection
    reg [5:0]  div_count;
    reg        div_sign_q, div_sign_r;  // Sign flags for quotient and remainder

    // Latches for start
    reg [2:0]  op_latched;
    reg [31:0] a_latched, b_latched;

    wire is_mul = (op_latched == `FUNCT3_MUL) || (op_latched == `FUNCT3_MULH) ||
                  (op_latched == `FUNCT3_MULHSU) || (op_latched == `FUNCT3_MULHU);
    wire is_div = (op_latched == `FUNCT3_DIV) || (op_latched == `FUNCT3_DIVU) ||
                  (op_latched == `FUNCT3_REM) || (op_latched == `FUNCT3_REMU);

    // Helper: signedness for multiplier operands (based on funct3 semantics)
    wire mul_signed_a = (op_latched == `FUNCT3_MULH) || (op_latched == `FUNCT3_MULHSU);
    wire mul_signed_b = (op_latched == `FUNCT3_MULH);

    // Helper: divider op_sel mapping (internal)
    wire [1:0] div_op_sel = (op_latched == `FUNCT3_DIV)  ? 2'b00 :
                           (op_latched == `FUNCT3_DIVU) ? 2'b01 :
                           (op_latched == `FUNCT3_REM)  ? 2'b10 : 2'b11;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            product <= 64'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            multiplicand <= 64'd0;
            multiplier <= 32'd0;
            acc <= 64'd0;
            mul_count <= 6'd0;
            dividend <= 32'd0;
            divisor <= 32'd0;
            quotient_reg <= 32'd0;
            remainder_reg <= 33'd0;
            div_count <= 6'd0;
            div_sign_q <= 1'b0;
            div_sign_r <= 1'b0;
            op_latched <= 3'd0;
            a_latched <= 32'd0;
            b_latched <= 32'd0;
        end else begin
            // Clear done when CPU acknowledges completion
            if (ack && done) begin
                done <= 1'b0;
            end
            
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;  // Clear done when new operation starts
                        // Latch inputs
                        op_latched <= funct3;
                        a_latched <= a;
                        b_latched <= b;

                        // Decide path
                        `ifdef SIMULATION
                        $display("[MDU] START: funct3=%0d a=0x%08h b=0x%08h", funct3, a, b);
                        $display("[MDU] START-LATCHED: op_latched=%0d a_latched=0x%08h b_latched=0x%08h", op_latched, a_latched, b_latched);
                        `endif
                        if ( (funct3 == `FUNCT3_MUL) || (funct3 == `FUNCT3_MULH) ||
                             (funct3 == `FUNCT3_MULHSU) || (funct3 == `FUNCT3_MULHU) ) begin
                            // Prepare multiplier (unsigned abs conversion if needed)
                            mul_sign <= ((funct3 == `FUNCT3_MULH) || (funct3 == `FUNCT3_MULHSU)) && a[31];
                            // Proper signed handling below - convert operand a to absolute for MULH and MULHSU
                            multiplicand <= {32'd0, (((funct3 == `FUNCT3_MULH) || (funct3 == `FUNCT3_MULHSU)) && a[31]) ? (~a + 1'b1) : a};
                            // b is converted to abs only for MULH (both signed)
                            multiplier <= ((funct3 == `FUNCT3_MULH) && b[31]) ? (~b + 1'b1) : b;
                            acc <= 64'd0;
                            mul_count <= 6'd0;
                            busy <= 1'b1;
                            state <= MUL;
                        end else begin
                            // Division - setup restoring division algorithm
                            busy <= 1'b1;
                            
                            // Handle signed division: convert to positive and track signs
                            if (funct3 == `FUNCT3_DIV || funct3 == `FUNCT3_REM) begin
                                // Signed division
                                dividend <= a[31] ? (~a + 1'b1) : a;  // Absolute value
                                divisor <= b[31] ? (~b + 1'b1) : b;   // Absolute value
                                div_sign_q <= a[31] ^ b[31];          // Quotient negative if signs differ
                                div_sign_r <= a[31];                  // Remainder takes dividend sign
                            end else begin
                                // Unsigned division
                                dividend <= a;
                                divisor <= b;
                                div_sign_q <= 1'b0;
                                div_sign_r <= 1'b0;
                            end
                            
                            quotient_reg <= 32'd0;
                            remainder_reg <= 33'd0;
                            div_count <= 6'd0;
                            state <= DIV;
                        end
                    end
                end

                MUL: begin
                    if (mul_count < 32) begin
                        if (multiplier[0]) begin
                            acc <= acc + multiplicand;
                        end
                        multiplicand <= multiplicand << 1;
                        multiplier <= multiplier >> 1;
                        mul_count <= mul_count + 1;
                    end else begin
                        // Apply sign correction based on operation type
                        // MULH: both operands are signed
                        //   If exactly one operand is negative (a_neg XOR b_neg), negate result
                        // MULHSU: a is signed, b is unsigned
                        //   If a is negative, negate result  
                        // MULHU: both unsigned, no sign correction
                        // MUL: lower 32 bits, no sign correction needed (inherent in 2's complement)
                        if (op_latched == `FUNCT3_MULH) begin
                            // MULH: negate if exactly one operand is negative (signs differ)
                            if ((a_latched[31] ^ b_latched[31]) == 1'b1) begin
                                product <= ~acc + 64'd1;
                            end else begin
                                product <= acc;
                            end
                        end else if (op_latched == `FUNCT3_MULHSU && a_latched[31]) begin
                            // MULHSU: negate if a is negative
                            product <= ~acc + 64'd1;
                        end else begin
                            // MULHU or MUL: no sign correction
                            product <= acc;
                        end
                        busy <= 1'b0;
                        done <= 1'b1;  // Set done when operation completes
                        `ifdef SIMULATION
                        $display("[MDU] MUL DONE: acc=0x%016h product_out=0x%016h op_latched=%0d a_latched=0x%08h b_latched=0x%08h multiplicand=0x%016h multiplier=0x%08h", acc, product, op_latched, a_latched, b_latched, multiplicand, multiplier);
                        `endif
                        state <= IDLE;
                    end
                end

                DIV: begin
                    // Handle division by zero
                    if (b_latched == 32'd0) begin
                        quotient <= 32'hFFFFFFFF;
                        remainder <= a_latched;
                        busy <= 1'b0;
                        done <= 1'b1;
                        state <= IDLE;
                    end else if (div_count < 32) begin
                        // Restoring division algorithm
                        // Shift remainder left and bring down next bit of dividend
                        remainder_reg <= {remainder_reg[31:0], dividend[31-div_count]};
                        
                        // Check if we can subtract divisor from shifted remainder
                        if ({remainder_reg[30:0], dividend[31-div_count]} >= divisor) begin
                            // Subtraction successful - set quotient bit and subtract
                            remainder_reg <= {1'b0, ({remainder_reg[30:0], dividend[31-div_count]} - divisor)};
                            quotient_reg <= (quotient_reg << 1) | 1'b1;
                        end else begin
                            // Subtraction would be negative - just shift and clear quotient bit
                            quotient_reg <= quotient_reg << 1;
                        end
                        
                        div_count <= div_count + 1;
                    end else begin
                        // Division complete - apply sign corrections
                        state <= DIV2;
                    end
                end
                
                DIV2: begin
                    // Apply final sign corrections based on operation type
                    case (op_latched)
                        `FUNCT3_DIV: begin
                            quotient <= div_sign_q ? (~quotient_reg + 1'b1) : quotient_reg;
                            remainder <= div_sign_r ? (~remainder_reg[31:0] + 1'b1) : remainder_reg[31:0];
                        end
                        `FUNCT3_DIVU: begin
                            quotient <= quotient_reg;
                            remainder <= remainder_reg[31:0];
                        end
                        `FUNCT3_REM: begin
                            quotient <= div_sign_q ? (~quotient_reg + 1'b1) : quotient_reg;
                            remainder <= div_sign_r ? (~remainder_reg[31:0] + 1'b1) : remainder_reg[31:0];
                        end
                        `FUNCT3_REMU: begin
                            quotient <= quotient_reg;
                            remainder <= remainder_reg[31:0];
                        end
                    endcase
                    
                    busy <= 1'b0;
                    done <= 1'b1;  // Set done when operation completes
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
