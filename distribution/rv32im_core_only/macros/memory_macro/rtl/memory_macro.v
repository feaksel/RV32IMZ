// Memory Macro: 32KB ROM + 64KB RAM
// Combined instruction/data memory subsystem
// Target: ~10K cells, 100×100μm

module memory_macro (
    input  wire clk,
    input  wire rst_n,
    
    // Instruction Wishbone Bus (ROM access)
    input  wire [31:0] iwb_adr_i,
    output wire [31:0] iwb_dat_o,
    input  wire [31:0] iwb_dat_i,
    input  wire        iwb_we_i,
    input  wire [3:0]  iwb_sel_i,
    input  wire        iwb_cyc_i,
    input  wire        iwb_stb_i,
    output wire        iwb_ack_o,
    output wire        iwb_err_o,
    
    // Data Wishbone Bus (RAM access)
    input  wire [31:0] dwb_adr_i,
    output wire [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    input  wire        dwb_we_i,
    input  wire [3:0]  dwb_sel_i,
    input  wire        dwb_cyc_i,
    input  wire        dwb_stb_i,
    output wire        dwb_ack_o,
    output wire        dwb_err_o,
    
    // External memory interface (for bootloader)
    output wire [31:0] ext_mem_adr_o,
    output wire [31:0] ext_mem_dat_o,
    input  wire [31:0] ext_mem_dat_i,
    output wire        ext_mem_we_o,
    output wire [3:0]  ext_mem_sel_o,
    output wire        ext_mem_cyc_o,
    output wire        ext_mem_stb_o,
    input  wire        ext_mem_ack_i,
    input  wire        ext_mem_err_i,
    
    // Memory status
    output wire        rom_ready,
    output wire        ram_ready,
    output wire [31:0] memory_status
);

//==============================================================================
// Address Decode
//==============================================================================

// Memory map:
// 0x00000000 - 0x00007FFF: 32KB ROM (instruction memory)
// 0x20000000 - 0x2000FFFF: 64KB RAM (data memory)
// 0x80000000+: External memory (bootloader/large data)

wire rom_sel = iwb_cyc_i && iwb_stb_i && (iwb_adr_i[31:15] == 17'h0000); // 0x0000_0000-0x0000_7FFF
wire ram_sel = dwb_cyc_i && dwb_stb_i && (dwb_adr_i[31:16] == 16'h2000); // 0x2000_0000-0x2000_FFFF  
wire ext_sel = (iwb_cyc_i && iwb_stb_i && iwb_adr_i[31]) || 
               (dwb_cyc_i && dwb_stb_i && dwb_adr_i[31]); // 0x8000_0000+

//==============================================================================
// 32KB ROM (Instruction Memory) - SRAM Macro Implementation
//==============================================================================
// Using 16 × 2KB SRAM macros to create 32KB ROM
// Each macro: 512 words × 32 bits = 2KB
// Address mapping: [14:11] = bank select, [10:2] = word address

localparam ROM_NUM_MACROS = 16;
wire [31:0] rom_data_from_macros [0:ROM_NUM_MACROS-1];
reg  [31:0] rom_dat_out;
reg         rom_ack;

// ROM banking using SRAM macros
genvar i;
generate
    for (i = 0; i < ROM_NUM_MACROS; i = i + 1) begin : rom_bank
        sky130_sram_2kbyte_1rw1r_32x512_8 sram_rom (
            .clk0(clk),
            .csb0(!(rom_sel && (iwb_adr_i[14:11] == i[3:0]))), // Bank select
            .web0(1'b1),        // Read-only (write always disabled)
            .addr0(iwb_adr_i[10:2]), // 9-bit word address within bank
            .din0(32'h0),       // No writes to ROM
            .dout0(rom_data_from_macros[i])
        );
    end
endgenerate

// ROM output mux and acknowledge
always @(*) begin
    case (iwb_adr_i[14:11])
        4'd0:    rom_dat_out = rom_data_from_macros[0];
        4'd1:    rom_dat_out = rom_data_from_macros[1];
        4'd2:    rom_dat_out = rom_data_from_macros[2];
        4'd3:    rom_dat_out = rom_data_from_macros[3];
        4'd4:    rom_dat_out = rom_data_from_macros[4];
        4'd5:    rom_dat_out = rom_data_from_macros[5];
        4'd6:    rom_dat_out = rom_data_from_macros[6];
        4'd7:    rom_dat_out = rom_data_from_macros[7];
        4'd8:    rom_dat_out = rom_data_from_macros[8];
        4'd9:    rom_dat_out = rom_data_from_macros[9];
        4'd10:   rom_dat_out = rom_data_from_macros[10];
        4'd11:   rom_dat_out = rom_data_from_macros[11];
        4'd12:   rom_dat_out = rom_data_from_macros[12];
        4'd13:   rom_dat_out = rom_data_from_macros[13];
        4'd14:   rom_dat_out = rom_data_from_macros[14];
        4'd15:   rom_dat_out = rom_data_from_macros[15];
        default: rom_dat_out = 32'h00000013; // NOP instruction
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rom_ack <= 1'b0;
    end else begin
        rom_ack <= rom_sel; // 1-cycle latency for SRAM
    end
end

//==============================================================================
// 64KB RAM (Data Memory) - SRAM Macro Implementation
//==============================================================================
// Using 32 × 2KB SRAM macros to create 64KB RAM
// Each macro: 512 words × 32 bits = 2KB
// Address mapping: [15:11] = bank select, [10:2] = word address

localparam RAM_NUM_MACROS = 32;
wire [31:0] ram_data_from_macros [0:RAM_NUM_MACROS-1];
reg  [31:0] ram_dat_out;
reg         ram_ack;

// RAM banking using SRAM macros
generate
    for (i = 0; i < RAM_NUM_MACROS; i = i + 1) begin : ram_bank
        sky130_sram_2kbyte_1rw1r_32x512_8 sram_ram (
            .clk0(clk),
            .csb0(!(ram_sel && (dwb_adr_i[15:11] == i[4:0]))), // Bank select
            .web0(!dwb_we_i),   // Write enable (active low)
            .addr0(dwb_adr_i[10:2]), // 9-bit word address within bank
            .din0(dwb_dat_i),   // Write data
            .dout0(ram_data_from_macros[i])
        );
    end
endgenerate

// RAM output mux and acknowledge
always @(*) begin
    case (dwb_adr_i[15:11])
        5'd0:    ram_dat_out = ram_data_from_macros[0];
        5'd1:    ram_dat_out = ram_data_from_macros[1];
        5'd2:    ram_dat_out = ram_data_from_macros[2];
        5'd3:    ram_dat_out = ram_data_from_macros[3];
        5'd4:    ram_dat_out = ram_data_from_macros[4];
        5'd5:    ram_dat_out = ram_data_from_macros[5];
        5'd6:    ram_dat_out = ram_data_from_macros[6];
        5'd7:    ram_dat_out = ram_data_from_macros[7];
        5'd8:    ram_dat_out = ram_data_from_macros[8];
        5'd9:    ram_dat_out = ram_data_from_macros[9];
        5'd10:   ram_dat_out = ram_data_from_macros[10];
        5'd11:   ram_dat_out = ram_data_from_macros[11];
        5'd12:   ram_dat_out = ram_data_from_macros[12];
        5'd13:   ram_dat_out = ram_data_from_macros[13];
        5'd14:   ram_dat_out = ram_data_from_macros[14];
        5'd15:   ram_dat_out = ram_data_from_macros[15];
        5'd16:   ram_dat_out = ram_data_from_macros[16];
        5'd17:   ram_dat_out = ram_data_from_macros[17];
        5'd18:   ram_dat_out = ram_data_from_macros[18];
        5'd19:   ram_dat_out = ram_data_from_macros[19];
        5'd20:   ram_dat_out = ram_data_from_macros[20];
        5'd21:   ram_dat_out = ram_data_from_macros[21];
        5'd22:   ram_dat_out = ram_data_from_macros[22];
        5'd23:   ram_dat_out = ram_data_from_macros[23];
        5'd24:   ram_dat_out = ram_data_from_macros[24];
        5'd25:   ram_dat_out = ram_data_from_macros[25];
        5'd26:   ram_dat_out = ram_data_from_macros[26];
        5'd27:   ram_dat_out = ram_data_from_macros[27];
        5'd28:   ram_dat_out = ram_data_from_macros[28];
        5'd29:   ram_dat_out = ram_data_from_macros[29];
        5'd30:   ram_dat_out = ram_data_from_macros[30];
        5'd31:   ram_dat_out = ram_data_from_macros[31];
        default: ram_dat_out = 32'h00000000;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ram_ack <= 1'b0;
    end else begin
        ram_ack <= ram_sel; // 1-cycle latency for SRAM
    end
end

//==============================================================================
// External Memory Interface
//==============================================================================

// Forward external memory requests
assign ext_mem_adr_o = ext_sel ? (iwb_cyc_i ? iwb_adr_i : dwb_adr_i) : 32'h0;
assign ext_mem_dat_o = ext_sel ? (iwb_cyc_i ? iwb_dat_i : dwb_dat_i) : 32'h0;
assign ext_mem_we_o  = ext_sel ? (iwb_cyc_i ? iwb_we_i : dwb_we_i) : 1'b0;
assign ext_mem_sel_o = ext_sel ? (iwb_cyc_i ? iwb_sel_i : dwb_sel_i) : 4'h0;
assign ext_mem_cyc_o = ext_sel ? (iwb_cyc_i || dwb_cyc_i) : 1'b0;
assign ext_mem_stb_o = ext_sel ? (iwb_stb_i || dwb_stb_i) : 1'b0;

reg ext_ack;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ext_ack <= 1'b0;
    end else begin
        ext_ack <= ext_sel && ext_mem_ack_i;
    end
end

//==============================================================================
// Output Multiplexing
//==============================================================================

// Instruction bus outputs
assign iwb_dat_o = rom_sel ? rom_dat_out : 
                   ext_sel ? ext_mem_dat_i : 
                   32'h00000013; // NOP if no valid selection

assign iwb_ack_o = rom_sel ? rom_ack :
                   ext_sel ? ext_ack :
                   1'b0;

assign iwb_err_o = ext_sel ? ext_mem_err_i : 1'b0;

// Data bus outputs  
assign dwb_dat_o = ram_sel ? ram_dat_out :
                   ext_sel ? ext_mem_dat_i :
                   32'h00000000;

assign dwb_ack_o = ram_sel ? ram_ack :
                   ext_sel ? ext_ack :
                   1'b0;

assign dwb_err_o = ext_sel ? ext_mem_err_i : 1'b0;

//==============================================================================
// Status Signals
//==============================================================================

assign rom_ready = 1'b1; // ROM always ready
assign ram_ready = 1'b1; // RAM always ready

// Memory status register
assign memory_status = {
    16'h0000,           // [31:16] Reserved
    1'b1,               // [15] ROM initialized  
    1'b1,               // [14] RAM ready
    1'b0,               // [13] External memory error
    ext_mem_ack_i,      // [12] External memory active
    4'h0,               // [11:8] Reserved
    8'h96               // [7:0] Memory macro version
};

endmodule