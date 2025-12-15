`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_full_trace;
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
                if (dwb_we_o) dmem[dwb_adr_o[11:2]] <= dwb_dat_o;
                dmem_data <= dmem[dwb_adr_o[11:2]];
                dmem_ack <= 1;
            end else begin
                dmem_ack <= 0;
            end
        end
    end

    // Trace EVERY state transition
    always @(posedge clk) begin
        if (rst_n) begin
            case (dut.state)
                dut.STATE_FETCH: if (imem_ack)
                    $display("[FETCH   ] PC=0x%02x, instr=0x%08x", dut.pc, imem_data);
                dut.STATE_DECODE:
                    $display("[DECODE  ] opcode=0x%02x, rd=x%0d, is_branch=%b, is_jump=%b", 
                             dut.opcode, dut.rd_addr, dut.is_branch, dut.is_jump);
                dut.STATE_EXECUTE:
                    $display("[EXECUTE ] alu_result=0x%08x, alu_zero=%b", dut.alu_result, dut.alu_zero);
                dut.STATE_WRITEBACK: begin
                    $display("[WBACK  ] rd_wen=%b, rd_data=0x%08x, next_pc will be 0x%02x", 
                             dut.rd_wen, dut.rd_data, 
                             dut.is_jump ? (dut.opcode == 7'h6f ? dut.pc + dut.immediate : (dut.rs1_data + dut.immediate) & ~32'h1) :
                             dut.is_branch ? (dut.alu_zero ? dut.pc + dut.immediate : dut.pc + 4) :
                             dut.pc + 4);
                    $display("");
                end
            endcase
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

        rst_n = 0; #20; rst_n = 1; #20;

        $display("\n=== DETAILED TRACE ===\n");

        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h00a00113;  // ADDI x2, x0, 10
        imem[2] = 32'h00208663;  // BEQ x1, x2, +12
        imem[3] = 32'h00100193;  // ADDI x3, x0, 1
        imem[4] = 32'h00200213;  // ADDI x4, x0, 2
        imem[5] = 32'h00300293;  // ADDI x5, x0, 3

        #500;  // Run for limited time

        $display("\n=== FINAL STATE ===");
        $display("x1=%0d, x2=%0d, x3=%0d, x4=%0d, x5=%0d",
                 dut.regfile_inst.registers[1],
                 dut.regfile_inst.registers[2],
                 dut.regfile_inst.registers[3],
                 dut.regfile_inst.registers[4],
                 dut.regfile_inst.registers[5]);

        $finish;
    end
endmodule
