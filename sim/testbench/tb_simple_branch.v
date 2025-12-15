/**
 * Simple Branch Test - Debug PC Updates
 */

`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_simple_branch;

    reg clk = 0;
    reg rst_n;

    always #5 clk = ~clk;

    // Wishbone signals
    wire [31:0] iwb_adr_o;
    wire [31:0] iwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o;
    reg iwb_ack_i;

    wire [31:0] dwb_adr_o, dwb_dat_o;
    wire [31:0] dwb_dat_i = 32'h0;
    wire dwb_we_o, dwb_cyc_o, dwb_stb_o;
    reg dwb_ack_i;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i = 1'b0;

    reg [31:0] interrupts = 32'h0;

    // Instruction memory
    reg [31:0] imem [0:15];
    assign iwb_dat_i = imem[iwb_adr_o[5:2]];

    // DUT
    custom_riscv_core dut (
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

    // Wishbone ack simulation
    always @(posedge clk) begin
        iwb_ack_i <= iwb_cyc_o && iwb_stb_o;
        dwb_ack_i <= dwb_cyc_o && dwb_stb_o;
    end

    // Monitor PC changes
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_FETCH) begin
            $display("[%0t] FETCH: PC=0x%08x, instruction=0x%08x", $time, dut.pc, iwb_dat_i);
        end
        if (rst_n && dut.state == dut.STATE_WRITEBACK) begin
            $display("[%0t] WRITEBACK: is_branch=%b, is_jump=%b, alu_zero=%b, opcode=0x%02x",
                     $time, dut.is_branch, dut.is_jump, dut.alu_zero, dut.opcode);
        end
    end

    initial begin
        $dumpfile("simple_branch.vcd");
        $dumpvars(0, tb_simple_branch);

        // Initialize
        rst_n = 0;
        iwb_ack_i = 0;
        dwb_ack_i = 0;

        // Program:
        // 0x00: ADDI x1, x0, 10
        imem[0] = 32'h00a00093;
        // 0x04: ADDI x2, x0, 10
        imem[1] = 32'h00a00113;
        // 0x08: BEQ x1, x2, +12 (should jump to 0x14)
        imem[2] = 32'h00208663;
        // 0x0C: ADDI x3, x0, 99 (should be SKIPPED)
        imem[3] = 32'h06300193;
        // 0x10: ADDI x4, x0, 88 (should be SKIPPED)
        imem[4] = 32'h05800213;
        // 0x14: ADDI x5, x0, 77 (should EXECUTE - branch target)
        imem[5] = 32'h04d00293;
        // 0x18: EBREAK
        imem[6] = 32'h00100073;

        #20 rst_n = 1;

        // Wait for execution
        #2000;

        $display("\n========== RESULTS ==========");
        $display("x1 = %d (should be 10)", dut.regfile_inst.registers[1]);
        $display("x2 = %d (should be 10)", dut.regfile_inst.registers[2]);
        $display("x3 = %d (should be 0 - skipped)", dut.regfile_inst.registers[3]);
        $display("x4 = %d (should be 0 - skipped)", dut.regfile_inst.registers[4]);
        $display("x5 = %d (should be 77 - executed)", dut.regfile_inst.registers[5]);

        if (dut.regfile_inst.registers[3] == 0 &&
            dut.regfile_inst.registers[4] == 0 &&
            dut.regfile_inst.registers[5] == 77) begin
            $display("\n*** BRANCH TEST PASSED ***");
        end else begin
            $display("\n*** BRANCH TEST FAILED ***");
            $display("Branch did not skip instructions correctly!");
        end

        $finish;
    end

endmodule
