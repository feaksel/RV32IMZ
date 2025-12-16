/**
 * @file chb_test_simple.c  
 * @brief Simple test application for bootloader verification
 * 
 * This is a minimal CHB application to test bootloader functionality:
 * - Initialize hardware
 * - Blink LED via GPIO
 * - Simple PWM output
 * - UART status messages
 */

#include <stdint.h>
#include "memory_map.h"

//=============================================================================
// Simple Hardware Control Functions  
//=============================================================================

static void delay(uint32_t cycles) {
    for (volatile uint32_t i = 0; i < cycles; i++) {
        __asm__ volatile("nop");
    }
}

static void uart_putc(char c) {
    while (!(*(volatile uint32_t*)(UART_BASE + 4) & 0x02));  // Wait for TX empty
    *(volatile uint32_t*)(UART_BASE + 0) = c;
}

static void uart_puts(const char* str) {
    while (*str) {
        uart_putc(*str++);
    }
}

static void gpio_set_led(uint8_t led_mask) {
    *(volatile uint32_t*)(GPIO_BASE + 0x04) = led_mask;  // GPIO OUTPUT register
}

//=============================================================================
// Main Application
//=============================================================================

int main(void) {
    // System banner
    uart_puts("\r\n");
    uart_puts("===========================================\r\n"); 
    uart_puts("  CHB Test Application v1.0.0\r\n");
    uart_puts("  Loaded via RV32IMZ Bootloader\r\n");
    uart_puts("===========================================\r\n");
    uart_puts("Hardware: RV32IMZ SoC @ 50MHz\r\n");
    uart_puts("Application: 5-Level CHB Inverter Test\r\n");
    uart_puts("\r\n");
    
    // Initialize GPIO for LED control
    *(volatile uint32_t*)(GPIO_BASE + 0x00) = 0x0F;  // GPIO DIRECTION - First 4 bits as outputs
    
    // Initialize PWM (simple setup)  
    PWM->CTRL = PWM_CTRL_ENABLE;    // Enable PWM
    PWM->FREQ_DIV = 10000;          // Frequency divider for 5kHz
    PWM->DEADTIME = 100;            // 100 cycle dead time
    
    uart_puts("Initialization complete!\r\n");
    uart_puts("Starting test sequence...\r\n\r\n");
    
    // Main test loop
    uint32_t loop_count = 0;
    uint8_t led_pattern = 1;
    
    while (1) {
        // Update LED pattern (walking LED)
        gpio_set_led(led_pattern);
        led_pattern = (led_pattern << 1) | (led_pattern >> 3);
        led_pattern &= 0x0F;
        
        // Update PWM modulation (simple sine approximation)
        uint16_t pwm_value = (loop_count % 100) * 655;  // Simple ramp 0-65535
        PWM->MOD_INDEX = pwm_value;
        
        // Status message every ~1000 loops
        if ((loop_count % 1000) == 0) {
            uart_puts("Loop: ");
            // Simple hex output
            for (int i = 28; i >= 0; i -= 4) {
                uint8_t nibble = (loop_count >> i) & 0xF;
                uart_putc((nibble < 10) ? ('0' + nibble) : ('A' + nibble - 10));
            }
            uart_puts(" PWM: ");
            for (int i = 12; i >= 0; i -= 4) {
                uint8_t nibble = (pwm_value >> i) & 0xF;
                uart_putc((nibble < 10) ? ('0' + nibble) : ('A' + nibble - 10));
            }
            uart_puts(" LED: ");
            uart_putc('0' + (led_pattern & 0xF));
            uart_puts("\r\n");
        }
        
        // Delay for visible LED changes
        delay(50000);  // ~1ms at 50MHz
        loop_count++;
        
        // Test protection system every 10000 loops
        if ((loop_count % 10000) == 0) {
            uart_puts("Protection check: ");
            uint32_t prot_status = *(volatile uint32_t*)(PROT_BASE + 0x00);
            if (prot_status == 0) {
                uart_puts("OK\r\n");
            } else {
                uart_puts("FAULT: ");
                for (int i = 28; i >= 0; i -= 4) {
                    uint8_t nibble = (prot_status >> i) & 0xF;
                    uart_putc((nibble < 10) ? ('0' + nibble) : ('A' + nibble - 10));
                }
                uart_puts("\r\n");
            }
        }
    }
    
    return 0;  // Should never reach here
}