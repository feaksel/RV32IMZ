`include "riscv_defines.vh"

/**
 * @file core_macro.v
 * @brief RV32I Core Macro for Hierarchical Implementation
 * 
 * This macro contains everything EXCEPT the MDU:
 * - Pipeline control logic
 * - Register file
 * - ALU
 * - Decoder
 * - CSR unit
 * - Exception unit
 * - Interrupt controller
 * 
 * The MDU is now external and connected through a clean interface.
 * 
 * Target: SKY130 technology, optimized for timing closure
 * Estimated: ~8,000-9,000 cells, 120×120 μm
 * 
 * @author Custom RISC-V Core Team
 * @date 2025-12-18
 * @version 1.0 - Hierarchical Macro Implementation
 */

module core_macro #(
    parameter RESET_VECTOR = 32'h00000000
)(
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

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
    input  wire        dwb_err_i,   // Error

    //==========================================================================
    // MDU Interface (External)
    //==========================================================================

    output wire        mdu_start,
    output wire        mdu_ack,
    output wire [2:0]  mdu_funct3,
    output wire [31:0] mdu_operand_a,
    output wire [31:0] mdu_operand_b,
    input  wire        mdu_busy,
    input  wire        mdu_done,
    input  wire [63:0] mdu_product,
    input  wire [31:0] mdu_quotient,
    input  wire [31:0] mdu_remainder,

    //==========================================================================
    // System Interface
    //==========================================================================

    input  wire [31:0] interrupts
);

    //==========================================================================
    // Internal Core Logic (Modified custom_riscv_core.v)
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

    // MDU control signals (now outputs to external MDU)
    reg         mdu_start_int;
    reg         mdu_ack_int;
    wire        mdu_busy_int;
    wire        mdu_done_int;
    wire [63:0] mdu_product_int;
    wire [31:0] mdu_quotient_int;
    wire [31:0] mdu_remainder_int;

    // temporary register to capture result from MDU
    reg [31:0]  mdu_result_reg;
    // pending state to capture MDU outputs across cycles (avoid read-after-nb race)
    reg [1:0]   mdu_pending;
    // latch for MDU funct3 (so it doesn't change while MDU is running)
    reg [2:0]   mdu_funct3_int;
    // temporary register for MDU selection logic
    reg [31:0]  mdu_selected_temp;

    // Connect internal MDU signals to external interface
    assign mdu_start = mdu_start_int;
    assign mdu_ack = mdu_ack_int;
    assign mdu_funct3 = mdu_funct3_int;
    assign mdu_operand_a = rs1_data;
    assign mdu_operand_b = rs2_data;
    assign mdu_busy_int = mdu_busy;
    assign mdu_done_int = mdu_done;
    assign mdu_product_int = mdu_product;
    assign mdu_quotient_int = mdu_quotient;
    assign mdu_remainder_int = mdu_remainder;

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
    reg [31:0]  trap_pc;
    reg [31:0]  trap_cause;
    reg [31:0]  trap_val;
    wire [31:0] trap_vector;
    wire [31:0] epc_out;

    // Exception signals
    wire        exception_taken;
    wire [31:0] exception_cause;
    wire [31:0] exception_val;

    // Interrupt signals
    wire        interrupt_pending;
    wire        interrupt_enabled;
    wire [31:0] interrupt_cause;

    // System instruction decode signals
    wire        is_ecall;
    wire        is_ebreak;
    wire        is_mret;
    wire        illegal_instr;

    // Instruction retirement counter
    reg         instr_retired;

    //==========================================================================
    // Wishbone Bus Interface Logic
    //==========================================================================

    // Instruction fetch state
    reg         ifetch_req;
    reg         ifetch_ack_r;
    
    // Data memory state
    reg         dmem_req;
    reg         dmem_ack_r;

    // Wishbone instruction bus
    assign iwb_adr_o = pc;
    assign iwb_cyc_o = ifetch_req;
    assign iwb_stb_o = ifetch_req;

    // Wishbone data bus
    assign dwb_adr_o = alu_result;
    assign dwb_dat_o = rs2_data;
    assign dwb_we_o  = mem_write;
    assign dwb_sel_o = 4'b1111;  // Always word access for simplicity
    assign dwb_cyc_o = dmem_req;
    assign dwb_stb_o = dmem_req;

    //==========================================================================
    // ALU Operand Selection
    //==========================================================================

    assign alu_operand_a = rs1_data;
    assign alu_operand_b = alu_src_imm ? immediate : rs2_data;

    //==========================================================================
    // Write-back Data Selection
    //==========================================================================

    assign rd_data = mem_read ? mem_data_reg : 
                     is_m ? mdu_result_reg : 
                     is_jump ? (pc + 4) : 
                     alu_result_reg;

    assign rd_wen = reg_write && (state == STATE_WRITEBACK) && !exception_taken;

    //==========================================================================
    // Branch Logic
    //==========================================================================

    assign branch_taken = is_branch && (
        (funct3 == `FUNCT3_BEQ  && alu_zero) ||
        (funct3 == `FUNCT3_BNE  && !alu_zero) ||
        (funct3 == `FUNCT3_BLT  && alu_result[0]) ||
        (funct3 == `FUNCT3_BGE  && !alu_result[0]) ||
        (funct3 == `FUNCT3_BLTU && alu_result[0]) ||
        (funct3 == `FUNCT3_BGEU && !alu_result[0])
    );

    assign branch_target = pc + immediate;

    //==========================================================================
    // CSR Address Selection
    //==========================================================================

    assign csr_addr = immediate[11:0];
    assign csr_wdata = (funct3[2]) ? {27'b0, rs1_addr} : rs1_data;
    assign csr_op = funct3;

    //==========================================================================
    // Main State Machine (same as original, but MDU is external)
    //==========================================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= RESET_VECTOR;
            state <= STATE_FETCH;
            instruction <= 32'h0;
            ifetch_req <= 1'b0;
            dmem_req <= 1'b0;
            ifetch_ack_r <= 1'b0;
            dmem_ack_r <= 1'b0;
            mem_data_reg <= 32'h0;
            alu_result_reg <= 32'h0;
            trap_entry <= 1'b0;
            trap_return <= 1'b0;
            trap_pc <= 32'h0;
            trap_cause <= 32'h0;
            trap_val <= 32'h0;
            instr_retired <= 1'b0;
            
            // MDU control signals
            mdu_start_int <= 1'b0;
            mdu_ack_int <= 1'b0;
            mdu_result_reg <= 32'h0;
            mdu_pending <= 2'd0;
            mdu_funct3_int <= 3'd0;
        end else begin
            // Default values
            ifetch_ack_r <= iwb_ack_i;
            dmem_ack_r <= dwb_ack_i;
            instr_retired <= 1'b0;
            trap_entry <= 1'b0;
            trap_return <= 1'b0;
            mdu_start_int <= 1'b0;  // Pulse signal
            mdu_ack_int <= 1'b0;    // Pulse signal

            case (state)
                STATE_FETCH: begin
                    if (!ifetch_req) begin
                        ifetch_req <= 1'b1;
                    end else if (iwb_ack_i) begin
                        instruction <= iwb_dat_i;
                        ifetch_req <= 1'b0;
                        state <= STATE_DECODE;
                    end
                end

                STATE_DECODE: begin
                    // Decode happens combinationally
                    state <= STATE_EXECUTE;
                end

                STATE_EXECUTE: begin
                    // Handle exceptions first
                    if (exception_taken) begin
                        trap_entry <= 1'b1;
                        trap_pc <= pc;
                        trap_cause <= exception_cause;
                        trap_val <= exception_val;
                        pc <= trap_vector;
                        state <= STATE_FETCH;
                    end else if (interrupt_pending && interrupt_enabled) begin
                        trap_entry <= 1'b1;
                        trap_pc <= pc;
                        trap_cause <= interrupt_cause;
                        trap_val <= 32'h0;
                        pc <= trap_vector;
                        state <= STATE_FETCH;
                    end else if (is_mret) begin
                        // Return from trap - restore PC and state
                        pc <= epc_out;
                        trap_return <= 1'b1;
                        state <= STATE_FETCH;
                    end else begin

                        // ALU operates
                        if (is_m) begin
                            // Start external MDU
                            mdu_start_int <= 1'b1;
                            mdu_funct3_int <= funct3;
                            mdu_pending <= 2'd0;
                            state <= STATE_MULDIV;
                        end else begin
                            alu_result_reg <= alu_result;

                            if (mem_read || mem_write) begin
                                state <= STATE_MEM;
                            end else begin
                                // Branch/Jump handling
                                if (branch_taken) begin
                                    pc <= branch_target;
                                end else if (is_jump) begin
                                    if (opcode == `OPCODE_JAL) begin
                                        pc <= pc + immediate;
                                    end else begin // JALR
                                        pc <= (rs1_data + immediate) & ~1;
                                    end
                                end else begin
                                    pc <= pc + 4;
                                end
                                state <= STATE_WRITEBACK;
                            end
                        end
                    end
                end

                STATE_MULDIV: begin
                    // Wait for external MDU to complete
                    if (mdu_done_int) begin
                        mdu_ack_int <= 1'b1;
                        mdu_pending <= 2'd1;
                        
                        // Select result based on funct3
                        case (mdu_funct3_int)
                            `FUNCT3_MUL:    mdu_selected_temp = mdu_product_int[31:0];
                            `FUNCT3_MULH:   mdu_selected_temp = mdu_product_int[63:32];
                            `FUNCT3_MULHSU: mdu_selected_temp = mdu_product_int[63:32];
                            `FUNCT3_MULHU:  mdu_selected_temp = mdu_product_int[63:32];
                            `FUNCT3_DIV:    mdu_selected_temp = mdu_quotient_int;
                            `FUNCT3_DIVU:   mdu_selected_temp = mdu_quotient_int;
                            `FUNCT3_REM:    mdu_selected_temp = mdu_remainder_int;
                            `FUNCT3_REMU:   mdu_selected_temp = mdu_remainder_int;
                            default:        mdu_selected_temp = 32'hDEADBEEF;
                        endcase
                        
                        state <= STATE_WRITEBACK;
                    end else if (mdu_pending == 2'd1) begin
                        // Capture result on next cycle
                        mdu_result_reg <= mdu_selected_temp;
                        mdu_pending <= 2'd2;
                        pc <= pc + 4;
                        state <= STATE_WRITEBACK;
                    end
                end

                STATE_MEM: begin
                    if (!dmem_req) begin
                        dmem_req <= 1'b1;
                    end else if (dwb_ack_i) begin
                        if (mem_read) begin
                            mem_data_reg <= dwb_dat_i;
                        end
                        dmem_req <= 1'b0;
                        pc <= pc + 4;
                        state <= STATE_WRITEBACK;
                    end
                end

                STATE_WRITEBACK: begin
                    instr_retired <= 1'b1;
                    state <= STATE_FETCH;
                end

            endcase
        end
    end

    //==========================================================================
    // MODULE INSTANTIATIONS (All except MDU)
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

    // CSR Unit - Control and Status Registers
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

    // Exception Unit - Exception detection and prioritization
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

endmodule