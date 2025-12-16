#include <stdint.h>
#include "../../memory_map.h"

// PR Controller Constants
#define KP 1.0f
#define KI 0.1f

// ZPEC instruction macros
#define zpec_sincos(sin_out, cos_out, angle) \
    __asm__ volatile ( \
        ".insn r 0x5b, 0, 4, %0, %1, %2" \
        : "=r"(sin_out), "=r"(cos_out) \
        : "r"(angle) \
    )

void init_pwm() {
    // Configure PWM accelerator for CPU-provided reference mode
    // Bit 0: enable, Bit 1: mode (0=auto, 1=cpu)
    PWM->CTRL = (1 << 1) | (1 << 0);
}

void pr_controller_run() {
    // 1. Read ADC value (AC Current)
    int32_t current_meas = ADC->DATA_CH3;

    // 2. Generate reference sine wave (example)
    int32_t angle = 16384; // pi/2 in Q15 format
    int32_t sin_ref;
    int32_t cos_ref; // Not used yet
    zpec_sincos(sin_ref, cos_ref, angle);

    // 3. Calculate error
    int32_t error = sin_ref - current_meas;

    // 4. TODO: Implement full PR controller using ZPEC.MAC
    
    // 5. For now, just write the error to the PWM cpu_reference for testing
    // This assumes the pwm_accelerator is in CPU-provided reference mode
    PWM->CPU_REFERENCE = error;
}

int main() {
    init_pwm();
    // TODO: Initialize other peripherals (ADC, Timer for interrupt)
    
    while (1) {
        // Run the control loop continuously
        pr_controller_run();
        // In a real system, this would be triggered by a timer interrupt
    }

    return 0;
}
