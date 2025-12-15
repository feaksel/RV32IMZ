`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_compliance_rv32ui_p_srli;
    reg clk = 0;
    reg rst_n;
    always #5 clk = ~clk;

    wire [31:0] iwb_adr_o, dwb_adr_o, dwb_dat_o;
    wire [31:0] iwb_dat_i, dwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o, dwb_we_o, dwb_cyc_o, dwb_stb_o;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i = 0;
    reg [31:0] interrupts = 0;

    // UNIFIED MEMORY - Single array for both instruction and data access
    // This enables self-modifying code and FENCE.I support
    reg [31:0] mem [0:8191];  // 32KB unified memory
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

    // Instruction fetch from unified memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ack <= 0;
            imem_data <= 32'h00000013;
        end else begin
            if (iwb_stb_o && iwb_cyc_o && !imem_ack) begin
                imem_data <= mem[iwb_adr_o[14:2]];  // Read from unified memory
                imem_ack <= 1;
            end else begin
                imem_ack <= 0;
            end
        end
    end

    // Data read - combinational (Wishbone requires data valid same cycle as ACK)
    always @(*) begin
        if (dwb_stb_o && dwb_cyc_o) begin
            dmem_data = mem[dwb_adr_o[14:2]];  // Read from unified memory
        end else begin
            dmem_data = 32'h0;
        end
    end

    // Data write and tohost monitoring
    reg [31:0] tohost = 0;
    reg [31:0] newv;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ack <= 0;
            tohost <= 0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
                    // Masked write: apply dwb_sel_o to update only selected bytes
                    newv = mem[dwb_adr_o[14:2]];
                    if (dwb_sel_o[0]) newv[7:0]   = dwb_dat_o[7:0];
                    if (dwb_sel_o[1]) newv[15:8]  = dwb_dat_o[15:8];
                    if (dwb_sel_o[2]) newv[23:16] = dwb_dat_o[23:16];
                    if (dwb_sel_o[3]) newv[31:24] = dwb_dat_o[31:24];
                    mem[dwb_adr_o[14:2]] <= newv;  // Write to unified memory
                    // Monitor tohost writes
                    if (dwb_adr_o[14:2] == 1024) begin
                        tohost <= dwb_dat_o;
                        if (dwb_dat_o != 0) begin
                            if (dwb_dat_o == 1) begin
                                $display("\n*** TEST PASSED ***");
                                $finish;
                            end else begin
                                $display("\n*** TEST FAILED *** (code: %0d)", dwb_dat_o >> 1);
                                $finish;
                            end
                        end
                    end
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
        interrupts = 32'h0;

        // Initialize unified memory
        for (i = 0; i < 8192; i = i + 1) begin
            mem[i] = 32'h00000013;  // NOP
        end

        // Load test program into unified memory
        // (RISC-V tests use unified memory with code and data in same binary)
        $readmemh("rv32ui-p-srli.hex", mem);

        #20 rst_n = 1;

        // Timeout after 100000 cycles
        #1000000;
        $display("\n*** TEST TIMEOUT ***");
        $finish;
    end

    // Trace execution for debugging
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_MEM && dwb_cyc_o && !dwb_we_o) begin
            $display("[LOAD] PC=0x%08x addr=0x%08x funct3=%b data=0x%08x",
                     dut.pc, dwb_adr_o, dut.funct3, dwb_dat_i);
        end
        if (rst_n && dut.state == dut.STATE_WRITEBACK && dut.rd_wen && dut.mem_read) begin
            $display("[WB_LOAD] PC=0x%08x x%0d <= 0x%08x (mem_data_reg=0x%08x, addr_offset=%b)",
                     dut.pc, dut.rd_addr, dut.rd_data, dut.mem_data_reg, dut.alu_result_reg[1:0]);
        end
        if (rst_n && dut.state == dut.STATE_TRAP) begin
            $display("[TRAP] PC=0x%08x, cause=0x%08x, val=0x%08x",
                     dut.trap_pc, dut.trap_cause, dut.trap_val);
        end
    end
endmodule
