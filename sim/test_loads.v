`timescale 1ns/1ps
`include "riscv_defines.vh"

module test_loads;
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

    // Data output is combinational (Wishbone requires data valid same cycle as ACK)
    always @(*) begin
        if (dwb_stb_o && dwb_cyc_o) begin
            dmem_data = dmem[dwb_adr_o[11:2]];
        end else begin
            dmem_data = 32'h0;
        end
    end

    // ACK and write logic are clocked
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ack <= 0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
                    // Handle byte-enable writes
                    if (dwb_sel_o[0]) dmem[dwb_adr_o[11:2]][7:0]   <= dwb_dat_o[7:0];
                    if (dwb_sel_o[1]) dmem[dwb_adr_o[11:2]][15:8]  <= dwb_dat_o[15:8];
                    if (dwb_sel_o[2]) dmem[dwb_adr_o[11:2]][23:16] <= dwb_dat_o[23:16];
                    if (dwb_sel_o[3]) dmem[dwb_adr_o[11:2]][31:24] <= dwb_dat_o[31:24];
                end
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

        // Setup test data in memory
        dmem[16] = 32'hDEADBEEF;  // Address 0x40

        // Test LB (load byte signed) from different offsets
        imem[0] = 32'h04000093;  // ADDI x1, x0, 0x40  (base address)
        imem[1] = 32'h00008103;  // LB x2, 0(x1)      -> x2 = 0xFFFFFFEF (sign-extended)
        imem[2] = 32'h00108183;  // LB x3, 1(x1)      -> x3 = 0xFFFFFFBE (sign-extended)
        imem[3] = 32'h00208203;  // LB x4, 2(x1)      -> x4 = 0xFFFFFFAD (sign-extended)
        imem[4] = 32'h00308283;  // LB x5, 3(x1)      -> x5 = 0xFFFFFFDE (sign-extended)

        // Test LBU (load byte unsigned)
        imem[5] = 32'h0000c303;  // LBU x6, 0(x1)     -> x6 = 0x000000EF
        imem[6] = 32'h0010c383;  // LBU x7, 1(x1)     -> x7 = 0x000000BE

        // Test LH (load halfword signed)
        imem[7] = 32'h00009413;  // LH x8, 0(x1)      -> x8 = 0xFFFFBEEF (sign-extended)
        imem[8] = 32'h00209493;  // LH x9, 2(x1)      -> x9 = 0xFFFFDEAD (sign-extended)

        // Test LHU (load halfword unsigned)
        imem[9] = 32'h0000d513;  // LHU x10, 0(x1)    -> x10 = 0x0000BEEF
        imem[10] = 32'h0020d593; // LHU x11, 2(x1)    -> x11 = 0x0000DEAD

        // Test LW (load word)
        imem[11] = 32'h0000a603; // LW x12, 0(x1)     -> x12 = 0xDEADBEEF

        #20 rst_n = 1;
        #2000;

        $display("\nLoad Test Results:");
        $display("Memory[0x40] = 0x%08x", dmem[16]);
        $display("\nLB tests (sign-extended):");
        $display("x2  (LB offset 0) = 0x%08x (expected: 0xffffffef) %s", dut.regfile_inst.registers[2], 
                 (dut.regfile_inst.registers[2] == 32'hffffffef) ? "PASS" : "FAIL");
        $display("x3  (LB offset 1) = 0x%08x (expected: 0xffffffbe) %s", dut.regfile_inst.registers[3],
                 (dut.regfile_inst.registers[3] == 32'hffffffbe) ? "PASS" : "FAIL");
        $display("x4  (LB offset 2) = 0x%08x (expected: 0xffffffad) %s", dut.regfile_inst.registers[4],
                 (dut.regfile_inst.registers[4] == 32'hffffffad) ? "PASS" : "FAIL");
        $display("x5  (LB offset 3) = 0x%08x (expected: 0xffffffde) %s", dut.regfile_inst.registers[5],
                 (dut.regfile_inst.registers[5] == 32'hffffffde) ? "PASS" : "FAIL");
        
        $display("\nLBU tests (zero-extended):");
        $display("x6  (LBU offset 0) = 0x%08x (expected: 0x000000ef) %s", dut.regfile_inst.registers[6],
                 (dut.regfile_inst.registers[6] == 32'h000000ef) ? "PASS" : "FAIL");
        $display("x7  (LBU offset 1) = 0x%08x (expected: 0x000000be) %s", dut.regfile_inst.registers[7],
                 (dut.regfile_inst.registers[7] == 32'h000000be) ? "PASS" : "FAIL");

        $display("\nLH tests (sign-extended):");
        $display("x8  (LH offset 0)  = 0x%08x (expected: 0xffffbeef) %s", dut.regfile_inst.registers[8],
                 (dut.regfile_inst.registers[8] == 32'hffffbeef) ? "PASS" : "FAIL");
        $display("x9  (LH offset 2)  = 0x%08x (expected: 0xffffdead) %s", dut.regfile_inst.registers[9],
                 (dut.regfile_inst.registers[9] == 32'hffffdead) ? "PASS" : "FAIL");

        $display("\nLHU tests (zero-extended):");
        $display("x10 (LHU offset 0) = 0x%08x (expected: 0x0000beef) %s", dut.regfile_inst.registers[10],
                 (dut.regfile_inst.registers[10] == 32'h0000beef) ? "PASS" : "FAIL");
        $display("x11 (LHU offset 2) = 0x%08x (expected: 0x0000dead) %s", dut.regfile_inst.registers[11],
                 (dut.regfile_inst.registers[11] == 32'h0000dead) ? "PASS" : "FAIL");

        $display("\nLW test:");
        $display("x12 (LW)  = 0x%08x (expected: 0xdeadbeef) %s", dut.regfile_inst.registers[12],
                 (dut.regfile_inst.registers[12] == 32'hdeadbeef) ? "PASS" : "FAIL");

        $finish;
    end
endmodule
