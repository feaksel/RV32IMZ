`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_csr_debug;
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

    // Trace CSR operations
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_EXECUTE && dut.is_system) begin
            $display("[CSR] PC=0x%02x, op=%b, addr=0x%03x, wdata=0x%08x, rdata=0x%08x",
                     dut.pc, dut.csr_op, dut.csr_addr, dut.csr_wdata, dut.csr_rdata);
        end

        if (rst_n && dut.state == dut.STATE_WRITEBACK && dut.is_system) begin
            $display("[CSR WB] rd=x%0d, rd_data=0x%08x, rd_wen=%b",
                     dut.rd_addr, dut.rd_data, dut.rd_wen);
        end
    end

    // Trace mtvec register changes
    reg [31:0] mtvec_prev;
    always @(posedge clk) begin
        if (rst_n) begin
            if (dut.csr_inst.mtvec !== mtvec_prev) begin
                $display("[MTVEC CHANGE] 0x%08x -> 0x%08x", mtvec_prev, dut.csr_inst.mtvec);
            end
            mtvec_prev <= dut.csr_inst.mtvec;
        end
    end

    integer i;
    initial begin
        rst_n = 0;

        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'h00000000;
        end

        rst_n = 0; #20;

        $display("\n=== CSR mtvec Debug Test ===\n");

        // Test program
        imem[0] = 32'h300020f3;  // CSRRS x1, mstatus, x0  (read mstatus)
        imem[1] = 32'h00001137;  // LUI x2, 0x1            (x2 = 0x1000)
        imem[2] = 32'h30511073;  // CSRRW x0, mtvec, x2    (write 0x1000 to mtvec)
        imem[3] = 32'h300021f3;  // CSRRS x3, mtvec, x0    (read mtvec)
        imem[4] = 32'h00100073;  // EBREAK

        rst_n = 1; #20;

        repeat(200) @(posedge clk);

        $display("\n=== Results ===");
        $display("x1 (mstatus) = 0x%08x", dut.regfile_inst.registers[1]);
        $display("x2 (LUI 0x1) = 0x%08x (expect 0x00001000)", dut.regfile_inst.registers[2]);
        $display("x3 (mtvec)   = 0x%08x (expect 0x00001000)", dut.regfile_inst.registers[3]);
        $display("mtvec CSR    = 0x%08x", dut.csr_inst.mtvec);

        if (dut.regfile_inst.registers[3] == 32'h00001000) begin
            $display("\n*** TEST PASSED ***");
        end else begin
            $display("\n*** TEST FAILED ***");
            $display("ERROR: x3 should be 0x00001000 but got 0x%08x",
                     dut.regfile_inst.registers[3]);
        end

        $finish;
    end
endmodule
