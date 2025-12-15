`timescale 1ns/1ps
`include "riscv_defines.vh"

module test_load_debug;
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

    // Data output is combinational
    always @(*) begin
        if (dwb_stb_o && dwb_cyc_o) begin
            dmem_data = dmem[dwb_adr_o[11:2]];
        end else begin
            dmem_data = 32'h0;
        end
    end

    // ACK and write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ack <= 0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
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

    // Trace execution
    always @(posedge clk) begin
        if (rst_n) begin
            if (dut.state == dut.STATE_MEM && dwb_cyc_o && dwb_stb_o) begin
                $display("[MEM] addr=0x%02x, we=%b, data_in=0x%08x, ack=%b",
                         dwb_adr_o, dwb_we_o, dwb_dat_i, dmem_ack);
            end
            if (dut.state == dut.STATE_WRITEBACK && dut.rd_wen) begin
                $display("[WB] x%0d <= 0x%08x (mem_read=%b, funct3=%b, mem_data_reg=0x%08x)",
                         dut.rd_addr, dut.rd_data, dut.mem_read, dut.funct3, dut.mem_data_reg);
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

        // Setup test data
        dmem[16] = 32'hDEADBEEF;  // Address 0x40

        // Test one LB instruction
        imem[0] = 32'h04000093;  // ADDI x1, x0, 0x40
        imem[1] = 32'h00008103;  // LB x2, 0(x1) -> should be 0xFFFFFFEF

        #20 rst_n = 1;
        #500;

        $display("\nResults:");
        $display("x1 = 0x%08x (expected: 0x00000040)", dut.regfile_inst.registers[1]);
        $display("x2 = 0x%08x (expected: 0xffffffef) %s",
                 dut.regfile_inst.registers[2],
                 (dut.regfile_inst.registers[2] == 32'hffffffef) ? "PASS" : "FAIL");

        $finish;
    end
endmodule
