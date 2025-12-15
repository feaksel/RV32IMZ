`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_exception_debug;
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

    // Detailed state and exception tracing
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_DECODE) begin
            $display("[DECODE] PC=0x%02x, instr=0x%08x, illegal=%b, ecall=%b, ebreak=%b",
                     dut.pc, dut.instruction, dut.illegal_instr, dut.is_ecall, dut.is_ebreak);
        end

        if (rst_n && dut.exception_taken) begin
            $display("[EXCEPTION] cause=0x%08x, val=0x%08x, PC=0x%02x",
                     dut.exception_cause, dut.exception_val, dut.pc);
        end

        if (rst_n && dut.trap_entry) begin
            $display("[TRAP ENTRY] trap_pc=0x%02x, trap_cause=0x%08x, trap_vector=0x%02x",
                     dut.trap_pc, dut.trap_cause, dut.trap_vector);
        end

        if (rst_n && dut.state == dut.STATE_WRITEBACK && dut.rd_wen) begin
            $display("[WB] x%0d <= 0x%08x", dut.rd_addr, dut.rd_data);
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

        $display("\n=== Exception Handling Debug Test ===\n");

        // Setup trap handler at 0x100 (imem[64])
        imem[64] = 32'h00100093;  // ADDI x1, x0, 1 (trap handler marker)
        imem[65] = 32'h30200073;  // MRET

        // Main program
        imem[0] = 32'h00100137;   // LUI x2, 0x100 (x2 = 0x00100000)
        imem[1] = 32'h30511073;   // CSRRW x0, mtvec, x2 (mtvec = 0x00100000)
        imem[2] = 32'h00800093;   // ADDI x1, x0, 8 (MIE bit)
        imem[3] = 32'h30009073;   // CSRRW x0, mstatus, x1 (enable interrupts)
        imem[4] = 32'hFFFFFFFF;   // Illegal instruction
        imem[5] = 32'h00200113;   // ADDI x2, x0, 2 (should NOT execute)
        imem[6] = 32'h00100073;   // EBREAK

        rst_n = 1; #20;

        $display("\nmtvec = 0x%08x", dut.csr_inst.mtvec);
        $display("mstatus = 0x%08x", dut.csr_inst.mstatus);

        repeat(300) @(posedge clk);

        $display("\n=== Results ===");
        $display("x1 = %d (expect 1 from handler)", dut.regfile_inst.registers[1]);
        $display("x2 = 0x%08x (expect 0x00100000 from LUI)", dut.regfile_inst.registers[2]);
        $display("mepc = 0x%08x", dut.csr_inst.mepc);
        $display("mcause = 0x%08x", dut.csr_inst.mcause);

        if (dut.regfile_inst.registers[1] == 1 && dut.regfile_inst.registers[2] == 32'h00100000) begin
            $display("\n*** TEST PASSED ***");
        end else begin
            $display("\n*** TEST FAILED ***");
        end

        $finish;
    end
endmodule
