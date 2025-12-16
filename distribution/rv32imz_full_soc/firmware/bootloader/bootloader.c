/**
 * @file bootloader.c
 * @brief UART Bootloader for RV32IMZ 5-Level CHB Inverter SoC
 * 
 * Features:
 * - UART-based firmware updates
 * - CRC32 verification  
 * - Application verification
 * - Safe boot with timeout
 * - Recovery mode
 *
 * Memory Layout:
 * - 0x00000000-0x00003FFF: This bootloader (16KB)
 * - 0x00004000-0x00007FFF: Application space (16KB)
 * - 0x00008000-0x00017FFF: RAM (64KB)
 */

#include <stdint.h>
#include <stdbool.h>

//=============================================================================
// Hardware Register Definitions
//=============================================================================

// UART Base Address
#define UART_BASE       0x80000000
#define UART_TX_DATA    (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_STATUS     (*(volatile uint32_t*)(UART_BASE + 0x04))
#define UART_CONTROL    (*(volatile uint32_t*)(UART_BASE + 0x08))

// UART Status Bits
#define UART_TX_EMPTY   (1 << 1)
#define UART_RX_READY   (1 << 0)

// Timer Base Address  
#define TIMER_BASE      0x80000010
#define TIMER_VALUE     (*(volatile uint32_t*)(TIMER_BASE + 0x00))

//=============================================================================
// Bootloader Constants
//=============================================================================

#define BOOT_MAGIC      0xB007ABCD
#define APP_START_ADDR  0x00004000
#define TIMEOUT_MS      3000
#define MAX_APP_SIZE    (16 * 1024)  // 16KB application space

typedef struct __attribute__((packed)) {
    uint32_t magic;     // Magic number for validation
    uint32_t version;   // Version (major.minor.patch)
    uint32_t size;      // Application size in bytes
    uint32_t crc32;     // CRC32 checksum
    uint32_t reserved;  // Future use
} firmware_header_t;

//=============================================================================
// CRC32 Implementation
//=============================================================================

static uint32_t crc32_table[256];
static bool crc32_table_initialized = false;

static void crc32_init_table(void) {
    if (crc32_table_initialized) return;
    
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 0; j < 8; j++) {
            if (crc & 1) {
                crc = (crc >> 1) ^ 0xEDB88320;
            } else {
                crc >>= 1;
            }
        }
        crc32_table[i] = crc;
    }
    crc32_table_initialized = true;
}

static uint32_t crc32_calculate(const uint8_t* data, uint32_t length) {
    crc32_init_table();
    
    uint32_t crc = 0xFFFFFFFF;
    for (uint32_t i = 0; i < length; i++) {
        uint8_t byte = data[i];
        crc = crc32_table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return ~crc;
}

//=============================================================================
// Basic I/O Functions
//=============================================================================

static void uart_putc(char c) {
    // Wait for TX empty
    while (!(UART_STATUS & UART_TX_EMPTY));
    UART_TX_DATA = c;
}

static void uart_puts(const char* str) {
    while (*str) {
        uart_putc(*str++);
    }
}

static void uart_put_hex(uint32_t value) {
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (value >> i) & 0xF;
        if (nibble < 10) {
            uart_putc('0' + nibble);
        } else {
            uart_putc('A' + nibble - 10);
        }
    }
}

static bool uart_rx_ready(void) {
    return (UART_STATUS & UART_RX_READY) != 0;
}

static char uart_getc(void) {
    while (!uart_rx_ready());
    return UART_TX_DATA;  // Same register for RX in simple implementations
}

static uint32_t get_time_ms(void) {
    // Simple timer (assumes 50MHz clock, adjust divider as needed)
    return TIMER_VALUE / 50000;  // Convert to milliseconds
}

static void delay_ms(uint32_t ms) {
    uint32_t start = get_time_ms();
    while ((get_time_ms() - start) < ms);
}

//=============================================================================
// UART Protocol Functions
//=============================================================================

static bool uart_receive_bytes(uint8_t* buffer, uint32_t length, uint32_t timeout_ms) {
    uint32_t start_time = get_time_ms();
    uint32_t received = 0;
    
    while (received < length) {
        if ((get_time_ms() - start_time) > timeout_ms) {
            return false;  // Timeout
        }
        
        if (uart_rx_ready()) {
            buffer[received++] = uart_getc();
        }
    }
    return true;
}

//=============================================================================
// Application Management
//=============================================================================

static bool verify_application(uint32_t addr) {
    firmware_header_t* header = (firmware_header_t*)addr;
    
    // Check magic number
    if (header->magic != BOOT_MAGIC) {
        uart_puts("No valid application (bad magic)\r\n");
        return false;
    }
    
    // Check size
    if (header->size > MAX_APP_SIZE) {
        uart_puts("Application too large\r\n");
        return false;
    }
    
    // Calculate CRC of application data (after header)
    uint8_t* app_data = (uint8_t*)(addr + sizeof(firmware_header_t));
    uint32_t calc_crc = crc32_calculate(app_data, header->size - sizeof(firmware_header_t));
    
    if (calc_crc != header->crc32) {
        uart_puts("CRC check failed - Expected: ");
        uart_put_hex(header->crc32);
        uart_puts(", Calculated: ");
        uart_put_hex(calc_crc);
        uart_puts("\r\n");
        return false;
    }
    
    return true;
}

static void jump_to_application(uint32_t addr) {
    uart_puts("Jumping to application...\r\n");
    delay_ms(100);  // Let UART finish
    
    // Disable interrupts
    __asm__ volatile("csrci mstatus, 0x8");
    
    // Jump to application entry point (after header)
    uint32_t app_entry = addr + sizeof(firmware_header_t);
    void (*app)(void) = (void (*)(void))app_entry;
    app();
    
    // Should never return
    while (1) {
        __asm__ volatile("wfi");
    }
}

