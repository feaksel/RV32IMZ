`timescale 1ns / 1ps
`include "riscv_defines.vh"

module tb_csr_unit;

    reg        clk;
    reg        rst_n;
    reg [11:0] csr_addr;
    reg [31:0] csr_wdata;
    reg [2:0]  csr_op;
    wire [31:0] csr_rdata;
    wire        csr_valid;

    reg        trap_entry;
    reg        trap_return;
    reg [31:0] trap_pc;
    reg [31:0] trap_cause;
    reg [31:0] trap_val;
    wire [31:0] trap_vector;
    wire [31:0] epc_out;

    reg [31:0] interrupts_i;
    wire       interrupt_pending;
    wire       interrupt_enabled;
    wire [31:0] interrupt_cause;

    reg        instr_retired;

    // Instantiate CSR unit
    csr_unit dut (
        .clk(clk),
        .rst_n(rst_n),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_op(csr_op),
        .csr_rdata(csr_rdata),
        .csr_valid(csr_valid),
        .trap_entry(trap_entry),
        .trap_return(trap_return),
        .trap_pc(trap_pc),
        .trap_cause(trap_cause),
        .trap_val(trap_val),
        .trap_vector(trap_vector),
        .epc_out(epc_out),
        .interrupts_i(interrupts_i),
        .interrupt_pending(interrupt_pending),
        .interrupt_enabled(interrupt_enabled),
        .interrupt_cause(interrupt_cause),
        .instr_retired(instr_retired)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        $dumpfile("csr_unit.vcd");
        $dumpvars(0, tb_csr_unit);

        // Initialize
        rst_n = 0;
        csr_addr = 12'h0;
        csr_wdata = 32'h0;
        csr_op = 3'b000;
        trap_entry = 0;
        trap_return = 0;
        trap_pc = 32'h0;
        trap_cause = 32'h0;
        trap_val = 32'h0;
        interrupts_i = 32'h0;
        instr_retired = 0;

        #20 rst_n = 1;
        #10;

        $display("=== Test 1: Read-Only Registers ===");
        // Read MISA
        csr_addr = `CSR_MISA;
        #10;
        $display("MISA = 0x%h (expected 0x40000100)", csr_rdata);
        assert(csr_rdata == 32'h40000100) else $error("MISA incorrect!");

        // Read MVENDORID
        csr_addr = `CSR_MVENDORID;
        #10;
        $display("MVENDORID = 0x%h", csr_rdata);

        $display("\n=== Test 2: Write and Read mstatus ===");
        // Write to mstatus using CSRRW
        csr_addr = `CSR_MSTATUS;
        csr_wdata = 32'h00000008;  // Set MIE bit
        csr_op = 3'b001;  // CSRRW
        #10;
        csr_op = 3'b000;  // Stop writing
        #10;
        $display("mstatus after write = 0x%h (expected 0x00000008)", csr_rdata);
        assert(csr_rdata == 32'h00000008) else $error("mstatus write failed!");

        $display("\n=== Test 3: Set bits with CSRRS ===");
        // Set additional bits using CSRRS
        csr_addr = `CSR_MSTATUS;
        csr_wdata = 32'h00000080;  // Set MPIE bit
        csr_op = 3'b010;  // CSRRS
        #10;
        csr_op = 3'b000;
        #10;
        $display("mstatus after CSRRS = 0x%h (expected 0x00000088)", csr_rdata);
        assert(csr_rdata == 32'h00000088) else $error("CSRRS failed!");

        $display("\n=== Test 4: Clear bits with CSRRC ===");
        // Clear bits using CSRRC
        csr_addr = `CSR_MSTATUS;
        csr_wdata = 32'h00000008;  // Clear MIE bit
        csr_op = 3'b011;  // CSRRC
        #10;
        csr_op = 3'b000;
        #10;
        $display("mstatus after CSRRC = 0x%h (expected 0x00000080)", csr_rdata);
        assert(csr_rdata == 32'h00000080) else $error("CSRRC failed!");

        $display("\n=== Test 5: Trap Entry ===");
        // Setup trap vector
        csr_addr = `CSR_MTVEC;
        csr_wdata = 32'h00001000;  // Trap vector at 0x1000
        csr_op = 3'b001;
        #10;
        csr_op = 3'b000;
        #10;

        // Enable interrupts
        csr_addr = `CSR_MSTATUS;
        csr_wdata = 32'h00000008;  // Set MIE
        csr_op = 3'b001;
        #10;
        csr_op = 3'b000;
        #10;

        // Trigger trap
        trap_entry = 1;
        trap_pc = 32'h00000100;
        trap_cause = 32'h8000000B;  // External interrupt
        trap_val = 32'h0;
        #10;
        trap_entry = 0;
        #10;

        // Check mepc
        csr_addr = `CSR_MEPC;
        #10;
        $display("mepc = 0x%h (expected 0x00000100)", csr_rdata);
        assert(csr_rdata == 32'h00000100) else $error("mepc not saved!");

        // Check mcause
        csr_addr = `CSR_MCAUSE;
        #10;
        $display("mcause = 0x%h (expected 0x8000000B)", csr_rdata);
        assert(csr_rdata == 32'h8000000B) else $error("mcause not saved!");

        // Check that interrupts are disabled
        csr_addr = `CSR_MSTATUS;
        #10;
        $display("mstatus = 0x%h (MIE should be 0, MPIE should be 1)", csr_rdata);
        assert(csr_rdata[3] == 1'b0) else $error("MIE not cleared!");
        assert(csr_rdata[7] == 1'b1) else $error("MPIE not set!");

        $display("\n=== Test 6: Trap Return (MRET) ===");
        trap_return = 1;
        #10;
        trap_return = 0;
        #10;

        // Check that interrupts are re-enabled
        csr_addr = `CSR_MSTATUS;
        #10;
        $display("mstatus after MRET = 0x%h (MIE should be 1)", csr_rdata);
        assert(csr_rdata[3] == 1'b1) else $error("MIE not restored!");

        $display("\n=== Test 7: Interrupt Pending ===");
        // Enable timer interrupt in mie
        csr_addr = `CSR_MIE;
        csr_wdata = 32'h00000080;  // Bit 7 = timer interrupt
        csr_op = 3'b001;
        #10;
        csr_op = 3'b000;
        #10;

        // Assert timer interrupt
        interrupts_i = 32'h00000080;
        #20;
        $display("interrupt_pending = %b (expected 1)", interrupt_pending);
        $display("interrupt_cause = 0x%h (expected 0x80000007)", interrupt_cause);
        assert(interrupt_pending == 1'b1) else $error("Interrupt not pending!");
        assert(interrupt_cause == 32'h80000007) else $error("Wrong interrupt cause!");

        $display("\n=== Test 8: Performance Counters ===");
        // Retire some instructions
        repeat (10) begin
            instr_retired = 1;
            #10;
            instr_retired = 0;
            #10;
        end

        // Read minstret
        csr_addr = `CSR_MINSTRET;
        #10;
        $display("minstret = %d (expected 10)", csr_rdata);
        assert(csr_rdata == 32'd10) else $error("minstret incorrect!");

        // Read mcycle
        csr_addr = `CSR_MCYCLE;
        #10;
        $display("mcycle = %d", csr_rdata);

        $display("\n=== All Tests Passed! ===");
        #100 $finish;
    end

endmodule