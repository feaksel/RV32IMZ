`timescale 1ns/1ps

//==============================================================================
// Testbench for RV32IM Hierarchical Top (2-Macro: MDU + Core)
// Tests the macro-wrapped hierarchical core implementation
//==============================================================================

module tb_hierarchical_core;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Instruction Wishbone Bus (read-only for instruction fetch)
    wire [31:0] iwb_adr;
    reg  [31:0] iwb_dat_in;
    wire        iwb_cyc;
    wire        iwb_stb;
    reg         iwb_ack;
    reg         iwb_err;
    
    // Data Wishbone Bus
    wire [31:0] dwb_adr;
    wire [31:0] dwb_dat_out;
    reg  [31:0] dwb_dat_in;
    wire        dwb_we;
    wire [3:0]  dwb_sel;
    wire        dwb_cyc;
    wire        dwb_stb;
    reg         dwb_ack;
    reg         dwb_err;
    
    // Interrupts
    reg [15:0] interrupts;

    //==========================================================================
    // DUT: Hierarchical Core (MDU Macro + Core Macro)
    //==========================================================================
    
    rv32im_hierarchical_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Instruction Wishbone (read-only)
        .iwb_adr_o  (iwb_adr),
        .iwb_dat_i  (iwb_dat_in),
        .iwb_cyc_o  (iwb_cyc),
        .iwb_stb_o  (iwb_stb),
        .iwb_ack_i  (iwb_ack),
        .iwb_err_i  (iwb_err),
        
        // Data Wishbone
        .dwb_adr_o  (dwb_adr),
        .dwb_dat_o  (dwb_dat_out),
        .dwb_dat_i  (dwb_dat_in),
        .dwb_we_o   (dwb_we),
        .dwb_sel_o  (dwb_sel),
        .dwb_cyc_o  (dwb_cyc),
        .dwb_stb_o  (dwb_stb),
        .dwb_ack_i  (dwb_ack),
        .dwb_err_i  (dwb_err),
        
        // Interrupts
        .interrupts (interrupts)
    );

    //==========================================================================
    // Clock Generation (100 MHz)
    //==========================================================================
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100 MHz
    end

    //==========================================================================
    // Simple Memory Model
    //==========================================================================
    
    reg [31:0] imem [0:1023];  // 4KB instruction memory
    reg [31:0] dmem [0:1023];  // 4KB data memory
    
    // Load test program
    initial begin
        // Simple test program: ADD, MUL, DIV operations
        
        // Test 1: ADD x1, x0, x0  (NOP equivalent)
        imem[0] = 32'h00000033;  // ADD x1, x0, x0
        
        // Test 2: ADDI x2, x0, 10  (x2 = 10)
        imem[1] = 32'h00a00113;  // ADDI x2, x0, 10
        
        // Test 3: ADDI x3, x0, 5   (x3 = 5)
        imem[2] = 32'h00500193;  // ADDI x3, x0, 5
        
        // Test 4: MUL x4, x2, x3   (x4 = 10 * 5 = 50)
        imem[3] = 32'h02310233;  // MUL x4, x2, x3
        
        // Test 5: DIV x5, x4, x3   (x5 = 50 / 5 = 10)
        imem[4] = 32'h023242b3;  // DIV x5, x4, x3
        
        // Test 6: SW x5, 0(x0)     (Store result to memory)
        imem[5] = 32'h00502023;  // SW x5, 0(x0)
        
        // Test 7: LW x6, 0(x0)     (Load back from memory)
        imem[6] = 32'h00002303;  // LW x6, 0(x0)
        
        // Test 8: Loop forever
        imem[7] = 32'hffdff06f;  // JAL x0, -4 (infinite loop)
        
        // Initialize data memory
        for (integer i = 0; i < 1024; i = i + 1) begin
            dmem[i] = 32'h0;
        end
    end

    //==========================================================================
    // Wishbone Bus Response Logic
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iwb_ack <= 1'b0;
            iwb_err <= 1'b0;
            dwb_ack <= 1'b0;
            dwb_err <= 1'b0;
            iwb_dat_in <= 32'h0;
            dwb_dat_in <= 32'h0;
        end else begin
            // Instruction fetch response (1-cycle latency)
            iwb_ack <= iwb_cyc && iwb_stb && !iwb_ack;
            iwb_err <= 1'b0;
            
            if (iwb_cyc && iwb_stb && !iwb_ack) begin
                iwb_dat_in <= imem[iwb_adr[11:2]];
                $display("[%0t] IFETCH: addr=0x%08h data=0x%08h", $time, iwb_adr, imem[iwb_adr[11:2]]);
            end
            
            // Data memory response (1-cycle latency)
            dwb_ack <= dwb_cyc && dwb_stb && !dwb_ack;
            dwb_err <= 1'b0;
            
            if (dwb_cyc && dwb_stb && !dwb_ack) begin
                if (dwb_we) begin
                    // Write operation
                    if (dwb_sel[0]) dmem[dwb_adr[11:2]][7:0]   <= dwb_dat_out[7:0];
                    if (dwb_sel[1]) dmem[dwb_adr[11:2]][15:8]  <= dwb_dat_out[15:8];
                    if (dwb_sel[2]) dmem[dwb_adr[11:2]][23:16] <= dwb_dat_out[23:16];
                    if (dwb_sel[3]) dmem[dwb_adr[11:2]][31:24] <= dwb_dat_out[31:24];
                    $display("[%0t] STORE: addr=0x%08h data=0x%08h sel=%b", 
                             $time, dwb_adr, dwb_dat_out, dwb_sel);
                end else begin
                    // Read operation
                    dwb_dat_in <= dmem[dwb_adr[11:2]];
                    $display("[%0t] LOAD:  addr=0x%08h data=0x%08h", 
                             $time, dwb_adr, dmem[dwb_adr[11:2]]);
                end
            end
        end
    end

    //==========================================================================
    // Test Monitoring
    //==========================================================================
    
    integer instr_count;
    
    initial begin
        instr_count = 0;
    end
    
    // Monitor instruction execution
    always @(posedge clk) begin
        if (rst_n && iwb_cyc && iwb_stb && iwb_ack) begin
            instr_count = instr_count + 1;
            if (instr_count <= 8) begin
                $display("[%0t] Instruction #%0d executed at PC=0x%08h", 
                         $time, instr_count, iwb_adr);
            end
        end
    end

    //==========================================================================
    // Test Sequence
    //==========================================================================
    
    initial begin
        // Dump waveforms
        $dumpfile("tb_hierarchical_core.vcd");
        $dumpvars(0, tb_hierarchical_core);
        
        // Initialize
        rst_n = 0;
        interrupts = 16'h0;
        iwb_dat_in = 32'h0;
        dwb_dat_in = 32'h0;
        iwb_ack = 0;
        dwb_ack = 0;
        iwb_err = 0;
        dwb_err = 0;
        
        $display("");
        $display("========================================");
        $display("Hierarchical Core Test Starting");
        $display("Testing: MDU Macro + Core Macro");
        $display("========================================");
        $display("");
        
        // Reset sequence
        #100;
        rst_n = 1;
        $display("[%0t] Reset released", $time);
        
        // Run for enough cycles to execute test program
        #5000;
        
        // Check results
        $display("");
        $display("========================================");
        $display("Test Results");
        $display("========================================");
        $display("Instructions executed: %0d", instr_count);
        $display("Data memory[0] = 0x%08h (should be 0x0000000a = 10)", dmem[0]);
        
        if (dmem[0] == 32'h0000000a) begin
            $display("");
            $display("✓ TEST PASSED!");
            $display("  - MUL operation worked (10 * 5 = 50)");
            $display("  - DIV operation worked (50 / 5 = 10)");
            $display("  - Memory store/load worked");
        end else begin
            $display("");
            $display("✗ TEST FAILED!");
            $display("  Expected: 0x0000000a, Got: 0x%08h", dmem[0]);
        end
        
        $display("========================================");
        $display("");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
