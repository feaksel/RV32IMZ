`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_trace_branch;
    reg clk = 0;
    reg rst_n;
    always #5 clk = ~clk;

    wire [31:0] iwb_adr_o, dwb_adr_o, dwb_dat_o;
    wire [31:0] iwb_dat_i, dwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o, dwb_we_o, dwb_cyc_o, dwb_stb_o;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i;
    reg [31:0] interrupts;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    reg imem_ack, dmem_ack;
    reg [31:0] imem_data, dmem_data;

    assign iwb_dat_i = imem_data;
    assign dwb_dat_i = dmem_data;
    reg bus_error;
    assign dwb_err_i = bus_error;

    custom_riscv_core dut (
        .clk(clk), .rst_n(rst_n),
        .iwb_adr_o(iwb_adr_o), .iwb_dat_i(iwb_dat_i),
        .iwb_cyc_o(iwb_cyc_o), .iwb_stb_o(iwb_stb_o), .iwb_ack_i(imem_ack),
        .dwb_adr_o(dwb_adr_o), .dwb_dat_o(dwb_dat_o), .dwb_dat_i(dwb_dat_i),
        .dwb_we_o(dwb_we_o), .dwb_sel_o(dwb_sel_o),
        .dwb_cyc_o(dwb_cyc_o), .dwb_stb_o(dwb_stb_o), .dwb_ack_i(dmem_ack),
        .dwb_err_i(dwb_err_i), .interrupts(interrupts)
    );

    // Memory simulation (same as full test)
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
            bus_error <= 0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
                    case (dwb_sel_o)
                        4'b1111: dmem[dwb_adr_o[11:2]] <= dwb_dat_o;
                        default: dmem[dwb_adr_o[11:2]] <= dwb_dat_o;
                    endcase
                end
                dmem_data <= dmem[dwb_adr_o[11:2]];
                dmem_ack <= 1;
            end else begin
                dmem_ack <= 0;
            end
        end
    end

    integer exec_count = 0;
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_WRITEBACK && dut.rd_wen) begin
            exec_count = exec_count + 1;
            $display("[%3d] @0x%02x: x%0d <= 0x%08x (opcode=0x%02x)",
                     exec_count, dut.pc, dut.rd_addr, dut.rd_data, dut.opcode);
        end
    end

    integer i;
    initial begin
        rst_n = 0;
        interrupts = 32'h0;

        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'h00000000;
        end

        #50 rst_n = 1;
        #50;

        $display("\n=== Replicating EXACT sequence from full test ===\n");

        // EXACT copy of TEST 3 from full test
        rst_n = 0; #20; rst_n = 1; #20;
        exec_count = 0;

        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h00a00113;  // ADDI x2, x0, 10
        imem[2] = 32'h00208663;  // BEQ x1, x2, +12
        imem[3] = 32'h00100193;  // ADDI x3, x0, 1
        imem[4] = 32'h00200213;  // ADDI x4, x0, 2
        imem[5] = 32'h00300293;  // ADDI x5, x0, 3
        imem[6] = 32'h00100073;  // EBREAK

        repeat(100) @(posedge clk);  // wait_cycles(100)

        $display("\nAfter 100 cycles:");
        $display("  x1=%0d (expect 10)", dut.regfile_inst.registers[1]);
        $display("  x2=%0d (expect 10)", dut.regfile_inst.registers[2]);
        $display("  x3=%0d (expect 0)", dut.regfile_inst.registers[3]);
        $display("  x4=%0d (expect 0)", dut.regfile_inst.registers[4]);
        $display("  x5=%0d (expect 3)", dut.regfile_inst.registers[5]);

        if (dut.regfile_inst.registers[3] != 0 || dut.regfile_inst.registers[4] != 0) begin
            $display("\n*** BUG REPRODUCED in exact copy of full test! ***");
        end else begin
            $display("\n*** Cannot reproduce - test passes! ***");
        end

        $finish;
    end
endmodule
