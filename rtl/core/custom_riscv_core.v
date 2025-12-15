`include "riscv_defines.vh"

/**
 * @file custom_riscv_core.v
 * @brief Custom RV32IM RISC-V Core with Zpec Extension (Native Wishbone)
 *
 * This is the main processor core implementing:
 * - RV32I base integer instruction set (40 instructions)
 * - M extension: multiply/divide (8 instructions)
 * - Zpec extension: power electronics custom instructions (6 instructions)
 *
 * Architecture: 3-stage pipeline (Fetch, Decode/Execute, Writeback)
 * ISA: RV32IM + Zpec
 * Bus: Native Wishbone B4 (Approach 2 - Cleaner Design)
 *
 * IMPLEMENTATION APPROACH: Native Wishbone (Approach 2)
 * - Core uses standard Wishbone B4 protocol directly
 * - No cmd/rsp conversion needed
 * - Cleaner, more reusable design
 * - Wrapper is just a simple passthrough
 *
 * @author Custom RISC-V Core Team
 * @date 2025-12-03
 * @version 0.2 - Approach 2: Native Wishbone Template
 */

module custom_riscv_core #(
    parameter RESET_VECTOR = 32'h00000000  // Reset PC address
)(
    input  wire        clk,
    input  wire        rst_n,  // Active LOW reset (Wishbone standard)

    //==========================================================================
    // Instruction Wishbone Bus (Master)
    //==========================================================================

    output wire [31:0] iwb_adr_o,   // Instruction address
    input  wire [31:0] iwb_dat_i,   // Instruction data from memory
    output wire        iwb_cyc_o,   // Cycle active
    output wire        iwb_stb_o,   // Strobe
    input  wire        iwb_ack_i,   // Acknowledge

    //==========================================================================
    // Data Wishbone Bus (Master)
    //==========================================================================

    output wire [31:0] dwb_adr_o,   // Data address
    output wire [31:0] dwb_dat_o,   // Data to write
    input  wire [31:0] dwb_dat_i,   // Data read from memory/peripheral
    output wire        dwb_we_o,    // Write enable (1=write, 0=read)
    output wire [3:0]  dwb_sel_o,   // Byte select
    output wire        dwb_cyc_o,   // Cycle active
    output wire        dwb_stb_o,   // Strobe
    input  wire        dwb_ack_i,   // Acknowledge
    input  wire        dwb_err_i,   // Bus error

    //==========================================================================
    // Interrupts
    //==========================================================================

    input  wire [31:0] interrupts   // Interrupt inputs [31:0]
);

    //==========================================================================
    // IMPLEMENTATION GUIDE - Approach 2: Native Wishbone
    //==========================================================================

    /**
     * WISHBONE PROTOCOL BASICS:
     *
     * Read Cycle:
     *   1. Master asserts CYC, STB, ADR (and clears WE)
     *   2. Slave sees STB=1, prepares data
     *   3. Slave asserts ACK with valid data on DAT_I
     *   4. Master reads data, clears CYC/STB
     *
     * Write Cycle:
     *   1. Master asserts CYC, STB, ADR, DAT_O, WE, SEL
     *   2. Slave sees STB=1 and WE=1, writes data
     *   3. Slave asserts ACK
     *   4. Master clears CYC/STB
     *
     * IMPLEMENTATION STRATEGY:
     *
     * Stage 1: Fetch
     *   - Generate iwb_adr_o = PC
     *   - Assert iwb_cyc_o, iwb_stb_o
     *   - Wait for iwb_ack_i
     *   - Latch instruction from iwb_dat_i
     *   - Increment PC
     *
     * Stage 2: Decode/Execute
     *   - Decode instruction
     *   - Read register file
     *   - Execute ALU operation
     *   - For LOAD/STORE:
     *     * Assert dwb_cyc_o, dwb_stb_o
     *     * Set dwb_adr_o, dwb_we_o, dwb_sel_o
     *     * Wait for dwb_ack_i
     *   - For branches: update PC
     *
     * Stage 3: Writeback
     *   - Write result to register file
     *   - For LOAD: write dwb_dat_i to register
     *
     * START SIMPLE:
     *   1. Implement single-cycle (no pipeline) first
     *   2. Just fetch → decode → execute → writeback sequentially
     *   3. Add pipelining later for performance
     */

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Program Counter
    reg [31:0] pc;

    // Instruction register
    reg [31:0] instruction;

    // Register file signals
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [31:0] rs1_data, rs2_data, rd_data;
    wire        rd_wen;

    // Decode signals
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] immediate;

    // ALU signals
    wire [31:0] alu_operand_a, alu_operand_b;
    wire [3:0]  alu_op;
    wire [31:0] alu_result;
    wire        alu_zero;
    // M-extension signal from decoder
    wire        is_m;
    // ZPEC-extension signal from decoder (always 0)
    wire        is_zpec;

    // Memory data register (to capture load data)
    reg [31:0]  mem_data_reg;

    // ALU result register (to capture ALU output)
    reg [31:0]  alu_result_reg;



    // Control signals from decoder
    wire        alu_src_imm;      // ALU source: 0=rs2, 1=immediate
    wire        mem_read;         // Memory read enable (loads)
    wire        mem_write;        // Memory write enable (stores)
    wire        reg_write;        // Register write enable
    wire        is_branch;        // Is branch instruction
    wire        is_jump;          // Is jump instruction
    wire        is_system;        // Is system instruction
    wire        branch_taken;
    wire [31:0] branch_target;

    // State machine (for multi-cycle operations)
    reg [2:0] state;
    localparam STATE_FETCH     = 3'd0;
    localparam STATE_DECODE    = 3'd1;
    localparam STATE_EXECUTE   = 3'd2;
    localparam STATE_MEM       = 3'd3;
    localparam STATE_WRITEBACK = 3'd4;
    localparam STATE_MULDIV    = 3'd5;
    localparam STATE_TRAP      = 3'd6;

    reg         mdu_start;
    reg         mdu_ack;
    wire        mdu_busy;
    wire        mdu_done;
    wire [63:0] mdu_product;
    wire [31:0] mdu_quotient;
    wire [31:0] mdu_remainder;

    // temporary register to capture result from MDU
    reg [31:0]  mdu_result_reg;
    // pending state to capture MDU outputs across cycles (avoid read-after-nb race)
    reg [1:0]   mdu_pending;
    // latch for MDU funct3 (so it doesn't change while MDU is running)
    reg [2:0]   mdu_funct3;
    // temporary register for MDU selection logic
    reg [31:0]  mdu_selected_temp;

    //==========================================================================
    // CSR and Trap Handling Signals
    //==========================================================================

    // CSR interface signals
    wire [11:0] csr_addr;
    wire [31:0] csr_wdata;
    wire [2:0]  csr_op;
    wire [31:0] csr_rdata;
    wire        csr_valid;

    // Trap handling signals
    reg         trap_entry;
    reg         trap_return;
    reg  [31:0] trap_pc;
    reg  [31:0] trap_cause;
    reg  [31:0] trap_val;
    wire [31:0] trap_vector;
    wire [31:0] epc_out;

    // Interrupt signals (from CSR unit)
    wire        interrupt_pending;
    wire        interrupt_enabled;
    wire [31:0] interrupt_cause;

    // interrupt_req is just interrupt_pending (CSR unit handles enable checking)
    wire        interrupt_req = interrupt_pending;

    // Exception signals
    wire        exception_taken;
    wire [31:0] exception_cause;
    wire [31:0] exception_val;

    // System instruction decoding
    wire        is_mret;
    wire        is_ecall;
    wire        is_ebreak;
    wire        illegal_instr;

    // Stall signal (not used yet but referenced)
    wire        stall = 1'b0;

    // Instruction retired signal for performance counters
    wire        instr_retired;

    // Wishbone control
    reg iwb_cyc_reg, iwb_stb_reg;
    reg dwb_cyc_reg, dwb_stb_reg;
    reg [31:0] dwb_adr_reg, dwb_dat_reg;
    reg dwb_we_reg;
    reg [3:0] dwb_sel_reg;

    assign iwb_cyc_o = iwb_cyc_reg;
    assign iwb_stb_o = iwb_stb_reg;
    assign iwb_adr_o = pc;

    assign dwb_cyc_o = dwb_cyc_reg;
    assign dwb_stb_o = dwb_stb_reg;
    assign dwb_adr_o = dwb_adr_reg;
    assign dwb_dat_o = dwb_dat_reg;
    assign dwb_we_o = dwb_we_reg;
    assign dwb_sel_o = dwb_sel_reg;

    // For AUIPC, operand A is PC; for LUI, operand A should be zero
    assign alu_operand_a = (opcode == `OPCODE_AUIPC) ? pc :
                           (opcode == `OPCODE_LUI)   ? 32'h0 : rs1_data;
    assign alu_operand_b = alu_src_imm ? immediate : rs2_data;

    // Load data processing (byte/halfword extraction and sign extension)
    wire [31:0] load_data_processed;
    wire [1:0]  load_addr_offset = alu_result_reg[1:0];  // Lower 2 bits of address
    wire [7:0]  load_byte;
    wire [15:0] load_halfword;
    wire        load_sign_bit;

    // Select byte based on address offset (use mem_data_reg captured in STATE_MEM)
    assign load_byte = (load_addr_offset == 2'b00) ? mem_data_reg[7:0] :
                       (load_addr_offset == 2'b01) ? mem_data_reg[15:8] :
                       (load_addr_offset == 2'b10) ? mem_data_reg[23:16] :
                                                       mem_data_reg[31:24];

    // Select halfword based on address offset (supports misaligned halfword access)
    // offset 00: bytes [1:0] = mem_data_reg[15:0]
    // offset 01: bytes [2:1] = mem_data_reg[23:8]
    // offset 10: bytes [3:2] = mem_data_reg[31:16]
    // offset 11: Would need next word's byte 0 - not supported, just use upper halfword
    assign load_halfword = (load_addr_offset == 2'b00) ? mem_data_reg[15:0] :
                           (load_addr_offset == 2'b01) ? mem_data_reg[23:8] :
                                                          mem_data_reg[31:16];

    // Determine sign bit for sign extension
    assign load_sign_bit = (funct3 == `FUNCT3_LB)  ? load_byte[7] :
                           (funct3 == `FUNCT3_LH)  ? load_halfword[15] :
                           1'b0;

    // Process load data based on funct3
    assign load_data_processed =
        (funct3 == `FUNCT3_LB)  ? {{24{load_sign_bit}}, load_byte} :      // LB: sign-extend byte
        (funct3 == `FUNCT3_LH)  ? {{16{load_sign_bit}}, load_halfword} :  // LH: sign-extend halfword
        (funct3 == `FUNCT3_LBU) ? {24'b0, load_byte} :                     // LBU: zero-extend byte
        (funct3 == `FUNCT3_LHU) ? {16'b0, load_halfword} :                 // LHU: zero-extend halfword
        mem_data_reg;                                                      // LW: full word

    assign rd_data = mem_read ? load_data_processed :
                     is_system ? csr_rdata :
                     is_jump ? (pc + 4) :      // Return address for JAL/JALR
                     alu_result_reg;
    assign rd_wen = reg_write && (state == STATE_WRITEBACK) && !is_branch;

    // CSR operation decoding
    assign csr_addr = instruction[31:20];
    assign csr_wdata = (funct3[2]) ? {27'b0, instruction[19:15]} : rs1_data;  // Immediate or register
    assign csr_op = (is_system && !is_mret && !is_ecall && !is_ebreak) ? funct3 : 3'b000;

    // Instruction retired when we complete writeback
    assign instr_retired = (state == STATE_WRITEBACK);

    // Note: is_mret, is_ecall, is_ebreak, illegal_instr now come from decoder


    // Initialize PC on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_VECTOR;
            state <= STATE_FETCH;
            iwb_cyc_reg <= 1'b0;
            iwb_stb_reg <= 1'b0;
            dwb_cyc_reg <= 1'b0;
            dwb_stb_reg <= 1'b0;
            mdu_start <= 1'b0;
            mdu_ack <= 1'b0;
            mdu_result_reg <= 32'd0;
            mdu_pending <= 2'd0;
            mem_data_reg <= 32'd0;
            trap_entry <= 1'b0;
            trap_return <= 1'b0;
            trap_pc <= 32'h0;
            trap_cause <= 32'h0;
            trap_val <= 32'h0;
        end else begin
            case (state)
                STATE_FETCH: begin
                // Clear trap_return flag if it was set
                trap_return <= 1'b0;

                if (interrupt_req && !stall) begin
                    trap_entry <= 1'b1;
                    trap_pc <= pc;
                    trap_cause <= interrupt_cause;
                    trap_val <= 32'h0;
                    state <= STATE_TRAP;
                end else begin

                    // Request instruction from memory
                    iwb_cyc_reg <= 1'b1;
                    iwb_stb_reg <= 1'b1;

                    if (iwb_ack_i) begin
                        instruction <= iwb_dat_i;
                        iwb_cyc_reg <= 1'b0;
                        iwb_stb_reg <= 1'b0;
                        state <= STATE_DECODE;
                        `ifdef SIMULATION
                        $display("[FETCH] PC=0x%08h instr=0x%08h", pc, iwb_dat_i);
                        `endif
                    end
                end

        end

                STATE_DECODE: begin
                    // Decoder runs combinationally
                    // Register file reads happen here
                    state <= STATE_EXECUTE;
                end

                STATE_EXECUTE: begin

                // Check for exceptions
                    `ifdef SIMULATION
                    $display("[EXEC] PC=0x%08h instr=0x%08h opcode=0x%02h funct3=%b funct7=0x%02h is_m=%b", pc, instruction, opcode, funct3, funct7, is_m);
                    `endif
                    if (exception_taken) begin
                    trap_entry <= 1'b1;
                    trap_pc <= pc;
                    trap_cause <= exception_cause;
                    trap_val <= exception_val;
                    state <= STATE_TRAP;
                end else if (is_mret) begin
                    // Return from trap - restore PC and state
                    pc <= epc_out;
                    trap_return <= 1'b1;
                    state <= STATE_FETCH;
                end else begin

                    // ALU operates
                    if (is_m) begin
                        // Start multiply/divide unit based on funct3
                        // Start pulse lasts one cycle
                        // Start unified MDU
                        mdu_start <= 1'b1;
                        mdu_funct3 <= funct3;
                        mdu_pending <= 2'd0;
                        `ifdef SIMULATION
                        $display("[CORE] MDU START: pc=0x%08h funct3=%0d rs1=0x%08h rs2=0x%08h", pc, funct3, rs1_data, rs2_data);
                        `endif
                        state <= STATE_MULDIV;
                    end else begin
                        alu_result_reg <= alu_result;

                        `ifdef SIMULATION
                        if (funct3 == `FUNCT3_SLL || funct3 == `FUNCT3_SRL_SRA) begin
                            $display("[ALU] PC=0x%08h funct3=%b rs1=0x%08h rs2_imm=0x%08h result=0x%08h", pc, funct3, rs1_data, alu_operand_b, alu_result);
                        end
                        `endif

                        if (opcode == `OPCODE_MISC_MEM) begin
                            // FENCE / FENCE.I: ensure memory ordering by waiting
                            // for outstanding data bus cycles to complete
                            if (!dwb_cyc_reg) begin
                                state <= STATE_WRITEBACK;
                            end else begin
                                // Stay in execute stage until stores complete
                                state <= STATE_EXECUTE;
                            end
                        end else if (mem_read || mem_write) begin
                            state <= STATE_MEM;
                        end else begin
                            state <= STATE_WRITEBACK;
                        end
                    end
                end

                end

                STATE_TRAP: begin
                // Jump to trap handler
                pc <= trap_vector;
                trap_entry <= 1'b0;
                state <= STATE_FETCH;
            end



                STATE_MULDIV: begin
                    // Clear one-cycle start pulse
                    mdu_start <= 1'b0;

                    // Wait for MDU completion
                    if (mdu_done && mdu_pending == 2'd0) begin
                        // Pulse seen: wait one cycle for MDU outputs to be stable (avoid non-blocking update race)
                        mdu_pending <= 2'd1;
                        state <= STATE_MULDIV;
                    end else if (mdu_pending == 2'd1) begin
                        // Capture MDU outputs now (product/quotient/remainder stable)
                        case (mdu_funct3)
                            `FUNCT3_MUL:    mdu_selected_temp = mdu_product[31:0];
                            `FUNCT3_MULH:   mdu_selected_temp = mdu_product[63:32];
                            `FUNCT3_MULHSU: mdu_selected_temp = mdu_product[63:32];
                            `FUNCT3_MULHU:  mdu_selected_temp = mdu_product[63:32];
                            `FUNCT3_DIV:    mdu_selected_temp = mdu_quotient;
                            `FUNCT3_DIVU:   mdu_selected_temp = mdu_quotient;
                            `FUNCT3_REM:    mdu_selected_temp = mdu_remainder;
                            `FUNCT3_REMU:   mdu_selected_temp = mdu_remainder;
                            default:        mdu_selected_temp = mdu_product[31:0];
                        endcase
                        mdu_result_reg <= mdu_selected_temp;
                        // Wait one more cycle to move `mdu_result_reg` into `alu_result_reg` (avoids race)
                        `ifdef SIMULATION
                        $display("[CORE] MDU CAPTURE: pc=0x%08h start_funct3=%0d mdu_product=0x%016h mdu_quotient=0x%08h mdu_remainder=0x%08h selected=0x%08h", pc, mdu_funct3, mdu_product, mdu_quotient, mdu_remainder, mdu_selected_temp);
                        `endif
                        mdu_pending <= 2'd2;
                        state <= STATE_MULDIV;
                    end else if (mdu_pending == 2'd2) begin
                        // now move to writeback after `mdu_result_reg` is stable
                        alu_result_reg <= mdu_result_reg;
                        mdu_pending <= 2'd0;
                        mdu_ack <= 1'b1;  // Signal MDU that we've completed processing
                        state <= STATE_WRITEBACK;
                    end else begin
                        // remain in MULDIV until unit signals done
                        state <= STATE_MULDIV;
                    end
                end

                STATE_MEM: begin
                    if (mem_read || mem_write) begin
                        dwb_cyc_reg <= 1'b1;
                        dwb_stb_reg <= 1'b1;
                        dwb_adr_reg <= alu_result_reg;  // Address from ALU
                        dwb_we_reg <= mem_write;

                        `ifdef SIMULATION
                        $display("[CORE] MEM START: PC=0x%08h addr=0x%08h we=%b sel=0b%b dat=0x%08h funct3=%0d", pc, dwb_adr_reg, dwb_we_reg, dwb_sel_reg, dwb_dat_reg, funct3);
                        `endif

                        if (mem_write) begin
                            // Replicate store data across all byte lanes for byte/halfword stores
                            case (funct3)
                                3'b000: begin  // SB: replicate byte to all lanes
                                    dwb_dat_reg <= {4{rs2_data[7:0]}};
                                    dwb_sel_reg <= 4'b0001 << alu_result_reg[1:0];
                                end
                                3'b001: begin  // SH: replicate halfword to both lanes
                                    dwb_dat_reg <= {2{rs2_data[15:0]}};
                                    dwb_sel_reg <= 4'b0011 << {alu_result_reg[1], 1'b0};
                                end
                                3'b010: begin  // SW: full word
                                    dwb_dat_reg <= rs2_data;
                                    dwb_sel_reg <= 4'b1111;
                                end
                                default: begin
                                    dwb_dat_reg <= rs2_data;
                                    dwb_sel_reg <= 4'b1111;
                                end
                            endcase
                        end else begin
                            dwb_sel_reg <= 4'b1111;  // Full word for loads
                        end

                        if (dwb_ack_i) begin
                            dwb_cyc_reg <= 1'b0;
                            dwb_stb_reg <= 1'b0;
                            // Capture memory data for loads
                            if (mem_read) begin
                                mem_data_reg <= dwb_dat_i;
                                `ifdef SIMULATION
                                $display("[CORE] MEM READ ACK: addr=0x%08h dat=0x%08h sel=0b%b funct3=%0d", dwb_adr_reg, dwb_dat_i, dwb_sel_reg, funct3);
                                `endif
                            end
                            if (mem_write) begin
                                `ifdef SIMULATION
                                $display("[CORE] MEM WRITE ACK: addr=0x%08h dat=0x%08h sel=0b%b funct3=%0d", dwb_adr_reg, dwb_dat_reg, dwb_sel_reg, funct3);
                                `endif
                            end
                            state <= STATE_WRITEBACK;
                        end
                    end else begin
                        state <= STATE_WRITEBACK;
                    end
                end

                STATE_WRITEBACK: begin
                    // Clear mdu_ack after one cycle
                    if (mdu_ack) mdu_ack <= 1'b0;
                    
                    // Register write happens via rd_wen signal (combinational)

                    `ifdef SIMULATION
                    if (rd_wen) begin
                        $display("[WB] PC=0x%08h rd=x%0d rd_data=0x%08h rd_wen=%b mem_read=%b mem_write=%b alu_result=0x%08h mem_data_reg=0x%08h load_processed=0x%08h", pc, rd_addr, rd_data, rd_wen, mem_read, mem_write, alu_result_reg, mem_data_reg, load_data_processed);
                    end
                    `endif

                    // Update PC
                    if (is_jump) begin
                        if (opcode == `OPCODE_JAL) begin
                            pc <= pc + immediate;
                        end else begin  // JALR
                            pc <= (rs1_data + immediate) & ~32'h1;
                        end
                    end else if (is_branch) begin
                        // Check branch condition based on funct3
                        // For unsigned comparisons, use proper unsigned comparison logic
                        case (funct3)
                            `FUNCT3_BEQ:  if (alu_zero) pc <= pc + immediate; else pc <= pc + 4;
                            `FUNCT3_BNE:  if (!alu_zero) pc <= pc + immediate; else pc <= pc + 4;
                            `FUNCT3_BLT:  if (alu_result[31]) pc <= pc + immediate; else pc <= pc + 4;
                            `FUNCT3_BGE:  if (!alu_result[31]) pc <= pc + immediate; else pc <= pc + 4;
                            `FUNCT3_BLTU: if (rs1_data < rs2_data) pc <= pc + immediate; else pc <= pc + 4;  // Unsigned comparison
                            `FUNCT3_BGEU: if (rs1_data >= rs2_data) pc <= pc + immediate; else pc <= pc + 4; // Unsigned comparison
                            default: pc <= pc + 4;
                        endcase
                    end else begin
                        pc <= pc + 4;
                    end

                    state <= STATE_FETCH;
                end
            endcase

        end
    end

    //==========================================================================
    // MODULE INSTANTIATIONS
    //==========================================================================
    
    // Register File
    regfile regfile_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rd_wen(rd_wen),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // ALU
    alu alu_inst (
        .operand_a(alu_operand_a),
        .operand_b(alu_operand_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Instruction Decoder
    decoder decoder_inst (
        .instruction(instruction),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .immediate(immediate),
        // Control signals
        .alu_op(alu_op),
        .alu_src_imm(alu_src_imm),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .reg_write(reg_write),
        .is_branch(is_branch),
        .is_jump(is_jump),
        .is_system(is_system),
        .is_m(is_m),
        .is_zpec(is_zpec),

        // System instruction decode
        .is_ecall(is_ecall),
        .is_ebreak(is_ebreak),
        .is_mret(is_mret),
        .is_wfi(),  // Not used yet
        .illegal_instr(illegal_instr)
    );

    //==========================================================================
    // CSR Unit - Control and Status Registers
    //==========================================================================

    csr_unit csr_inst (
        .clk(clk),
        .rst_n(rst_n),

        // CSR Read/Write Interface
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_op(csr_op),
        .csr_rdata(csr_rdata),
        .csr_valid(csr_valid),

        // Trap Interface
        .trap_entry(trap_entry),
        .trap_return(trap_return),
        .trap_pc(trap_pc),
        .trap_cause(trap_cause),
        .trap_val(trap_val),
        .trap_vector(trap_vector),
        .epc_out(epc_out),

        // Interrupt Interface
        .interrupts_i(interrupts),
        .interrupt_pending(interrupt_pending),
        .interrupt_enabled(interrupt_enabled),
        .interrupt_cause(interrupt_cause),

        // Performance Counters
        .instr_retired(instr_retired)
    );

    //==========================================================================
    // Exception Unit - Exception detection and prioritization
    //==========================================================================

    exception_unit exc_unit (
        .pc(pc),
        .instruction(instruction),
        .funct3(funct3),
        // Use combinational ALU result for current instruction address
        .mem_addr(alu_result),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .bus_error(dwb_err_i),
        .illegal_instr(illegal_instr),
        .ecall(is_ecall),
        .ebreak(is_ebreak),

        .exception_taken(exception_taken),
        .exception_cause(exception_cause),
        .exception_val(exception_val)
    );

    // Unified MDU instance (handles MUL/MULH/MULHSU/MULHU and DIV/DIVU/REM/REMU)
    mdu mdu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(mdu_start),
        .ack(mdu_ack),
        .funct3(funct3),
        .a(rs1_data),
        .b(rs2_data),
        .busy(mdu_busy),
        .done(mdu_done),
        .product(mdu_product),
        .quotient(mdu_quotient),
        .remainder(mdu_remainder)
    );



endmodule
