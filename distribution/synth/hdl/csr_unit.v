`include "riscv_defines.vh"

module csr_unit (
    input  wire        clk,
    input  wire        rst_n,

    //==========================================================================
    // CSR Read/Write Interface (from core)
    //==========================================================================

    input  wire [11:0] csr_addr,      // CSR address
    input  wire [31:0] csr_wdata,     // Data to write
    input  wire [2:0]  csr_op,        // Operation: 000=none, 001=RW, 010=RS, 011=RC
    output reg  [31:0] csr_rdata,     // Data read
    output wire        csr_valid,     // CSR address is valid (exists)

    //==========================================================================
    // Trap Interface (from core)
    //==========================================================================

    input  wire        trap_entry,    // Entering trap handler
    input  wire        trap_return,   // Returning from trap (MRET)
    input  wire [31:0] trap_pc,       // PC at time of trap
    input  wire [31:0] trap_cause,    // Exception/interrupt cause
    input  wire [31:0] trap_val,      // Bad address or instruction

    output reg  [31:0] trap_vector,   // Address of trap handler
    output wire [31:0] epc_out,       // Return address (mepc)

    //==========================================================================
    // Interrupt Interface
    //==========================================================================

    input  wire [31:0] interrupts_i,  // Interrupt lines from peripherals
    output wire        interrupt_pending, // Any interrupt pending
    output wire        interrupt_enabled, // Global interrupt enable
    output reg  [31:0] interrupt_cause,   // Which interrupt to service

    //==========================================================================
    // Performance Counters
    //==========================================================================

    input  wire        instr_retired  // Increment minstret when instruction retires
);

    //==========================================================================
    // CSR Registers
    //==========================================================================

    // Machine Trap Setup
    reg [31:0] mstatus;    // Machine status register
    reg [31:0] mie;        // Machine interrupt enable
    reg [31:0] mtvec;      // Machine trap vector base address

    // Machine Trap Handling
    reg [31:0] mscratch;   // Machine scratch register
    reg [31:0] mepc;       // Machine exception program counter
    reg [31:0] mcause;     // Machine trap cause
    reg [31:0] mtval;      // Machine trap value
    reg [31:0] mip;        // Machine interrupt pending (read-only, reflects interrupts_i)

    // Machine Counters
    reg [63:0] mcycle;     // Cycle counter (64-bit)
    reg [63:0] minstret;   // Instructions retired counter (64-bit)

    // Read-only info registers (hardcoded)
    localparam [31:0] MVENDORID = 32'h00000000;  // Non-commercial implementation
    localparam [31:0] MARCHID   = 32'h00000000;  // Architecture ID (0 = not assigned)
    localparam [31:0] MIMPID    = 32'h00000001;  // Implementation version 1
    localparam [31:0] MHARTID   = 32'h00000000;  // Hardware thread ID 0
    localparam [31:0] MISA      = 32'h40000100;  // RV32I + M extension
                                                  // Bit 30: MXL=01 (32-bit)
                                                  // Bit 8:  I extension
                                                  // Bit 12: M extension

    //==========================================================================
    // mstatus Bit Fields
    //==========================================================================

    // Bit positions (as defined in riscv_defines.vh)
    // `MSTATUS_MIE   = 3   (Machine Interrupt Enable)
    // `MSTATUS_MPIE  = 7   (Previous MIE value)
    // `MSTATUS_MPP_LO/HI = 11,12 (Previous privilege mode - always 11 for M-mode)

    wire mie_bit  = mstatus[`MSTATUS_MIE];
    wire mpie_bit = mstatus[`MSTATUS_MPIE];

    //==========================================================================
    // Interrupt Logic
    //==========================================================================

    // Update mip based on external interrupt lines
    always @(posedge clk) begin
        if (!rst_n) begin
            mip <= 32'h0;
        end else begin
            mip <= interrupts_i;
        end
    end

    // Determine if any interrupt is pending and enabled
    wire [31:0] pending_and_enabled = mip & mie;
    assign interrupt_pending = (|pending_and_enabled) && mie_bit;
    assign interrupt_enabled = mie_bit;

    // Priority encoder for interrupts (higher bit = higher priority)
    // Standard RISC-V interrupt priority: external > software > timer
    integer i;
    always @(*) begin
        interrupt_cause = 32'h0;
        for (i = 31; i >= 0; i = i - 1) begin
            if (pending_and_enabled[i]) begin
                interrupt_cause = 32'h80000000 | i;  // Set bit 31 for interrupt
            end
        end
    end

    //==========================================================================
    // Trap Vector Calculation
    //==========================================================================

    // mtvec[1:0] = mode: 00=Direct, 01=Vectored
    // mtvec[31:2] = base address (aligned to 4 bytes)

    wire [1:0]  mtvec_mode = mtvec[1:0];
    wire [31:0] mtvec_base = {mtvec[31:2], 2'b00};

    always @(*) begin
        if (mtvec_mode == 2'b00) begin
            // Direct mode: all traps jump to base address
            trap_vector = mtvec_base;
        end else begin
            // Vectored mode: interrupts jump to base + 4*cause
            if (trap_cause[31]) begin
                // Interrupt: vectored
                trap_vector = mtvec_base + ({trap_cause[30:0], 2'b00});
            end else begin
                // Exception: direct to base
                trap_vector = mtvec_base;
            end
        end
    end

    assign epc_out = mepc;

    //==========================================================================
    // CSR Read Logic
    //==========================================================================

    reg valid;

    always @(*) begin
        csr_rdata = 32'h0;
        valid = 1'b1;

        case (csr_addr)
            // Machine Information Registers
            `CSR_MVENDORID:  csr_rdata = MVENDORID;
            `CSR_MARCHID:    csr_rdata = MARCHID;
            `CSR_MIMPID:     csr_rdata = MIMPID;
            `CSR_MHARTID:    csr_rdata = MHARTID;

            // Machine Trap Setup
            `CSR_MSTATUS:    csr_rdata = mstatus;
            `CSR_MISA:       csr_rdata = MISA;
            `CSR_MIE:        csr_rdata = mie;
            `CSR_MTVEC:      csr_rdata = mtvec;

            // Machine Trap Handling
            `CSR_MSCRATCH:   csr_rdata = mscratch;
            `CSR_MEPC:       csr_rdata = mepc;
            `CSR_MCAUSE:     csr_rdata = mcause;
            `CSR_MTVAL:      csr_rdata = mtval;
            `CSR_MIP:        csr_rdata = mip;

            // Machine Counters
            `CSR_MCYCLE:     csr_rdata = mcycle[31:0];
            `CSR_MCYCLEH:    csr_rdata = mcycle[63:32];
            `CSR_MINSTRET:   csr_rdata = minstret[31:0];
            `CSR_MINSTRETH:  csr_rdata = minstret[63:32];

            // User-accessible counters (shadow mcycle/minstret)
            `CSR_CYCLE:      csr_rdata = mcycle[31:0];
            `CSR_CYCLEH:     csr_rdata = mcycle[63:32];
            `CSR_INSTRET:    csr_rdata = minstret[31:0];
            `CSR_INSTRETH:   csr_rdata = minstret[63:32];

            // Invalid CSR
            default: begin
                csr_rdata = 32'h0;
                valid = 1'b0;
            end
        endcase
    end

    assign csr_valid = valid;

    //==========================================================================
    // CSR Write Logic
    //==========================================================================

    // CSR operations:
    // 000: No operation
    // 001: CSRRW  - Read/Write (write wdata, read old value)
    // 010: CSRRS  - Read and Set bits (set bits from wdata)
    // 011: CSRRC  - Read and Clear bits (clear bits from wdata)
    // 101: CSRRWI - Read/Write Immediate
    // 110: CSRRSI - Read and Set Immediate
    // 111: CSRRCI - Read and Clear Immediate

    wire csr_write = (csr_op != 3'b000);

    reg [31:0] csr_wdata_final;

    always @(*) begin
        case (csr_op[1:0])
            2'b01: csr_wdata_final = csr_wdata;                    // CSRRW/CSRRWI
            2'b10: csr_wdata_final = csr_rdata | csr_wdata;        // CSRRS/CSRRSI
            2'b11: csr_wdata_final = csr_rdata & ~csr_wdata;       // CSRRC/CSRRCI
            default: csr_wdata_final = 32'h0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset values
            mstatus   <= 32'h0;          // MIE=0 (interrupts disabled)
            mie       <= 32'h0;          // All interrupts disabled
            mtvec     <= 32'h00000000;   // Trap vector at address 0 (should be set by software)
            mscratch  <= 32'h0;
            mepc      <= 32'h0;
            mcause    <= 32'h0;
            mtval     <= 32'h0;
            mcycle    <= 64'h0;
            minstret  <= 64'h0;

        end else begin
            // Update performance counters
            mcycle <= mcycle + 64'd1;
            if (instr_retired) begin
                minstret <= minstret + 64'd1;
            end

            //======================================================================
            // Trap Entry
            //======================================================================

            if (trap_entry) begin
                // Save current state
                mepc   <= trap_pc;        // Save PC
                mcause <= trap_cause;     // Save cause
                mtval  <= trap_val;       // Save trap value (bad address/instruction)

                // Update mstatus
                mstatus[`MSTATUS_MPIE] <= mstatus[`MSTATUS_MIE];  // Save current MIE
                mstatus[`MSTATUS_MIE]  <= 1'b0;                    // Disable interrupts
                mstatus[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO] <= 2'b11; // Previous privilege = M-mode

            //======================================================================
            // Trap Return (MRET)
            //======================================================================

            end else if (trap_return) begin
                // Restore previous state
                mstatus[`MSTATUS_MIE]  <= mstatus[`MSTATUS_MPIE];  // Restore MIE
                mstatus[`MSTATUS_MPIE] <= 1'b1;                     // Set MPIE to 1
                mstatus[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO] <= 2'b11; // Stay in M-mode

            //======================================================================
            // Normal CSR Write
            //======================================================================

            end else if (csr_write && valid) begin
                case (csr_addr)
                    `CSR_MSTATUS:   mstatus   <= csr_wdata_final & 32'h00001888; // Only writable bits
                    `CSR_MIE:       mie       <= csr_wdata_final;
                    `CSR_MTVEC:     mtvec     <= csr_wdata_final;
                    `CSR_MSCRATCH:  mscratch  <= csr_wdata_final;
                    `CSR_MEPC:      mepc      <= csr_wdata_final & 32'hFFFFFFFE; // Clear LSB
                    `CSR_MCAUSE:    mcause    <= csr_wdata_final;
                    `CSR_MTVAL:     mtval     <= csr_wdata_final;

                    // Counters (writable)
                    `CSR_MCYCLE:    mcycle[31:0]   <= csr_wdata_final;
                    `CSR_MCYCLEH:   mcycle[63:32]  <= csr_wdata_final;
                    `CSR_MINSTRET:  minstret[31:0] <= csr_wdata_final;
                    `CSR_MINSTRETH: minstret[63:32]<= csr_wdata_final;

                    // Read-only registers - ignore writes
                    default: ;
                endcase
            end
        end
    end

endmodule