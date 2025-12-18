// CPU Core Macro: RV32IM + MDU 
// Complete RISC-V core with multiply/divide unit
// Target: ~11K cells, 120×120μm
// Uses proven 2-macro hierarchical approach internally

module cpu_core_macro (
    input  wire clk,
    input  wire rst_n,
    
    // Instruction Wishbone Bus
    output wire [31:0] iwb_adr_o,
    output wire [31:0] iwb_dat_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_we_o,
    output wire [3:0]  iwb_sel_o,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,
    input  wire        iwb_err_i,
    
    // Data Wishbone Bus
    output wire [31:0] dwb_adr_o,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output wire        dwb_we_o,
    output wire [3:0]  dwb_sel_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,
    input  wire        dwb_err_i,
    
    // Interrupts
    input  wire [15:0] interrupts,
    
    // Debug interface
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire        debug_valid,
    
    // Performance counters
    output wire [31:0] cycle_count,
    output wire [31:0] instr_count
);

//==============================================================================
// Use the proven hierarchical RV32IM implementation
//==============================================================================

rv32im_hierarchical_top u_hierarchical_core (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Instruction Wishbone Bus
    .iwb_adr_o      (iwb_adr_o),
    .iwb_dat_o      (iwb_dat_o),
    .iwb_dat_i      (iwb_dat_i),
    .iwb_we_o       (iwb_we_o),
    .iwb_sel_o      (iwb_sel_o),
    .iwb_cyc_o      (iwb_cyc_o),
    .iwb_stb_o      (iwb_stb_o),
    .iwb_ack_i      (iwb_ack_i),
    .iwb_err_i      (iwb_err_i),
    
    // Data Wishbone Bus  
    .dwb_adr_o      (dwb_adr_o),
    .dwb_dat_o      (dwb_dat_o),
    .dwb_dat_i      (dwb_dat_i),
    .dwb_we_o       (dwb_we_o),
    .dwb_sel_o      (dwb_sel_o),
    .dwb_cyc_o      (dwb_cyc_o),
    .dwb_stb_o      (dwb_stb_o),
    .dwb_ack_i      (dwb_ack_i),
    .dwb_err_i      (dwb_err_i),
    
    // Interrupts
    .interrupts     (interrupts)
);

//==============================================================================
// Debug and Performance Monitoring
//==============================================================================

// Debug interface - expose internal processor state
assign debug_pc = u_hierarchical_core.u_core_macro.pc;
assign debug_instruction = u_hierarchical_core.u_core_macro.instruction;
assign debug_valid = u_hierarchical_core.u_core_macro.instr_retired;

// Performance counters
reg [31:0] cycle_counter;
reg [31:0] instruction_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycle_counter <= 32'h0;
        instruction_counter <= 32'h0;
    end else begin
        cycle_counter <= cycle_counter + 1;
        if (debug_valid) begin
            instruction_counter <= instruction_counter + 1;
        end
    end
end

assign cycle_count = cycle_counter;
assign instr_count = instruction_counter;

endmodule