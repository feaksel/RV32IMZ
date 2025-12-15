`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_debug_branch;
    reg clk = 0;
    reg rst_n;
    always #5 clk = ~clk;

    wire [31:0] iwb_adr_o, iwb_dat_i, dwb_adr_o, dwb_dat_o, dwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o, dwb_we_o, dwb_cyc_o, dwb_stb_o;
    reg iwb_ack_i, dwb_ack_i;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i = 1'b0;
    reg [31:0] interrupts = 32'h0;

    reg [31:0] imem [0:15];
    assign iwb_dat_i = imem[iwb_adr_o[5:2]];
    assign dwb_dat_i = 32'h0;

    custom_riscv_core dut (.*);

    always @(posedge clk) begin
        iwb_ack_i <= iwb_cyc_o && iwb_stb_o;
        dwb_ack_i <= dwb_cyc_o && dwb_stb_o;
    end

    integer exec_count = 0;
    
    // Track EVERY instruction execution in WRITEBACK
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_WRITEBACK) begin
            exec_count = exec_count + 1;
            $display("[%3d] EXEC @0x%02x: opcode=0x%02x, rd=x%0d, rd_data=0x%08x, rd_wen=%b",
                     exec_count, dut.trap_pc, dut.opcode, dut.rd_addr, dut.rd_data, dut.rd_wen);
        end
    end

    initial begin
        rst_n = 0;
        
        // Setup mtvec to point to a safe halt loop FIRST
        imem[0] = 32'h00000093;  // ADDI x1, x0, 0  (will be overwritten)
        imem[1] = 32'h00000113;  // ADDI x2, x0, 0
        imem[2] = 32'h00208663;  // BEQ (will be overwritten)
        imem[3] = 32'h00100193;  // ADDI x3, x0, 1
        imem[4] = 32'h00200213;  // ADDI x4, x0, 2
        imem[5] = 32'h00300293;  // ADDI x5, x0, 3
        imem[6] = 32'h00100073;  // EBREAK
        
        // Trap handler at 0x20: infinite loop
        imem[8] = 32'h0000006f;  // JAL x0, 0 (infinite loop)

        #20 rst_n = 1;
        #20;

        $display("\n========== SCENARIO 1: EBREAK with UNINITIALIZED mtvec ==========");
        $display("mtvec defaults to 0x00000000, so EBREAK will jump to start!\n");
        
        // Reset and run
        rst_n = 0; #20; rst_n = 1; #20;
        exec_count = 0;
        
        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h00a00113;  // ADDI x2, x0, 10  
        imem[2] = 32'h00208663;  // BEQ x1, x2, +12
        imem[3] = 32'h00100193;  // ADDI x3, x0, 1 (SHOULD BE SKIPPED)
        imem[4] = 32'h00200213;  // ADDI x4, x0, 2 (SHOULD BE SKIPPED)
        imem[5] = 32'h00300293;  // ADDI x5, x0, 3
        imem[6] = 32'h00100073;  // EBREAK

        #500;  // Wait for some execution
        
        $display("\nAfter 500ns:");
        $display("  x1=%0d (expect 10)", dut.regfile_inst.registers[1]);
        $display("  x2=%0d (expect 10)", dut.regfile_inst.registers[2]);
        $display("  x3=%0d (expect 0, but might be 1 if EBREAK caused re-execution!)", 
                 dut.regfile_inst.registers[3]);
        $display("  x4=%0d (expect 0, but might be 2 if EBREAK caused re-execution!)", 
                 dut.regfile_inst.registers[4]);
        $display("  x5=%0d (expect 3)", dut.regfile_inst.registers[5]);

        if (dut.regfile_inst.registers[3] != 0 || dut.regfile_inst.registers[4] != 0) begin
            $display("\n*** BUG CONFIRMED: EBREAK re-execution caused skipped instructions to execute! ***\n");
        end

        #500;
        $display("\n========== SCENARIO 2: Initialize mtvec to trap handler ==========\n");
        
        rst_n = 0; #20; rst_n = 1; #20;
        exec_count = 0;
        
        // Write mtvec CSR to 0x20 (trap handler address)
        imem[0] = 32'h02000293;  // ADDI x5, x0, 32 (0x20)
        imem[1] = 32'h30529073;  // CSRRW x0, mtvec, x5
        
        // Now run the actual test
        imem[2] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[3] = 32'h00a00113;  // ADDI x2, x0, 10
        imem[4] = 32'h00208863;  // BEQ x1, x2, +16 (skip to imem[8])
        imem[5] = 32'h00100193;  // ADDI x3, x0, 1 (SHOULD BE SKIPPED)
        imem[6] = 32'h00200213;  // ADDI x4, x0, 2 (SHOULD BE SKIPPED)
        imem[7] = 32'h00300193;  // ADDI x3, x0, 3 (SHOULD BE SKIPPED)
        imem[8] = 32'h00400293;  // ADDI x5, x0, 4 (target)
        imem[9] = 32'h00100073;  // EBREAK → will jump to 0x20 (infinite loop)

        #1000;
        
        $display("\nAfter 1000ns with mtvec=0x20:");
        $display("  x1=%0d (expect 10)", dut.regfile_inst.registers[1]);
        $display("  x2=%0d (expect 10)", dut.regfile_inst.registers[2]);
        $display("  x3=%0d (expect 0 - skipped)", dut.regfile_inst.registers[3]);
        $display("  x4=%0d (expect 0 - skipped)", dut.regfile_inst.registers[4]);
        $display("  x5=%0d (expect 4)", dut.regfile_inst.registers[5]);

        if (dut.regfile_inst.registers[3] == 0 && 
            dut.regfile_inst.registers[4] == 0 &&
            dut.regfile_inst.registers[5] == 4) begin
            $display("\n*** FIX CONFIRMED: With mtvec set, test passes! ***\n");
        end

        $finish;
    end
endmodule
