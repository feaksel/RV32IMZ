`timescale 1ns / 1ps
`include "riscv_defines.vh"

module tb_full_system;

    reg        clk;
    reg        rst_n;
    wire [31:0] iwb_adr_o;
    wire [31:0] iwb_dat_i;
    wire        iwb_cyc_o;
    wire        iwb_stb_o;
    wire        iwb_ack_i;
    wire [31:0] dwb_adr_o;
    wire [31:0] dwb_dat_o;
    wire [31:0] dwb_dat_i;
    wire        dwb_we_o;
    wire [3:0]  dwb_sel_o;
    wire        dwb_cyc_o;
    wire        dwb_stb_o;
    wire        dwb_ack_i;
    wire        dwb_err_i;
    reg  [31:0] interrupts;

    // Instruction memory (ROM)
    reg [31:0] imem [0:1023];  // 4KB instruction memory
    reg [31:0] imem_data;
    reg        imem_ack;

    // Data memory (RAM)
    reg [31:0] dmem [0:1023];  // 4KB data memory
    reg [31:0] dmem_data;
    reg        dmem_ack;

    // Instantiate core
    custom_riscv_core #(
        .RESET_VECTOR(32'h00000000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .iwb_adr_o(iwb_adr_o),
        .iwb_dat_i(iwb_dat_i),
        .iwb_cyc_o(iwb_cyc_o),
        .iwb_stb_o(iwb_stb_o),
        .iwb_ack_i(iwb_ack_i),
        .dwb_adr_o(dwb_adr_o),
        .dwb_dat_o(dwb_dat_o),
        .dwb_dat_i(dwb_dat_i),
        .dwb_we_o(dwb_we_o),
        .dwb_sel_o(dwb_sel_o),
        .dwb_cyc_o(dwb_cyc_o),
        .dwb_stb_o(dwb_stb_o),
        .dwb_ack_i(dwb_ack_i),
        .dwb_err_i(dwb_err_i),
        .interrupts(interrupts)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz clock

    // Instruction memory (ROM) - Wishbone slave
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ack <= 0;
            imem_data <= 32'h00000013;  // NOP
        end else begin
            if (iwb_stb_o && iwb_cyc_o && !imem_ack) begin
                imem_data <= imem[iwb_adr_o[11:2]];  // Word-addressed
                imem_ack <= 1;
            end else begin
                imem_ack <= 0;
            end
        end
    end
    assign iwb_dat_i = imem_data;
    assign iwb_ack_i = imem_ack;

    // Data memory (RAM) - Wishbone slave
    reg bus_error;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ack <= 0;
            dmem_data <= 32'h0;
            bus_error <= 0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
                    // Write
                    if (dwb_sel_o[0]) dmem[dwb_adr_o[11:2]][7:0]   <= dwb_dat_o[7:0];
                    if (dwb_sel_o[1]) dmem[dwb_adr_o[11:2]][15:8]  <= dwb_dat_o[15:8];
                    if (dwb_sel_o[2]) dmem[dwb_adr_o[11:2]][23:16] <= dwb_dat_o[23:16];
                    if (dwb_sel_o[3]) dmem[dwb_adr_o[11:2]][31:24] <= dwb_dat_o[31:24];
                end else begin
                    // Read
                    dmem_data <= dmem[dwb_adr_o[11:2]];
                end
                dmem_ack <= 1;
                bus_error <= 0;
            end else begin
                dmem_ack <= 0;
                bus_error <= 0;
            end
        end
    end
    assign dwb_dat_i = dmem_data;
    assign dwb_ack_i = dmem_ack;
    assign dwb_err_i = bus_error;

    // Test control
    integer test_num = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    task wait_cycles;
        input integer n;
        begin
            repeat(n) @(posedge clk);
        end
    endtask

    task check_register;
        input integer reg_num;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            // Access register file through backdoor (simulation only)
            if (dut.regfile_inst.registers[reg_num] === expected) begin
                $display("[PASS] Test %0d: %s - x%0d = 0x%08h", test_num, test_name, reg_num, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s - x%0d expected 0x%08h, got 0x%08h",
                         test_num, test_name, reg_num, expected, dut.regfile_inst.registers[reg_num]);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    task check_memory;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (dmem[addr[11:2]] === expected) begin
                $display("[PASS] Test %0d: %s - MEM[0x%08h] = 0x%08h", test_num, test_name, addr, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s - MEM[0x%08h] expected 0x%08h, got 0x%08h",
                         test_num, test_name, addr, expected, dmem[addr[11:2]]);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    task load_program;
        input [255:0] filename;
        begin
            $readmemh(filename, imem);
            $display("Loaded program: %s", filename);
        end
    endtask

    // Main test
    initial begin
        $dumpfile("full_system.vcd");
        $dumpvars(0, tb_full_system);

        // Initialize
        rst_n = 0;
        interrupts = 32'h0;

        // Clear memories
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;  // NOP
            dmem[i] = 32'h00000000;
        end

        // Set up trap handler at address 0x190 (imem[100])
        // Trap handler: infinite loop (JAL x0, 0)
        imem[100] = 32'h0000006f;  // JAL x0, 0

        #50 rst_n = 1;
        #50;

        // Initialize mtvec to trap handler (0x190 = 400 decimal)
        imem[0] = 32'h19000293;  // ADDI x5, x0, 400
        imem[1] = 32'h30529073;  // CSRRW x0, mtvec, x5
        imem[2] = 32'h00000013;  // NOP
        imem[3] = 32'h00000013;  // NOP

        wait_cycles(20);  // Let mtvec init complete

        $display("\n========================================");
        $display("RISC-V Full System Integration Test");
        $display("========================================\n");

        //======================================================================
        // TEST 1: Basic ALU Operations
        //======================================================================
        $display("\n=== TEST SUITE 1: Basic ALU Operations ===\n");

        // ADDI x1, x0, 10   # x1 = 10
        imem[0] = 32'h00a00093;
        // ADDI x2, x0, 20   # x2 = 20
        imem[1] = 32'h01400113;
        // ADD x3, x1, x2    # x3 = x1 + x2 = 30
        imem[2] = 32'h002081b3;
        // SUB x4, x2, x1    # x4 = x2 - x1 = 10
        imem[3] = 32'h40110233;  // Fixed: was 40208233 (x1-x2), now x2-x1
        // AND x5, x1, x2    # x5 = 10 & 20 = 0
        imem[4] = 32'h0020f2b3;
        // OR x6, x1, x2     # x6 = 10 | 20 = 30
        imem[5] = 32'h0020e333;
        // XOR x7, x1, x2    # x7 = 10 ^ 20 = 30
        imem[6] = 32'h0020c3b3;
        // EBREAK (stop)
        imem[7] = 32'h00100073;

        wait_cycles(100);

        check_register(1, 32'd10, "ADDI x1, x0, 10");
        check_register(2, 32'd20, "ADDI x2, x0, 20");
        check_register(3, 32'd30, "ADD x3, x1, x2");
        check_register(4, 32'd10, "SUB x4, x2, x1");
        check_register(5, 32'd0,  "AND x5, x1, x2");
        check_register(6, 32'd30, "OR x6, x1, x2");
        check_register(7, 32'd30, "XOR x7, x1, x2");

        //======================================================================
        // TEST 2: Memory Operations (Load/Store)
        //======================================================================
        $display("\n=== TEST SUITE 2: Memory Operations ===\n");

        // Reset and load program
        rst_n = 0; #20;

        // LUI x1, 0x12345   # x1 = 0x12345000
        imem[0] = 32'h123450b7;
        // ADDI x1, x1, 0x678 # x1 = 0x12345678
        imem[1] = 32'h67808093;
        // SW x1, 0(x0)      # MEM[0] = 0x12345678
        imem[2] = 32'h00102023;
        // LW x2, 0(x0)      # x2 = MEM[0] = 0x12345678
        imem[3] = 32'h00002103;
        // EBREAK
        imem[4] = 32'h00100073;

        rst_n = 1; #20;
        wait_cycles(100);

        check_register(1, 32'h12345678, "LUI + ADDI");
        check_register(2, 32'h12345678, "SW then LW");
        check_memory(32'h00000000, 32'h12345678, "Memory write");

        //======================================================================
        // TEST 3: Branch Instructions
        //======================================================================
        $display("\n=== TEST SUITE 3: Branch Instructions ===\n");

        rst_n = 0; #20;

        // ADDI x1, x0, 10
        imem[0] = 32'h00a00093;
        // ADDI x2, x0, 10
        imem[1] = 32'h00a00113;
        // BEQ x1, x2, +12 (skip next 2 instructions)
        imem[2] = 32'h00208663;  // Fixed: was +8, now +12 to skip 2 instructions
        // ADDI x3, x0, 1  # Should be skipped
        imem[3] = 32'h00100193;
        // ADDI x4, x0, 2  # Should be skipped
        imem[4] = 32'h00200213;
        // ADDI x5, x0, 3  # Should execute
        imem[5] = 32'h00300293;
        // EBREAK
        imem[6] = 32'h00100073;

        rst_n = 1; #20;
        wait_cycles(100);

        check_register(1, 32'd10, "Branch setup x1");
        check_register(2, 32'd10, "Branch setup x2");
        check_register(3, 32'd0,  "Skipped by BEQ");
        check_register(4, 32'd0,  "Skipped by BEQ");
        check_register(5, 32'd3,  "After branch target");

        //======================================================================
        // TEST 4: Jump Instructions
        //======================================================================
        $display("\n=== TEST SUITE 4: Jump Instructions ===\n");

        rst_n = 0; #20;

        // JAL x1, +12 (jump to PC+12)
        imem[0] = 32'h00c000ef;
        // ADDI x2, x0, 1  # Should be skipped
        imem[1] = 32'h00100113;
        // ADDI x3, x0, 2  # Should be skipped
        imem[2] = 32'h00200193;
        // ADDI x4, x0, 3  # Jump target
        imem[3] = 32'h00300213;
        // EBREAK
        imem[4] = 32'h00100073;

        rst_n = 1; #20;
        wait_cycles(50);

        check_register(1, 32'h00000004, "JAL return address");
        check_register(2, 32'd0, "Skipped by JAL");
        check_register(3, 32'd0, "Skipped by JAL");
        check_register(4, 32'd3, "Jump target executed");

        //======================================================================
        // TEST 5: Shift Operations
        //======================================================================
        $display("\n=== TEST SUITE 5: Shift Operations ===\n");

        rst_n = 0; #20;

        // ADDI x1, x0, 8    # x1 = 8
        imem[0] = 32'h00800093;
        // SLLI x2, x1, 2    # x2 = 8 << 2 = 32
        imem[1] = 32'h00209113;
        // SRLI x3, x2, 1    # x3 = 32 >> 1 = 16
        imem[2] = 32'h00115193;
        // ADDI x4, x0, -8   # x4 = -8 (0xFFFFFFF8)
        imem[3] = 32'hff800213;
        // SRAI x5, x4, 1    # x5 = -8 >> 1 = -4 (arithmetic)
        imem[4] = 32'h40125293;
        // EBREAK
        imem[5] = 32'h00100073;

        rst_n = 1; #20;
        wait_cycles(100);

        check_register(1, 32'd8,  "ADDI x1 = 8");
        check_register(2, 32'd32, "SLLI (8 << 2)");
        check_register(3, 32'd16, "SRLI (32 >> 1)");
        check_register(4, 32'hFFFFFFF8, "ADDI x4 = -8");
        check_register(5, 32'hFFFFFFFC, "SRAI (-8 >> 1)");

        //======================================================================
        // TEST 6: CSR Instructions
        //======================================================================
        $display("\n=== TEST SUITE 6: CSR Operations ===\n");

        rst_n = 0; #20;

        // CSRRS x1, mstatus, x0  # Read mstatus
        imem[0] = 32'h300020f3;
        // LUI x2, 0x1            # x2 = 0x1000
        imem[1] = 32'h00001137;
        // CSRRW x0, mtvec, x2    # Write mtvec = 0x1000
        imem[2] = 32'h30511073;
        // CSRRS x3, mtvec, x0    # Read back mtvec
        imem[3] = 32'h305021f3;  // Fixed: was 0x300 (mstatus), now 0x305 (mtvec)
        // EBREAK
        imem[4] = 32'h00100073;

        rst_n = 1; #20;
        wait_cycles(100);

        check_register(3, 32'h00001000, "CSR mtvec read/write");

        //======================================================================
        // TEST 7: Exception Handling (Illegal Instruction)
        //======================================================================
        $display("\n=== TEST SUITE 7: Exception Handling ===\n");

        rst_n = 0; #20;

        // Setup trap handler at 0x100
        imem[64] = 32'h00100093;  // ADDI x1, x0, 1 (trap handler)
        imem[65] = 32'h30200073;  // MRET

        // Set mtvec to 0x100
        imem[0] = 32'h10000093;   // ADDI x1, x0, 256 (0x100)
        imem[1] = 32'h30509073;   // CSRRW x0, mtvec, x1
        // Enable interrupts
        imem[2] = 32'h00800093;   // ADDI x1, x0, 8 (MIE bit)
        imem[3] = 32'h30009073;   // CSRRW x0, mstatus, x1
        // Illegal instruction (will cause exception)
        imem[4] = 32'hFFFFFFFF;
        // Should not execute
        imem[5] = 32'h00200113;   // ADDI x2, x0, 2
        imem[6] = 32'h00100073;   // EBREAK

        rst_n = 1; #20;
        wait_cycles(200);

        check_register(1, 32'd1, "Exception handler executed");
        check_register(2, 32'd0, "Instruction after exception not executed");

        //======================================================================
        // TEST 8: Timer Interrupt
        //======================================================================
        $display("\n=== TEST SUITE 8: Interrupt Handling ===\n");

        rst_n = 0; #20;

        // Setup interrupt handler
        imem[64] = 32'h00500193;  // ADDI x3, x0, 5 (ISR marker)
        imem[65] = 32'h30200073;  // MRET

        // Set mtvec
        imem[0] = 32'h10000093;   // ADDI x1, x0, 256 (0x100)
        imem[1] = 32'h30509073;   // CSRRW x0, mtvec, x1
        // Enable timer interrupt in mie (bit 7)
        imem[2] = 32'h08000093;   // ADDI x1, x0, 0x80
        imem[3] = 32'h30409073;   // CSRRW x0, mie, x1
        // Enable global interrupts (MIE in mstatus)
        imem[4] = 32'h00800093;   // ADDI x1, x0, 8
        imem[5] = 32'h30009073;   // CSRRW x0, mstatus, x1
        // Wait loop
        imem[6] = 32'h00100113;   // ADDI x2, x0, 1
        imem[7] = 32'h00100113;   // ADDI x2, x0, 1 (loop)
        imem[8] = 32'h00100073;   // EBREAK

        rst_n = 1; #20;

        // Trigger timer interrupt after some cycles
        #500;
        interrupts[7] = 1;  // Timer interrupt
        #100;
        interrupts[7] = 0;

        wait_cycles(100);

        check_register(3, 32'd5, "Interrupt handler executed");

        //======================================================================
        // Summary
        //======================================================================
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);
        $display("  Total:  %0d", pass_count + fail_count);
        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED! ***");
        end else begin
            $display("\n*** SOME TESTS FAILED ***");
        end
        $display("========================================\n");

        #1000 $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
