`include "riscv_defines.vh"

module exception_unit (
    input  wire [31:0] pc,              // Current PC
    input  wire [31:0] instruction,     // Current instruction
    input  wire [2:0]  funct3,          // Access width for mem ops (from decoder)
    input  wire [31:0] mem_addr,        // Memory address (for load/store)
    input  wire        mem_read,        // Is load instruction
    input  wire        mem_write,       // Is store instruction
    input  wire        bus_error,       // Bus error from Wishbone
    input  wire        illegal_instr,   // From decoder
    input  wire        ecall,           // ECALL instruction
    input  wire        ebreak,          // EBREAK instruction

    output reg         exception_taken, // Exception occurred
    output reg  [31:0] exception_cause, // Exception code
    output reg  [31:0] exception_val    // Bad address or instruction
);

    always @(*) begin
        exception_taken = 1'b0;
        exception_cause = 32'h0;
        exception_val = 32'h0;

        // Priority encoder (check highest priority first)

        // 1. Instruction address misaligned (PC not 4-byte aligned)
        if (pc[1:0] != 2'b00) begin
            exception_taken = 1'b1;
            exception_cause = `MCAUSE_INSTR_MISALIGN;
            exception_val = pc;

        // 2. Instruction access fault (from bus error on fetch)
        // (Handled in fetch stage - not checked here)

        // 3. Illegal instruction
        end else if (illegal_instr) begin
            exception_taken = 1'b1;
            exception_cause = `MCAUSE_ILLEGAL_INSTR;
            exception_val = instruction;

        // 4. Breakpoint (EBREAK)
        end else if (ebreak) begin
            exception_taken = 1'b1;
            exception_cause = `MCAUSE_BREAKPOINT;
            exception_val = pc;

        // 5. Load address misaligned
        end else if (mem_read) begin
            if ((funct3 == `FUNCT3_LH || funct3 == `FUNCT3_LHU) && (mem_addr[0] != 1'b0)) begin
                exception_taken = 1'b1;
                exception_cause = `MCAUSE_LOAD_MISALIGN;
                exception_val = mem_addr;
            end else if ((funct3 == `FUNCT3_LW) && (mem_addr[1:0] != 2'b00)) begin
                exception_taken = 1'b1;
                exception_cause = `MCAUSE_LOAD_MISALIGN;
                exception_val = mem_addr;
            end else if (bus_error) begin
                exception_taken = 1'b1;
                exception_cause = `MCAUSE_LOAD_ACCESS_FAULT;
                exception_val = mem_addr;
            end

        // 6. Store address misaligned
        end else if (mem_write) begin
            if ((funct3 == `FUNCT3_SH) && (mem_addr[0] != 1'b0)) begin
                exception_taken = 1'b1;
                exception_cause = `MCAUSE_STORE_MISALIGN;
                exception_val = mem_addr;
            end else if ((funct3 == `FUNCT3_SW) && (mem_addr[1:0] != 2'b00)) begin
                exception_taken = 1'b1;
                exception_cause = `MCAUSE_STORE_MISALIGN;
                exception_val = mem_addr;
            end else if (bus_error) begin
                exception_taken = 1'b1;
                exception_cause = `MCAUSE_STORE_ACCESS_FAULT;
                exception_val = mem_addr;
            end

        // 7. Environment call (ECALL)
        end else if (ecall) begin
            exception_taken = 1'b1;
            exception_cause = `MCAUSE_ECALL_M_MODE;
            exception_val = 32'h0;
        end
    end

endmodule