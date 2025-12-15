`timescale 1ns / 1ps
`include "riscv_defines.vh"

module test_mdu_integration;
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
        if (dut.is_m) begin
            $display("[M-EXT] PC=0x%08h instr=0x%08h opcode=0x%02x funct3=%0d funct7=0x%02x is_m=%b", 
                dut.pc, dut.instruction, dut.opcode, dut.funct3, dut.funct7, dut.is_m);
        end
    end

    initial begin
        $dumpfile("test_mdu_integration.vcd");
        $dumpvars(0, test_mdu_integration);
        
        rst_n = 0;
        
        // Test specific M-extension instructions
        mem[0] = 32'h00500113;  // addi x2, x0, 5   
        mem[1] = 32'h00600193;  // addi x3, x0, 6
        mem[2] = 32'h023100b3;  // mul x1, x2, x3   (funct7=0x01, funct3=0x0)  
        mem[3] = 32'h02314533;  // div x10, x2, x3  (funct7=0x01, funct3=0x4) 5/6=0 rem=5
        mem[4] = 32'h02316533;  // rem x10, x2, x3  (funct7=0x01, funct3=0x6) 5%6=5  
        mem[5] = 32'h00000073;  // ecall (end test)
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        repeat(200) @(posedge clk);
        
        $display("=== Final Results ===");
        $display("x1 = %0d (expected 30)", dut.regfile_inst.registers[1]);
        $display("x10 = %0d (expected 0)", dut.regfile_inst.registers[10]);
        $display("x10 = %0d (expected 5)", dut.regfile_inst.registers[10]);
        
        $finish;
    end
endmodule
