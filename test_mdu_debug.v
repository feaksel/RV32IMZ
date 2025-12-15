`timescale 1ns / 1ps
`include "riscv_defines.vh"

module test_mdu_debug;
    reg clk, rst_n;
    reg [31:0] interrupts = 0;
    
    wire [31:0] iwb_adr_o, dwb_adr_o, dwb_dat_o;
    wire [31:0] iwb_dat_i, dwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o, dwb_we_o, dwb_cyc_o, dwb_stb_o;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i = 0;
    
    reg [31:0] mem [0:8191];
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
    
    // Memory interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ack <= 0;
            dmem_ack <= 0;
            imem_data <= 32'h00000013;
            dmem_data <= 32'h0;
        end else begin
            if (iwb_stb_o && iwb_cyc_o && !imem_ack) begin
                imem_data <= mem[iwb_adr_o[14:2]];
                imem_ack <= 1;
            end else begin
                imem_ack <= 0;
            end
            
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
                    mem[dwb_adr_o[14:2]] <= dwb_dat_o; 
                end else begin
                    dmem_data <= mem[dwb_adr_o[14:2]];
                end
                dmem_ack <= 1;
            end else begin
                dmem_ack <= 0;
            end
        end
    end

    initial clk = 0;
    always #5 clk = ~clk;
    
    // Debug monitors
    always @(posedge clk) begin
        if (dut.state == 3'd5) begin // STATE_MULDIV
            $display("[MDUDEBUG] cycle=%0d state=MULDIV mdu_start=%b mdu_done=%b mdu_busy=%b mdu_pending=%0d", 
                $time/10, dut.mdu_start, dut.mdu_done, dut.mdu_busy, dut.mdu_pending);
        end
        if (dut.mdu_start) begin
            $display("[MDUDEBUG] MDU START: pc=0x%08h funct3=%0d a=%0d b=%0d", 
                dut.pc, dut.mdu_funct3, dut.rs1_data, dut.rs2_data);
        end
        if (dut.mdu_done) begin
            $display("[MDUDEBUG] MDU DONE: pc=0x%08h product=0x%016h quotient=%0d remainder=%0d", 
                dut.pc, dut.mdu_product, dut.mdu_quotient, dut.mdu_remainder);
        end
    end

    initial begin
        $dumpfile("test_mdu_debug.vcd");
        $dumpvars(0, test_mdu_debug);
        
        rst_n = 0;
        
        // Initialize memory with simple MUL instruction: mul x1, x2, x3
        // x2 = 5, x3 = 6, expect x1 = 30
        mem[0] = 32'h00500113;  // addi x2, x0, 5   
        mem[1] = 32'h00600193;  // addi x3, x0, 6
        mem[2] = 32'h023100b3;  // mul x1, x2, x3   (0x02310033)
        mem[3] = 32'h00000073;  // ecall (end test)
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        repeat(100) @(posedge clk);
        
        if (dut.regfile_inst.registers[1] == 30) begin
            $display("SUCCESS: x1 = %0d (expected 30)", dut.regfile_inst.registers[1]);
        end else begin
            $display("FAILURE: x1 = %0d (expected 30)", dut.regfile_inst.registers[1]);
        end
        
        $display("Final register state:");
        $display("x1 = %0d, x2 = %0d, x3 = %0d", dut.regfile_inst.registers[1], dut.regfile_inst.registers[2], dut.regfile_inst.registers[3]);
        
        $finish;
    end
endmodule
