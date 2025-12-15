# RISC-V Bootloader Guide

**Complete guide to bootloader design and implementation for embedded RISC-V systems**

---

## Table of Contents

1. [What is a Bootloader?](#what-is-a-bootloader)
2. [Why You Need a Bootloader](#why-you-need-a-bootloader)
3. [Boot Process Overview](#boot-process-overview)
4. [Memory Layout](#memory-layout)
5. [Bootloader Types](#bootloader-types)
6. [RISC-V Specific Considerations](#risc-v-specific-considerations)
7. [Implementation: Simple Bootloader](#implementation-simple-bootloader)
8. [Implementation: UART Bootloader](#implementation-uart-bootloader)
9. [Implementation: Flash Programmer](#implementation-flash-programmer)
10. [Security Considerations](#security-considerations)
11. [Troubleshooting](#troubleshooting)

---

## What is a Bootloader?

A **bootloader** is a small program that runs when your processor powers up or resets. Its job is to:

1. **Initialize hardware** (clocks, memory, peripherals)
2. **Load application code** from storage (flash, UART, SD card, network)
3. **Transfer control** to the main application
4. **Provide update mechanism** (optional but recommended)

### Analogy

Think of it like your computer's BIOS/UEFI:
- **BIOS** (bootloader) → initializes hardware, finds OS
- **Operating System** (your application) → runs the actual programs

### In Your RISC-V Inverter

```
Power On
   ↓
Bootloader (0x0000_0000) ← You write this
   ↓
   ├─ Initialize hardware
   ├─ Check for update request
   └─ Jump to application
      ↓
Main Application (0x0001_0000) ← Your inverter control code
   ↓
   ├─ PWM control
   ├─ ADC sampling
   └─ Control loops
```

---

## Why You Need a Bootloader

### Problem Without Bootloader

**Scenario:** You've deployed 10 inverters in the field. You find a bug.

**Without bootloader:**
1. Remove device from installation
2. Connect JTAG debugger
3. Reflash via programmer
4. Reinstall device
5. **Cost:** 1 hour per device × 10 devices = 10 hours 😓

**With bootloader:**
1. Connect USB/UART cable
2. Send update command
3. Upload new firmware (30 seconds)
4. **Cost:** 5 minutes per device × 10 devices = 50 minutes 🎉

### Benefits

| Feature | Without Bootloader | With Bootloader |
|---------|-------------------|-----------------|
| **Field updates** | Impossible | Easy (UART/USB) |
| **Recovery** | Need JTAG | Self-recovery possible |
| **Multi-image** | Single app only | Multiple firmwares |
| **Diagnostics** | Limited | Built-in test mode |
| **Security** | None | Signature verification |

---

## Boot Process Overview

### Standard RISC-V Boot Sequence

```
┌─────────────────────────────────────────────────────────────┐
│                      POWER ON / RESET                        │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 0: Hardware Reset                                      │
│  • PC = 0x0000_0000 (reset vector)                          │
│  • All registers = 0                                         │
│  • Machine mode (M-mode)                                     │
│  • Interrupts disabled                                       │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: First-Stage Bootloader (ROM/Flash @ 0x0000_0000)   │
│  • Initialize critical hardware:                             │
│    - Clock configuration                                     │
│    - Memory controller                                       │
│    - Stack pointer (SP)                                      │
│  • Load second-stage bootloader (if needed)                  │
│  • Duration: < 1ms                                           │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Second-Stage Bootloader (Flash @ 0x0000_1000)      │
│  • Initialize remaining peripherals:                         │
│    - UART (for communication)                                │
│    - Timer (for timeouts)                                    │
│    - GPIO (for status LEDs)                                  │
│  • Check for update request:                                 │
│    - Button pressed?                                         │
│    - Magic value in RAM?                                     │
│    - UART command received?                                  │
│  • If update requested:                                      │
│    - Enter update mode (receive new firmware)                │
│    - Program flash                                           │
│    - Verify integrity                                        │
│  • If no update:                                             │
│    - Validate application image                              │
│    - Jump to application                                     │
│  • Duration: 10-100ms                                        │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Application (Flash @ 0x0001_0000)                  │
│  • Your main program runs                                    │
│  • Inverter control loop                                     │
│  • Can request reboot to bootloader if needed                │
└─────────────────────────────────────────────────────────────┘
```

### Key Points

1. **PC starts at 0x0000_0000** - This is hardwired in RISC-V (reset vector)
2. **Bootloader must be at address 0** - First instruction executed
3. **Application at higher address** - Bootloader jumps there when ready
4. **Can't brick the device** - Bootloader is read-only (or protected)

---

## Memory Layout

### Typical Embedded RISC-V Memory Map

```
┌──────────────────┬─────────┬────────────────────────────────┐
│   Address Range  │  Size   │         Purpose                │
├──────────────────┼─────────┼────────────────────────────────┤
│ 0x0000_0000      │   4 KB  │ First-Stage Bootloader (ROM)   │
│                  │         │  - Reset handler               │
│                  │         │  - Clock init                  │
│                  │         │  - Jump to stage 2             │
├──────────────────┼─────────┼────────────────────────────────┤
│ 0x0000_1000      │  12 KB  │ Second-Stage Bootloader        │
│                  │         │  - UART protocol               │
│                  │         │  - Flash programmer            │
│                  │         │  - Update logic                │
├──────────────────┼─────────┼────────────────────────────────┤
│ 0x0000_4000      │  48 KB  │ Application Code               │
│ (or 0x0001_0000) │ (or more│  - Your inverter firmware      │
│                  │         │  - Control algorithms          │
│                  │         │  - Peripheral drivers          │
├──────────────────┼─────────┼────────────────────────────────┤
│ 0x0001_0000      │  64 KB  │ Data RAM                       │
│ (separate)       │         │  - Variables                   │
│                  │         │  - Stack                       │
│                  │         │  - Heap                        │
├──────────────────┼─────────┼────────────────────────────────┤
│ 0x0002_0000      │  16 KB  │ Shared Communication Buffer    │
│                  │         │  - Bootloader ↔ App messages   │
│                  │         │  - Update requests             │
├──────────────────┼─────────┼────────────────────────────────┤
│ 0x4000_0000      │   ---   │ Memory-Mapped Peripherals      │
│                  │         │  - PWM, ADC, UART, etc.        │
└──────────────────┴─────────┴────────────────────────────────┘
```

### Linker Script for Bootloader

```ld
/* bootloader.ld - Linker script for first-stage bootloader */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)   : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rwx)  : ORIGIN = 0x00010000, LENGTH = 4K
}

SECTIONS
{
    /* Reset vector and boot code */
    .text : {
        KEEP(*(.text.start))     /* Reset handler first */
        *(.text*)
        *(.rodata*)
    } > ROM

    /* Data section */
    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > RAM AT > ROM

    /* BSS (zero-initialized) */
    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    /* Stack (grows downward) */
    .stack : {
        . = ALIGN(16);
        . = . + 1K;  /* 1KB stack */
        _stack_top = .;
    } > RAM
}
```

### Linker Script for Application

```ld
/* application.ld - Linker script for main application */

OUTPUT_ARCH("riscv")
ENTRY(_app_start)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00004000, LENGTH = 48K   /* After bootloader */
    RAM (rwx)   : ORIGIN = 0x00010000, LENGTH = 60K   /* Main RAM */
}

SECTIONS
{
    /* Application vector table (if using interrupts) */
    .vectors : {
        KEEP(*(.vectors))
    } > FLASH

    /* Application code */
    .text : {
        *(.text*)
        *(.rodata*)
    } > FLASH

    /* Rest same as bootloader */
    .data : { /* ... */ } > RAM AT > FLASH
    .bss  : { /* ... */ } > RAM

    /* Larger stack for application */
    .stack : {
        . = ALIGN(16);
        . = . + 8K;  /* 8KB stack */
        _stack_top = .;
    } > RAM
}
```

---

## Bootloader Types

### Type 1: Simple Jump Bootloader

**Simplest possible - just initialize and jump.**

```c
// simple_boot.c - Minimal bootloader
void _start(void) __attribute__((section(".text.start"), naked));

void _start(void) {
    // 1. Set stack pointer
    __asm__ volatile("la sp, _stack_top");

    // 2. Initialize .data section (copy from flash to RAM)
    extern uint32_t _data_start, _data_end, _data_load;
    uint32_t *src = &_data_load;
    uint32_t *dst = &_data_start;
    while (dst < &_data_end) {
        *dst++ = *src++;
    }

    // 3. Zero .bss section
    extern uint32_t _bss_start, _bss_end;
    dst = &_bss_start;
    while (dst < &_bss_end) {
        *dst++ = 0;
    }

    // 4. Jump to application
    #define APP_START_ADDR 0x00004000
    void (*app_entry)(void) = (void (*)(void))APP_START_ADDR;
    app_entry();  // Never returns
}
```

**Use case:** Development only, no field updates possible.

### Type 2: UART Update Bootloader

**Can update firmware via serial port.**

```c
// uart_boot.c - UART-based bootloader

#define BOOT_MAGIC      0xDEADBEEF
#define APP_START_ADDR  0x00004000
#define TIMEOUT_MS      3000

typedef struct {
    uint32_t magic;
    uint32_t size;
    uint32_t crc32;
    uint8_t  data[];
} firmware_image_t;

void bootloader_main(void) {
    uart_init(115200);
    timer_init();

    uart_puts("Bootloader v1.0\r\n");
    uart_puts("Press 'U' for update, any key to boot app...\r\n");

    // Wait for command with timeout
    uint32_t start_time = get_time_ms();
    while ((get_time_ms() - start_time) < TIMEOUT_MS) {
        if (uart_rx_ready()) {
            char cmd = uart_getc();

            if (cmd == 'U' || cmd == 'u') {
                // Enter update mode
                uart_puts("Update mode. Waiting for image...\r\n");

                if (receive_and_program_firmware()) {
                    uart_puts("Update successful!\r\n");
                } else {
                    uart_puts("Update failed!\r\n");
                }

                uart_puts("Rebooting...\r\n");
                delay_ms(100);
                system_reset();
            } else {
                // Any other key: boot immediately
                break;
            }
        }
    }

    // No update requested, boot application
    uart_puts("Booting application...\r\n\r\n");
    jump_to_application(APP_START_ADDR);
}

bool receive_and_program_firmware(void) {
    firmware_image_t header;

    // 1. Receive header
    if (!uart_receive_bytes((uint8_t*)&header, sizeof(header), 5000)) {
        uart_puts("ERROR: Header timeout\r\n");
        return false;
    }

    // 2. Verify magic
    if (header.magic != BOOT_MAGIC) {
        uart_puts("ERROR: Invalid magic\r\n");
        return false;
    }

    uart_printf("Receiving %u bytes...\r\n", header.size);

    // 3. Erase application flash area
    uart_puts("Erasing flash...\r\n");
    flash_erase(APP_START_ADDR, header.size);

    // 4. Receive and program data in chunks
    uint32_t addr = APP_START_ADDR;
    uint32_t remaining = header.size;
    uint8_t buffer[256];
    uint32_t crc = 0xFFFFFFFF;

    while (remaining > 0) {
        uint32_t chunk = (remaining > sizeof(buffer)) ? sizeof(buffer) : remaining;

        if (!uart_receive_bytes(buffer, chunk, 1000)) {
            uart_puts("ERROR: Data timeout\r\n");
            return false;
        }

        // Program to flash
        flash_write(addr, buffer, chunk);

        // Update CRC
        crc = crc32_update(crc, buffer, chunk);

        addr += chunk;
        remaining -= chunk;

        // Progress indicator
        uart_putc('.');
    }

    crc = ~crc;  // Finalize CRC
    uart_puts("\r\n");

    // 5. Verify CRC
    if (crc != header.crc32) {
        uart_printf("ERROR: CRC mismatch (got 0x%08X, expected 0x%08X)\r\n",
                   crc, header.crc32);
        return false;
    }

    uart_puts("CRC OK\r\n");
    return true;
}

void jump_to_application(uint32_t addr) {
    // Disable interrupts
    __asm__ volatile("csrci mstatus, 0x8");

    // Reset stack pointer
    __asm__ volatile("la sp, _stack_top");

    // Jump to application
    void (*app)(void) = (void (*)(void))addr;
    app();

    // Should never return
    while (1);
}
```

**Use case:** Field-deployable, update via UART/USB converter.

### Type 3: Multi-Image Bootloader

**Supports A/B partitions for safe updates.**

```c
// multi_image_boot.c - Dual-bank bootloader

#define APP_A_ADDR  0x00004000  // Partition A
#define APP_B_ADDR  0x00010000  // Partition B
#define CONFIG_ADDR 0x0001F000  // Last flash sector

typedef struct {
    uint32_t magic;           // 0xA5A5A5A5 if valid
    uint32_t version;         // Firmware version number
    uint32_t size;            // Firmware size in bytes
    uint32_t crc32;           // CRC32 checksum
    uint32_t boot_count;      // Number of boots attempted
    uint32_t flags;           // Status flags
} partition_info_t;

typedef struct {
    partition_info_t partition_a;
    partition_info_t partition_b;
    uint32_t active_partition;  // 0=A, 1=B
    uint32_t update_pending;    // 1 if new image needs testing
} boot_config_t;

#define FLAG_VALID      (1 << 0)  // Image is valid
#define FLAG_TESTED     (1 << 1)  // Image has been tested successfully
#define FLAG_CORRUPTED  (1 << 2)  // Image failed verification

void bootloader_main(void) {
    boot_config_t *config = (boot_config_t*)CONFIG_ADDR;

    uart_init(115200);
    uart_puts("Multi-image bootloader v1.0\r\n");

    // Check for update request
    if (button_pressed() || uart_check_update_command()) {
        enter_update_mode(config);
        system_reset();
    }

    // Select partition to boot
    uint32_t boot_addr;
    partition_info_t *boot_partition;

    if (config->active_partition == 0) {
        boot_addr = APP_A_ADDR;
        boot_partition = &config->partition_a;
        uart_puts("Booting partition A\r\n");
    } else {
        boot_addr = APP_B_ADDR;
        boot_partition = &config->partition_b;
        uart_puts("Booting partition B\r\n");
    }

    // Verify partition before booting
    if (!verify_partition(boot_addr, boot_partition)) {
        uart_puts("ERROR: Partition corrupted, trying fallback...\r\n");

        // Mark as corrupted
        boot_partition->flags |= FLAG_CORRUPTED;
        flash_write_config(config);

        // Try other partition
        if (config->active_partition == 0) {
            boot_addr = APP_B_ADDR;
            boot_partition = &config->partition_b;
        } else {
            boot_addr = APP_A_ADDR;
            boot_partition = &config->partition_a;
        }

        if (!verify_partition(boot_addr, boot_partition)) {
            uart_puts("FATAL: Both partitions corrupted!\r\n");
            enter_recovery_mode();
        }
    }

    // Increment boot count (for rollback protection)
    boot_partition->boot_count++;
    if (boot_partition->boot_count > 3 && !(boot_partition->flags & FLAG_TESTED)) {
        // Failed to boot 3 times, rollback to previous version
        uart_puts("ERROR: Boot failed 3 times, rolling back...\r\n");
        config->active_partition = (config->active_partition == 0) ? 1 : 0;
        boot_partition->flags |= FLAG_CORRUPTED;
        flash_write_config(config);
        system_reset();
    }

    flash_write_config(config);

    // Jump to application
    uart_printf("Starting app v%u.%u.%u\r\n",
               boot_partition->version >> 16,
               (boot_partition->version >> 8) & 0xFF,
               boot_partition->version & 0xFF);

    jump_to_application(boot_addr);
}

bool verify_partition(uint32_t addr, partition_info_t *info) {
    // Check magic
    if (info->magic != 0xA5A5A5A5) {
        uart_puts("Invalid magic\r\n");
        return false;
    }

    // Calculate CRC32 over entire image
    uint32_t crc = crc32_calculate((uint8_t*)addr, info->size);

    if (crc != info->crc32) {
        uart_printf("CRC mismatch (got 0x%08X, expected 0x%08X)\r\n",
                   crc, info->crc32);
        return false;
    }

    return true;
}
```

**Use case:** Production systems requiring high reliability and safe updates.

---

## RISC-V Specific Considerations

### 1. Reset Vector

**RISC-V specification:** PC = Implementation-defined reset address on reset.

**Common implementations:**
- **SiFive cores:** 0x0000_1000 (allows room for debug ROM at 0x0)
- **Most embedded:** 0x0000_0000 (simplest)
- **Your choice:** Depends on your core design

**Solution:** Make sure first instruction of bootloader is at reset vector address.

```assembly
# boot_start.S - RISC-V bootloader entry point

.section .text.start, "ax"
.global _start

_start:
    # This MUST be at reset vector address!

    # 1. Set stack pointer (FIRST thing to do!)
    la sp, _stack_top

    # 2. Set global pointer (for relaxation optimization)
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # 3. Clear all registers (paranoid but safe)
    li x1,  0
    li x2,  0
    li x3,  0
    # ... up to x31

    # 4. Disable interrupts
    csrci mstatus, 0x8  # Clear MIE bit

    # 5. Jump to C code
    j bootloader_main

    # Should never return, but just in case:
.L_hang:
    wfi  # Wait for interrupt (low power)
    j .L_hang
```

### 2. Privilege Modes

**RISC-V has 3 privilege levels:**
- **M-mode** (Machine): Full control, all CSRs accessible
- **S-mode** (Supervisor): For OS kernel (optional)
- **U-mode** (User): For applications (optional)

**Embedded systems:** Usually M-mode only (simplest).

**Bootloader considerations:**
- Bootloader runs in **M-mode**
- Application also runs in **M-mode** (for embedded)
- No privilege level change needed (unlike ARM)

### 3. CSR Initialization

**Critical CSRs to initialize in bootloader:**

```c
void init_csrs(void) {
    // Disable all interrupts
    csr_write(CSR_MIE, 0x0);

    // Clear pending interrupts
    csr_write(CSR_MIP, 0x0);

    // Set trap vector (if bootloader handles traps)
    csr_write(CSR_MTVEC, (uint32_t)&_trap_handler);

    // Ensure machine mode
    uint32_t mstatus = csr_read(CSR_MSTATUS);
    mstatus &= ~MSTATUS_MIE;  // Disable interrupts
    mstatus |= MSTATUS_MPP_M; // Previous privilege = M-mode
    csr_write(CSR_MSTATUS, mstatus);
}
```

### 4. Cache Management (if applicable)

**If your RISC-V has caches:**

```c
void invalidate_icache(void) {
    // RISC-V privileged spec: fence.i instruction
    __asm__ volatile("fence.i" ::: "memory");
}

void flush_dcache(void) {
    // Implementation-specific
    // Some cores provide custom CSRs for cache control
    // Example for SiFive cores:
    // csr_write(0x7C1, 0x1);  // Custom CSR to flush D-cache

    // Or use fence instruction (ensures memory ordering)
    __asm__ volatile("fence" ::: "memory");
}
```

**Important:** After programming new firmware, flush caches before jumping!

### 5. PMP (Physical Memory Protection)

**Advanced: Lock bootloader region to prevent corruption.**

```c
void setup_pmp(void) {
    // Protect bootloader region (0x0000_0000 to 0x0000_4000)
    // Make it read-execute only, cannot be modified by application

    // PMP entry 0: Bootloader region
    uint32_t pmpaddr0 = 0x00004000 >> 2;  // Address in 4-byte units
    csr_write(CSR_PMPADDR0, pmpaddr0);

    // PMP config: Top-Of-Range, Read-eXecute only, Locked
    uint32_t pmpcfg0 = (PMP_TOR << 3) | PMP_R | PMP_X | PMP_L;
    csr_write(CSR_PMPCFG0, pmpcfg0);

    // Once locked, even M-mode cannot modify this region!
}
```

---

## Implementation: UART Bootloader

### Complete Working Example

**Directory structure:**
```
bootloader/
├── boot_start.S        # Assembly entry point
├── bootloader.c        # Main logic
├── uart.c              # UART driver
├── flash.c             # Flash programming
├── crc32.c             # CRC calculation
├── bootloader.ld       # Linker script
└── Makefile
```

**boot_start.S:**
```assembly
# boot_start.S

.section .text.start, "ax"
.global _start

_start:
    # Set stack
    la sp, _stack_top

    # Set global pointer
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # Initialize .data section
    la a0, _data_load     # Source (in flash)
    la a1, _data_start    # Destination (in RAM)
    la a2, _data_end

.L_copy_data:
    beq a1, a2, .L_copy_done
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j .L_copy_data

.L_copy_done:
    # Zero .bss section
    la a0, _bss_start
    la a1, _bss_end

.L_zero_bss:
    beq a0, a1, .L_bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j .L_zero_bss

.L_bss_done:
    # Jump to C main
    j bootloader_main
```

**bootloader.c:**
```c
// bootloader.c

#include <stdint.h>
#include <stdbool.h>
#include "uart.h"
#include "flash.h"
#include "crc32.h"

#define APP_START_ADDR  0x00004000
#define BOOT_MAGIC      0xB007ABCD
#define TIMEOUT_MS      3000

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t version;
    uint32_t size;
    uint32_t crc32;
    uint32_t reserved[4];
} firmware_header_t;

// Forward declarations
static bool check_for_update_request(void);
static bool receive_firmware(void);
static bool verify_application(uint32_t addr);
static void jump_to_application(uint32_t addr);

void bootloader_main(void) {
    // Initialize peripherals
    uart_init(115200);
    timer_init();

    // Print banner
    uart_puts("\r\n");
    uart_puts("================================\r\n");
    uart_puts("  RISC-V Bootloader v1.0\r\n");
    uart_puts("  5-Level Inverter Controller\r\n");
    uart_puts("================================\r\n");

    // Check for update request
    if (check_for_update_request()) {
        uart_puts("\r\n>>> Update mode <<<\r\n");
        uart_puts("Waiting for firmware image...\r\n");

        if (receive_firmware()) {
            uart_puts("Update successful!\r\n");
            uart_puts("Rebooting in 2 seconds...\r\n");
            delay_ms(2000);
            system_reset();
        } else {
            uart_puts("Update failed!\r\n");
            uart_puts("Attempting to boot existing app...\r\n");
        }
    }

    // Verify application
    uart_puts("Verifying application...\r\n");
    if (!verify_application(APP_START_ADDR)) {
        uart_puts("ERROR: Application verification failed!\r\n");
        uart_puts("Entering recovery mode...\r\n");

        // Recovery mode: wait for firmware upload
        while (1) {
            if (receive_firmware()) {
                system_reset();
            }
            delay_ms(100);
        }
    }

    uart_puts("Application verified OK\r\n");
    uart_puts("Jumping to application...\r\n\r\n");
    delay_ms(100);  // Let UART finish transmitting

    jump_to_application(APP_START_ADDR);

    // Should never reach here
    while (1) {
        __asm__ volatile("wfi");
    }
}

static bool check_for_update_request(void) {
    uart_puts("\r\nPress 'U' for update mode (3s timeout)...\r\n");

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
        if ((get_time_ms() - start) % 1000 == 0) {
            uart_putc('.');
        }
    }

    uart_puts("\r\n");
    return false;
}

static bool receive_firmware(void) {
    firmware_header_t header;

    uart_puts("Waiting for header (30s timeout)...\r\n");

    // Receive header
    if (!uart_receive_bytes((uint8_t*)&header, sizeof(header), 30000)) {
        uart_puts("ERROR: Header receive timeout\r\n");
        return false;
    }

    // Verify magic
    if (header.magic != BOOT_MAGIC) {
        uart_printf("ERROR: Invalid magic (got 0x%08X, expected 0x%08X)\r\n",
                   header.magic, BOOT_MAGIC);
        return false;
    }

    uart_printf("Firmware version: %u.%u.%u\r\n",
               (header.version >> 16) & 0xFF,
               (header.version >> 8) & 0xFF,
               header.version & 0xFF);
    uart_printf("Size: %u bytes\r\n", header.size);

    // Sanity check size
    if (header.size > (48 * 1024)) {  // Max 48KB
        uart_puts("ERROR: Firmware too large\r\n");
        return false;
    }

    // Erase application area
    uart_puts("Erasing flash...\r\n");
    flash_erase(APP_START_ADDR, header.size);

    // Receive and program firmware
    uart_puts("Programming");
    uint32_t addr = APP_START_ADDR;
    uint32_t remaining = header.size;
    uint8_t buffer[128];
    uint32_t crc = 0xFFFFFFFF;

    while (remaining > 0) {
        uint32_t chunk = (remaining > sizeof(buffer)) ? sizeof(buffer) : remaining;

        if (!uart_receive_bytes(buffer, chunk, 5000)) {
            uart_puts("\r\nERROR: Data receive timeout\r\n");
            return false;
        }

        // Program to flash
        if (!flash_write(addr, buffer, chunk)) {
            uart_puts("\r\nERROR: Flash write failed\r\n");
            return false;
        }

        // Update CRC
        crc = crc32_update(crc, buffer, chunk);

        addr += chunk;
        remaining -= chunk;

        // Progress indicator
        uart_putc('.');
    }

    crc = ~crc;
    uart_puts(" done\r\n");

    // Verify CRC
    uart_printf("Verifying CRC (calculated: 0x%08X, expected: 0x%08X)...\r\n",
               crc, header.crc32);

    if (crc != header.crc32) {
        uart_puts("ERROR: CRC mismatch!\r\n");
        return false;
    }

    // Write header
    flash_write(APP_START_ADDR, (uint8_t*)&header, sizeof(header));

    uart_puts("CRC verified OK\r\n");
    return true;
}

static bool verify_application(uint32_t addr) {
    firmware_header_t *header = (firmware_header_t*)addr;

    // Check magic
    if (header->magic != BOOT_MAGIC) {
        uart_puts("No valid application found\r\n");
        return false;
    }

    // Calculate CRC
    uint8_t *data = (uint8_t*)(addr + sizeof(firmware_header_t));
    uint32_t crc = crc32_calculate(data, header->size - sizeof(firmware_header_t));

    if (crc != header->crc32) {
        uart_printf("CRC check failed (0x%08X != 0x%08X)\r\n", crc, header->crc32);
        return false;
    }

    return true;
}

static void jump_to_application(uint32_t addr) {
    // Disable interrupts
    __asm__ volatile("csrci mstatus, 0x8");

    // Invalidate instruction cache (if present)
    __asm__ volatile("fence.i");

    // Jump to application entry point
    // Application starts at addr + sizeof(header)
    uint32_t app_entry = addr + sizeof(firmware_header_t);
    void (*app)(void) = (void (*)(void))app_entry;

    app();

    // Should never return
    while (1);
}
```

**Usage:**

1. **Build bootloader:**
   ```bash
   make bootloader
   # Produces bootloader.bin
   ```

2. **Flash bootloader via JTAG:**
   ```bash
   openocd -f interface/jlink.cfg -f target/riscv.cfg \
           -c "program bootloader.bin 0x00000000 verify reset exit"
   ```

3. **Build application:**
   ```bash
   make application
   # Produces application.bin with header
   ```

4. **Update via UART:**
   ```bash
   # Connect USB-UART adapter
   # Press reset button
   # Press 'U' key within 3 seconds
   python3 upload_tool.py /dev/ttyUSB0 application.bin
   ```

---

## Implementation: Flash Programmer

### UART Upload Tool (Python)

```python
#!/usr/bin/env python3
# upload_tool.py - Firmware upload tool for RISC-V bootloader

import serial
import struct
import time
import sys
from pathlib import Path

BOOT_MAGIC = 0xB007ABCD
BAUDRATE = 115200

def crc32(data):
    """Calculate CRC32 (same algorithm as bootloader)"""
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return (~crc) & 0xFFFFFFFF

def upload_firmware(port, filename, version=(1, 0, 0)):
    """Upload firmware to device via UART"""

    # Read firmware file
    print(f"Reading {filename}...")
    with open(filename, 'rb') as f:
        firmware_data = f.read()

    print(f"Firmware size: {len(firmware_data)} bytes")

    # Calculate CRC
    crc = crc32(firmware_data)
    print(f"CRC32: 0x{crc:08X}")

    # Build header
    version_u32 = (version[0] << 16) | (version[1] << 8) | version[2]
    header = struct.pack('<IIII', BOOT_MAGIC, version_u32, len(firmware_data), crc)
    header += b'\x00' * 16  # Reserved bytes

    # Open serial port
    print(f"Opening {port} @ {BAUDRATE} baud...")
    ser = serial.Serial(port, BAUDRATE, timeout=1)
    time.sleep(0.1)

    # Wait for bootloader prompt
    print("Waiting for bootloader...")
    ser.write(b'U')  # Trigger update mode
    time.sleep(0.5)

    # Read bootloader messages
    while ser.in_waiting > 0:
        line = ser.readline().decode('utf-8', errors='ignore')
        print(f"  {line.strip()}")

    # Send header
    print("Sending header...")
    ser.write(header)
    time.sleep(0.1)

    # Send firmware data
    print("Sending firmware data...")
    chunk_size = 128
    sent = 0

    while sent < len(firmware_data):
        chunk = firmware_data[sent:sent + chunk_size]
        ser.write(chunk)
        sent += len(chunk)

        # Progress
        percent = (sent * 100) // len(firmware_data)
        print(f"\r  Progress: {percent}% ({sent}/{len(firmware_data)} bytes)", end='')

        time.sleep(0.01)  # Small delay between chunks

    print("\n")

    # Wait for verification messages
    print("Waiting for verification...")
    time.sleep(1)

    while ser.in_waiting > 0:
        line = ser.readline().decode('utf-8', errors='ignore')
        print(f"  {line.strip()}")

    ser.close()
    print("Upload complete!")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: upload_tool.py <port> <firmware.bin> [version]")
        print("Example: upload_tool.py /dev/ttyUSB0 app.bin 1.2.3")
        sys.exit(1)

    port = sys.argv[1]
    filename = sys.argv[2]

    version = (1, 0, 0)
    if len(sys.argv) > 3:
        version = tuple(map(int, sys.argv[3].split('.')))

    upload_firmware(port, filename, version)
```

**Usage:**
```bash
python3 upload_tool.py /dev/ttyUSB0 application.bin 1.2.3
```

---

## Security Considerations

### 1. Firmware Signature Verification

**Problem:** Anyone with UART access can upload malicious firmware.

**Solution:** Use cryptographic signatures (e.g., Ed25519).

```c
// Secure bootloader with signature verification

#include "ed25519.h"  // Use TweetNaCl or similar

// Public key embedded in bootloader (flash, read-only)
const uint8_t PUBLIC_KEY[32] = {
    0x12, 0x34, 0x56, 0x78, /* ... */
};

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t size;
    uint32_t crc32;
    uint8_t signature[64];  // Ed25519 signature
} secure_header_t;

bool verify_firmware_signature(secure_header_t *header, uint8_t *firmware) {
    // Verify Ed25519 signature
    return ed25519_verify(header->signature,
                         firmware,
                         header->size,
                         PUBLIC_KEY);
}

bool receive_secure_firmware(void) {
    secure_header_t header;

    // Receive header
    uart_receive_bytes((uint8_t*)&header, sizeof(header), 30000);

    // Verify magic and CRC as before
    // ...

    // Verify signature
    uart_puts("Verifying signature...\r\n");
    if (!verify_firmware_signature(&header, firmware_buffer)) {
        uart_puts("ERROR: Invalid signature! Rejecting firmware.\r\n");
        return false;
    }

    uart_puts("Signature valid, programming...\r\n");
    // Program firmware
    // ...
}
```

### 2. Rollback Protection

**Problem:** Attacker can downgrade to old version with known vulnerabilities.

**Solution:** Store version number in flash, reject older versions.

```c
#define MIN_VERSION_ALLOWED  0x00010200  // 1.2.0

bool check_version(uint32_t new_version) {
    uint32_t current_version = read_current_version();

    if (new_version < MIN_VERSION_ALLOWED) {
        uart_puts("ERROR: Version too old, rejecting\r\n");
        return false;
    }

    if (new_version < current_version) {
        uart_puts("WARNING: Downgrade detected\r\n");
        // Could reject, or ask for confirmation
    }

    return true;
}
```

### 3. Secure Boot Chain

**Full secure boot:**
1. **Boot ROM** (mask ROM, immutable) → verifies bootloader signature
2. **Bootloader** (signed) → verifies application signature
3. **Application** (signed) → runs

**Each stage verifies the next before transferring control.**

---

## Troubleshooting

### Problem: Bootloader doesn't run

**Symptoms:** No UART output, device appears dead

**Checks:**
1. Verify bootloader at correct address (reset vector)
2. Check clock initialization
3. Verify stack pointer set correctly
4. Check UART pins and baud rate

**Debug:**
```c
// Add LED blink at very start
void _start(void) {
    // Blink LED to confirm entry
    GPIO->OUTPUT = 0x1;
    for (volatile int i = 0; i < 1000000; i++);
    GPIO->OUTPUT = 0x0;

    // Continue with boot...
}
```

### Problem: Application doesn't start

**Symptoms:** Bootloader runs, but application doesn't

**Checks:**
1. Verify application address correct
2. Check jump address calculation
3. Ensure caches flushed (fence.i)
4. Verify application has valid entry point

**Debug:**
```c
void jump_to_application(uint32_t addr) {
    uart_printf("Jumping to 0x%08X\r\n", addr);

    // Read first instruction for debug
    uint32_t *entry = (uint32_t*)addr;
    uart_printf("First instruction: 0x%08X\r\n", *entry);

    delay_ms(100);

    // Jump
    void (*app)(void) = (void (*)(void))addr;
    app();
}
```

### Problem: Firmware upload fails

**Symptoms:** CRC mismatch, timeout, corruption

**Checks:**
1. UART baud rate matches on both sides
2. Flow control disabled
3. Sufficient timeout for flash erase
4. Buffer overrun in receive

**Debug:**
```python
# In upload_tool.py, add verification read-back
def verify_upload(ser, addr, expected_data):
    # Send read command to bootloader
    ser.write(b'R')  # Read command
    ser.write(struct.pack('<II', addr, len(expected_data)))

    # Read back
    readback = ser.read(len(expected_data))

    if readback == expected_data:
        print("Verification: OK")
    else:
        print("Verification: FAILED")
        # Print mismatches
        for i, (a, b) in enumerate(zip(expected_data, readback)):
            if a != b:
                print(f"  Addr 0x{addr+i:08X}: wrote 0x{a:02X}, read 0x{b:02X}")
```

---

## Summary

### Bootloader Checklist

**Essential features:**
- [x] Hardware initialization
- [x] UART communication
- [x] Firmware update capability
- [x] CRC verification
- [x] Timeout handling
- [x] Jump to application

**Recommended features:**
- [x] Multi-image support (A/B partitions)
- [x] Rollback protection
- [x] Version tracking
- [x] Recovery mode

**Advanced features:**
- [ ] Cryptographic signatures
- [ ] Secure boot
- [ ] Encrypted firmware
- [ ] Over-the-air (OTA) updates

### Key Takeaways

1. **Bootloader is essential** for field-deployable products
2. **Start simple** - basic UART bootloader is sufficient for most projects
3. **RISC-V specifics** - Mind the reset vector, CSRs, and privilege modes
4. **Security matters** - Add signature verification for production
5. **Test thoroughly** - Especially error cases (timeout, corruption, power loss)

---

**Document Version:** 1.0
**Last Updated:** 2025-12-09
**Target:** RISC-V RV32IM Embedded Systems
**For:** 5-Level Inverter Controller Project