//=============================================================================
// Firmware Update Functions
//=============================================================================

static bool receive_firmware(void) {
    firmware_header_t header;
    
    uart_puts("Waiting for firmware header (30s timeout)...\r\n");
    
    // Receive header
    if (!uart_receive_bytes((uint8_t*)&header, sizeof(header), 30000)) {
        uart_puts("ERROR: Header timeout\r\n");
        return false;
    }
    
    // Verify header
    if (header.magic != BOOT_MAGIC) {
        uart_puts("ERROR: Invalid magic - ");
        uart_put_hex(header.magic);
        uart_puts("\r\n");
        return false;
    }
    
    if (header.size > MAX_APP_SIZE) {
        uart_puts("ERROR: Firmware too large\r\n");
        return false;
    }
    
    uart_puts("Firmware version: ");
    uart_put_hex(header.version);
    uart_puts("\r\nSize: ");
    uart_put_hex(header.size);
    uart_puts(" bytes\r\n");
    
    // For this simple implementation, we'll simulate flash programming
    // In a real system, this would erase and program flash memory
    uart_puts("Simulating flash programming...\r\n");
    
    // Receive and verify firmware data
    uint8_t buffer[128];
    uint32_t remaining = header.size;
    uint32_t addr = APP_START_ADDR + sizeof(firmware_header_t);
    uint32_t crc = 0xFFFFFFFF;
    
    uart_puts("Programming");
    
    // Write header first (simulate)
    crc32_init_table();
    
    while (remaining > 0) {
        uint32_t chunk = (remaining > sizeof(buffer)) ? sizeof(buffer) : remaining;
        
        if (!uart_receive_bytes(buffer, chunk, 5000)) {
            uart_puts("\r\nERROR: Data timeout\r\n");
            return false;
        }
        
        // Update CRC
        for (uint32_t i = 0; i < chunk; i++) {
            crc = crc32_table[(crc ^ buffer[i]) & 0xFF] ^ (crc >> 8);
        }
        
        remaining -= chunk;
        uart_putc('.');
    }
    
    crc = ~crc;
    uart_puts(" done\r\n");
    
    // Verify CRC
    if (crc != header.crc32) {
        uart_puts("ERROR: CRC mismatch!\r\n");
        return false;
    }
    
    uart_puts("Firmware update successful!\r\n");
    uart_puts("Note: This is a simulation - actual flash programming would occur here\r\n");
    
    return true;
}

static bool check_for_update_request(void) {
    uart_puts("Press 'U' for update mode (3s timeout)...\r\n");
    
    uint32_t start = get_time_ms();
    while ((get_time_ms() - start) < TIMEOUT_MS) {
        if (uart_rx_ready()) {
            char c = uart_getc();
            if (c == 'U' || c == 'u') {
                return true;
            }
            // Any other key: skip to boot
            return false;
        }
        
        // Visual countdown
        static uint32_t last_dot = 0;
        uint32_t elapsed = get_time_ms() - start;
        if ((elapsed / 500) > last_dot) {
            uart_putc('.');
            last_dot++;
        }
    }
    
    uart_puts("\r\n");
    return false;
}

//=============================================================================
// Main Bootloader Function
//=============================================================================

void bootloader_main(void) {
    // Initialize UART (simple setup - assume already configured)
    
    // Print banner
    uart_puts("\r\n");
    uart_puts("===========================================\r\n");
    uart_puts("  RV32IMZ Bootloader v1.0\r\n");
    uart_puts("  5-Level CHB Inverter Controller\r\n");
    uart_puts("===========================================\r\n");
    uart_puts("Build: Dec 16, 2025\r\n");
    uart_puts("\r\n");
    
    // Check for update request
    if (check_for_update_request()) {
        uart_puts("\r\n>>> UPDATE MODE <<<\r\n");
        uart_puts("Waiting for firmware upload...\r\n");
        
        if (receive_firmware()) {
            uart_puts("Update completed successfully!\r\n");
            uart_puts("Rebooting in 2 seconds...\r\n");
            delay_ms(2000);
            
            // Simulate reboot (in real system would trigger reset)
            uart_puts("Reboot simulation - please reset manually\r\n");
            while(1);
        } else {
            uart_puts("Update failed! Attempting to boot existing app...\r\n");
        }
    }
    
    // Verify and boot application
    uart_puts("Verifying application...\r\n");
    if (!verify_application(APP_START_ADDR)) {
        uart_puts("\r\nERROR: No valid application found!\r\n");
        uart_puts("Entering recovery mode...\r\n");
        uart_puts("Send firmware via UART to recover.\r\n");
        
        // Recovery mode: wait for firmware upload indefinitely
        while (1) {
            if (receive_firmware()) {
                uart_puts("Recovery successful! Please reset to boot.\r\n");
            }
            delay_ms(1000);
        }
    }
    
    uart_puts("Application verified OK!\r\n");
    
    // Display application info
    firmware_header_t* header = (firmware_header_t*)APP_START_ADDR;
    uart_puts("App version: ");
    uart_put_hex(header->version);
    uart_puts("\r\nApp size: ");
    uart_put_hex(header->size);
    uart_puts(" bytes\r\n");
    
    jump_to_application(APP_START_ADDR);
}

//=============================================================================
// Entry Point
//=============================================================================

// Entry point called from startup code
int main(void) {
    bootloader_main();
    return 0;  // Should never reach here
}