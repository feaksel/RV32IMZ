/**
 * @file dual_rom.v  
 * @brief Dual ROM Module: 16KB Bootloader + 16KB Application Space
 *
 * Memory Layout:
 * - 0x00000000 - 0x00003FFF: Bootloader ROM (16KB)
 * - 0x00004000 - 0x00007FFF: Application ROM (16KB)
 *
 * This replaces the original rom_32kb.v to support bootloader architecture
 * while maintaining the same external interface.
 */

module dual_rom #(
    parameter ADDR_WIDTH = 15,     // 32KB total = 2^15 bytes
    parameter DATA_WIDTH = 32,
    parameter BOOTLOADER_FILE = "firmware/bootloader/bootloader.hex",
    parameter APP_FILE = "firmware/firmware.hex"
)(
    input  wire                    clk,
    input  wire [ADDR_WIDTH-1:0]   addr,        // Byte address
    input  wire                    stb,         // Wishbone strobe
    output reg  [DATA_WIDTH-1:0]   data_out,
    output reg                     ack
);

    // Memory organization
    localparam BOOTLOADER_DEPTH = (1 << 12);  // 16KB = 4K words
    localparam APP_DEPTH = (1 << 12);          // 16KB = 4K words
    
    // Bootloader ROM: 0x00000000 - 0x00003FFF
    reg [DATA_WIDTH-1:0] bootloader_rom [0:BOOTLOADER_DEPTH-1];
    
    // Application ROM: 0x00004000 - 0x00007FFF  
    reg [DATA_WIDTH-1:0] application_rom [0:APP_DEPTH-1];

    // Initialize ROMs from hex files
    initial begin
        // Load bootloader
        $readmemh(BOOTLOADER_FILE, bootloader_rom);
        
        // Load application (if file exists)
        $readmemh(APP_FILE, application_rom);
        
        // synthesis translate_off
        $display("[DUAL_ROM] Bootloader loaded from %s", BOOTLOADER_FILE);
        $display("[DUAL_ROM] Application loaded from %s", APP_FILE);
        $display("[DUAL_ROM] Memory layout:");
        $display("  0x00000000-0x00003FFF: Bootloader (%0d words)", BOOTLOADER_DEPTH);
        $display("  0x00004000-0x00007FFF: Application (%0d words)", APP_DEPTH);
        
        // Show first bootloader instructions
        $display("[DUAL_ROM] Bootloader entry:");
        $display("  0x00000000: 0x%08X", bootloader_rom[0]);
        $display("  0x00000004: 0x%08X", bootloader_rom[1]);
        $display("  0x00000008: 0x%08X", bootloader_rom[2]);
        // synthesis translate_on
    end

    // Address decoding
    wire is_bootloader = (addr[ADDR_WIDTH-1:14] == 1'b0);  // 0x0000-0x3FFF
    wire is_application = (addr[ADDR_WIDTH-1:14] == 1'b1); // 0x4000-0x7FFF
    
    wire [11:0] bootloader_addr = addr[13:2];  // Word address for bootloader
    wire [11:0] application_addr = addr[13:2]; // Word address for application

    // Synchronous read with address decoding
    always @(posedge clk) begin
        if (stb) begin
            if (is_bootloader) begin
                data_out <= bootloader_rom[bootloader_addr];
            end else if (is_application) begin
                data_out <= application_rom[application_addr];
            end else begin
                data_out <= 32'h00000000;  // Default for unmapped regions
            end
            ack <= 1'b1;
        end else begin
            ack <= 1'b0;
        end
    end

endmodule