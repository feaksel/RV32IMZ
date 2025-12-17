// Sky130 SRAM Macro - 2KB Single Port
// Placeholder macro for academic synthesis
//
// This is a behavioral model for the sky130_sram_2kbyte_1rw1r_32x512_8 macro
// Real macro would come from SRAM compiler or foundry

module sky130_sram_2kbyte_1rw1r_32x512_8 (
    input         clk0,     // Clock
    input         csb0,     // Chip Select (active low)
    input         web0,     // Write Enable (active low) 
    input  [8:0]  addr0,    // Address (512 words = 9 bits)
    input  [31:0] din0,     // Data In
    output [31:0] dout0     // Data Out
);

    // Memory array: 512 words x 32 bits = 2KB
    reg [31:0] memory [0:511];
    reg [31:0] dout0_reg;

    // Initialize memory to zeros
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) begin
            memory[i] = 32'h0;
        end
        dout0_reg = 32'h0;
    end

    // Memory operation
    always @(posedge clk0) begin
        if (!csb0) begin  // Chip select active
            if (!web0) begin  // Write operation
                memory[addr0] <= din0;
            end
            // Read operation (always happens when selected)
            dout0_reg <= memory[addr0];
        end
    end

    // Output assignment
    assign dout0 = dout0_reg;

    // Synthesis attributes for proper SRAM inference
    (* ram_style = "block" *) reg [31:0] memory_attr [0:511];
    
    // For timing simulation - add realistic delays
    specify
        (posedge clk0 => (dout0 : 1'bx)) = (0.5, 0.5);  // 0.5ns delay
    endspecify

endmodule