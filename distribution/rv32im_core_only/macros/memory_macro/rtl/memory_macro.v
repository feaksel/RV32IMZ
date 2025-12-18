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
// 32KB ROM (Instruction Memory)
//==============================================================================

reg [31:0] rom_memory [0:8191]; // 32KB = 8K words
reg [31:0] rom_dat_out;
reg        rom_ack;

// Initialize ROM with basic bootloader/program
initial begin
    $readmemh("../../../programs/factorial_imem.vh", rom_memory);
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rom_dat_out <= 32'h0;
        rom_ack <= 1'b0;
    end else begin
        rom_ack <= rom_sel;
        if (rom_sel && !iwb_we_i) begin
            rom_dat_out <= rom_memory[iwb_adr_i[14:2]]; // Word addressed
        end
    end
end

//==============================================================================
// 64KB RAM (Data Memory)
//==============================================================================

reg [31:0] ram_memory [0:16383]; // 64KB = 16K words
reg [31:0] ram_dat_out;
reg        ram_ack;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ram_dat_out <= 32'h0;
        ram_ack <= 1'b0;
    end else begin
        ram_ack <= ram_sel;
        if (ram_sel) begin
            if (dwb_we_i) begin
                // Write operation
                if (dwb_sel_i[0]) ram_memory[dwb_adr_i[15:2]][7:0]   <= dwb_dat_i[7:0];
                if (dwb_sel_i[1]) ram_memory[dwb_adr_i[15:2]][15:8]  <= dwb_dat_i[15:8];
                if (dwb_sel_i[2]) ram_memory[dwb_adr_i[15:2]][23:16] <= dwb_dat_i[23:16];
                if (dwb_sel_i[3]) ram_memory[dwb_adr_i[15:2]][31:24] <= dwb_dat_i[31:24];
            end else begin
                // Read operation
                ram_dat_out <= ram_memory[dwb_adr_i[15:2]];
            end
        end
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