`timescale 1ns/1ps
`include "riscv_defines.vh"

module test_hazard;
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

    integer i;
    initial begin
        rst_n = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'h00000000;
        end

        // EXACT pattern from compliance test_26
        imem[0] = 32'h800000b7;  // LUI x1, 0x80000  -> x1 = 0x80000000
        imem[1] = 32'h00e00113;  // ADDI x2, x0, 14  -> x2 = 14
        imem[2] = 32'h0020d733;  // SRL x14, x1, x2  -> x14 = 0x00020000
        imem[3] = 32'h00000013;  // NOP
        imem[4] = 32'h00070313;  // MV x6, x14 (ADDI x6, x14, 0) -> x6 = x14 = 0x00020000

        #20 rst_n = 1;
        #1000;

        $display("Test RAW Hazard (compliance test pattern):");
        $display("x1  = 0x%08x (expected: 0x80000000)", dut.regfile_inst.registers[1]);
        $display("x2  = 0x%08x (expected: 0x0000000e)", dut.regfile_inst.registers[2]);
        $display("x14 = 0x%08x (expected: 0x00020000)", dut.regfile_inst.registers[14]);
        $display("x6  = 0x%08x (expected: 0x00020000) %s", 
                 dut.regfile_inst.registers[6],
                 (dut.regfile_inst.registers[6] == 32'h00020000) ? "PASS" : "FAIL");

        if (dut.regfile_inst.registers[6] != 32'h00020000) begin
            $display("\nFAILURE: RAW hazard not handled correctly!");
            $display("x14 was written but x6 got wrong value through MV instruction");
        end

        $finish;
    end
endmodule
