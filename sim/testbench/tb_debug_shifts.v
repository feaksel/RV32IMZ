`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_debug_shifts;
    reg clk = 0;
    reg rst_n;
    always #5 clk = ~clk;

    wire [31:0] iwb_adr_o, dwb_adr_o, dwb_dat_o;
    wire [31:0] iwb_dat_i, dwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o, dwb_we_o, dwb_cyc_o, dwb_stb_o;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i = 0;
    reg [31:0] interrupts = 0;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    reg imem_ack, dmem_ack;
    reg [31:0] imem_data, dmem_data;

    assign iwb_dat_i = imem_data;
    assign dwb_dat_i = dmem_data;

    custom_riscv_core dut (
        .clk(clk), .rst_n(rst_n),
        .iwb_adr_o(iwb_adr_o), .iwb_dat_i(iwb_dat_i),
        .iwb_cyc_o(iwb_cyc_o), .iwb_stb_o(iwb_stb_o), .iwb_ack_i(imem_ack),
        .dwb_adr_o(dwb_adr_o), .dwb_dat_o(dwb_dat_o), .dwb_dat_i(dwb_dat_i),
        .dwb_we_o(dwb_we_o), .dwb_sel_o(dwb_sel_o),
        .dwb_cyc_o(dwb_cyc_o), .dwb_stb_o(dwb_stb_o), .dwb_ack_i(dmem_ack),
        .dwb_err_i(dwb_err_i), .interrupts(interrupts)
    );

    // Instruction memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ack <= 0;
            imem_data <= 32'h00000013;
        end else begin
            if (iwb_stb_o && iwb_cyc_o && !imem_ack) begin
                imem_data <= imem[iwb_adr_o[11:2]];
                imem_ack <= 1;
            end else begin
                imem_ack <= 0;
            end
        end
    end

    // Data memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ack <= 0;
            dmem_data <= 32'h0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) dmem[dwb_adr_o[11:2]] <= dwb_dat_o;
                dmem_data <= dmem[dwb_adr_o[11:2]];
                dmem_ack <= 1;
            end else begin
                dmem_ack <= 0;
            end
        end
    end

    // Trace writeback
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_WRITEBACK && dut.rd_wen) begin
            $display("[WB] x%0d <= 0x%08x (PC=0x%02x)",
                     dut.rd_addr, dut.rd_data, dut.pc);
        end
    end

    integer i;
    initial begin
        $dumpfile("tb_debug_shifts.vcd");
        $dumpvars(0, tb_debug_shifts);

        rst_n = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'h00000000;
        end

        // Test SRL (shift right logical) - register version
        // x1 = 0x80000000, x2 = 4
        // x3 = x1 >> x2 = 0x08000000
        imem[0] = 32'h800000b7;  // LUI x1, 0x80000
        imem[1] = 32'h00400113;  // ADDI x2, x0, 4
        imem[2] = 32'h0020d1b3;  // SRL x3, x1, x2

        // Test SRA (shift right arithmetic) - register version
        // x4 = x1 >>> x2 = 0xf8000000 (sign extended)
        imem[3] = 32'h4020d233;  // SRA x4, x1, x2

        // Test SRLI (shift right logical immediate)
        // x5 = x1 >> 4 = 0x08000000
        imem[4] = 32'h0040d293;  // SRLI x5, x1, 4

        // Test SRAI (shift right arithmetic immediate)
        // x6 = x1 >>> 4 = 0xf8000000 (sign extended)
        imem[5] = 32'h4040d313;  // SRAI x6, x1, 4

        // Test AND register
        // x7 = 0xff, x8 = 0xf0
        // x9 = x7 & x8 = 0xf0
        imem[6] = 32'h0ff00393;  // ADDI x7, x0, 0xff
        imem[7] = 32'h0f000413;  // ADDI x8, x0, 0xf0
        imem[8] = 32'h0083f4b3;  // AND x9, x7, x8

        // Test OR register
        // x10 = x7 | x8 = 0xff
        imem[9] = 32'h0083e533;  // OR x10, x7, x8

        // Test XOR register
        // x11 = x7 ^ x8 = 0x0f
        imem[10] = 32'h0083c5b3;  // XOR x11, x7, x8

        #20 rst_n = 1;

        $display("\n=== Testing Shift and Logical Operations ===\n");

        #2000;

        $display("\nExpected results:");
        $display("x1 = 0x80000000");
        $display("x2 = 0x00000004");
        $display("x3 (SRL)  = 0x08000000");
        $display("x4 (SRA)  = 0xf8000000");
        $display("x5 (SRLI) = 0x08000000");
        $display("x6 (SRAI) = 0xf8000000");
        $display("x7 = 0x000000ff");
        $display("x8 = 0x000000f0");
        $display("x9 (AND)  = 0x000000f0");
        $display("x10 (OR)  = 0x000000ff");
        $display("x11 (XOR) = 0x0000000f");

        $display("\nActual results:");
        $display("x1  = 0x%08x", dut.regfile_inst.registers[1]);
        $display("x2  = 0x%08x", dut.regfile_inst.registers[2]);
        $display("x3  = 0x%08x %s", dut.regfile_inst.registers[3],
                 (dut.regfile_inst.registers[3] == 32'h08000000) ? "PASS" : "FAIL");
        $display("x4  = 0x%08x %s", dut.regfile_inst.registers[4],
                 (dut.regfile_inst.registers[4] == 32'hf8000000) ? "PASS" : "FAIL");
        $display("x5  = 0x%08x %s", dut.regfile_inst.registers[5],
                 (dut.regfile_inst.registers[5] == 32'h08000000) ? "PASS" : "FAIL");
        $display("x6  = 0x%08x %s", dut.regfile_inst.registers[6],
                 (dut.regfile_inst.registers[6] == 32'hf8000000) ? "PASS" : "FAIL");
        $display("x7  = 0x%08x", dut.regfile_inst.registers[7]);
        $display("x8  = 0x%08x", dut.regfile_inst.registers[8]);
        $display("x9  = 0x%08x %s", dut.regfile_inst.registers[9],
                 (dut.regfile_inst.registers[9] == 32'h000000f0) ? "PASS" : "FAIL");
        $display("x10 = 0x%08x %s", dut.regfile_inst.registers[10],
                 (dut.regfile_inst.registers[10] == 32'h000000ff) ? "PASS" : "FAIL");
        $display("x11 = 0x%08x %s", dut.regfile_inst.registers[11],
                 (dut.regfile_inst.registers[11] == 32'h0000000f) ? "PASS" : "FAIL");

        $finish;
    end
endmodule
