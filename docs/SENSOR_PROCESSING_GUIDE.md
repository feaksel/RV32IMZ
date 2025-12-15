# RISC-V Sensor Processing Guide

**Complete guide to sensor interfacing, signal processing, and control decisions for RISC-V inverter systems**

---

## Table of Contents

1. [Overview](#overview)
2. [Physical Sensors](#physical-sensors)
3. [Signal Conditioning](#signal-conditioning)
4. [ADC Interface Hardware](#adc-interface-hardware)
5. [Raw Data Conversion](#raw-data-conversion)
6. [Sensor Calibration](#sensor-calibration)
7. [Digital Filtering](#digital-filtering)
8. [Control Decisions](#control-decisions)
9. [Complete ISR Example](#complete-isr-example)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### Complete Sensor-to-Control Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│                     PHYSICAL WORLD                            │
│  • Current: ±20A (AC waveform)                               │
│  • Voltage: ±150V peak (AC output)                           │
│  • DC Bus: 0-60V (two isolated sources)                      │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│               ANALOG SIGNAL CHAIN                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                │
│  │  Sensor  │──►│  Filter  │──►│ Level    │                │
│  │ (±20A)   │   │ (RC)     │   │ Shift    │                │
│  │ Output:  │   │ Cutoff:  │   │ (0-3.3V) │                │
│  │ 0.5-4.5V │   │ 1.6 kHz  │   │          │                │
│  └──────────┘   └──────────┘   └──────────┘                │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│                    ADC CONVERSION                             │
│  • 12-bit ADC (0-4095 counts)                                │
│  • 4 channels simultaneous                                    │
│  • Sample rate: 10 kHz (synchronized with PWM)               │
│  • Conversion time: ~10 µs                                    │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│              RISC-V PROCESSING (ISR)                          │
│  Step 1: Read ADC registers                                  │
│          → raw[0] = 2456 counts (current)                    │
│                                                               │
│  Step 2: Convert to engineering units                        │
│          → (2456 - 2048) × 0.0098 = 4.0 A                    │
│                                                               │
│  Step 3: Digital filtering                                   │
│          → LPF: 4.0A → 3.95A (remove noise)                  │
│                                                               │
│  Step 4: Safety checks                                       │
│          → 3.95A < 15A ? ✓ OK                                │
│          → 48V < 55V ? ✓ OK                                  │
│                                                               │
│  Step 5: Calculate error                                     │
│          → error = 5.0A (ref) - 3.95A (meas) = 1.05A         │
│                                                               │
│  Step 6: Control algorithm (PR controller)                   │
│          → output = Kp×error + Kr×integral                   │
│          → MI = 0.85 (modulation index)                      │
│                                                               │
│  Step 7: Modulation (5-level)                                │
│          → Compare MI×sin(θ) with level-shifted carriers     │
│          → Generate duty cycles for 8 switches               │
│                                                               │
│  Step 8: Update PWM                                          │
│          → PWM->DUTY[0] = 3600 (50% of 7200)                 │
│          → PWM->DUTY[1] = 0                                  │
│          → ... (all 8 channels)                              │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│                  HARDWARE ACTUATION                           │
│  • PWM signals → Gate drivers → MOSFETs                      │
│  • H-bridges generate AC voltage                             │
│  • Current increases toward 5.0A setpoint                    │
│                                                               │
│  [Loop repeats at 10 kHz = every 100 µs]                    │
└──────────────────────────────────────────────────────────────┘
```

### Key Concepts

- **Sensor:** Converts physical quantity to electrical signal
- **Signal Conditioning:** Scales signal to ADC input range (0-3.3V)
- **ADC:** Converts analog voltage to digital number (12-bit = 0-4095)
- **Conversion:** Maps digital counts to engineering units (Amps, Volts)
- **Filtering:** Removes noise and switching artifacts
- **Control:** Makes decisions based on processed sensor data

---

## Physical Sensors

### Current Sensor: Hall-Effect Type

**Example: ACS712-20A**

```
┌────────────────────────────────────────────┐
│          ACS712-20A Current Sensor          │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │                                     │   │
│  │   Hall Effect IC                    │   │
│  │                                     │   │
│  │   ┌──────┐                          │   │
│  │   │ Hall │  Magnetic field from     │   │
│  │   │ Sens │  current through trace   │   │
│  │   └──┬───┘                          │   │
│  │      │                              │   │
│  │      ↓                              │   │
│  │   ┌──────┐                          │   │
│  │   │ Amp  │ → Vout = 2.5V + I×0.1V  │   │
│  │   └──────┘                          │   │
│  │                                     │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Input: ±20A (flows through internal path) │
│  Output: 0.5V to 4.5V analog voltage       │
│                                             │
│  Transfer Function:                         │
│    Vout = Vcc/2 + Sensitivity × Ip         │
│    Vout = 2.5V + 0.1V/A × Ip               │
│                                             │
│  Examples:                                  │
│    Ip =  0A   → Vout = 2.5V (zero current) │
│    Ip = +10A  → Vout = 3.5V                │
│    Ip = -10A  → Vout = 1.5V                │
│    Ip = +20A  → Vout = 4.5V (max)          │
│    Ip = -20A  → Vout = 0.5V (min)          │
└────────────────────────────────────────────┘

Specifications:
• Supply: 5V DC
• Isolation: 2.1 kV RMS
• Bandwidth: DC to 80 kHz
• Rise time: 5 µs
• Accuracy: ±1.5% @ 25°C
• Temperature drift: ±2% over -40°C to +85°C
```

**Pros:**
- ✅ Galvanic isolation (important for safety)
- ✅ Measures DC and AC current
- ✅ Low cost (~$2)
- ✅ Easy to use (single chip)
- ✅ Wide bandwidth (suitable for 10 kHz PWM)

**Cons:**
- ❌ Offset drift with temperature
- ❌ Limited accuracy (±1.5%)
- ❌ Needs 5V supply (not 3.3V)

**Alternatives:**
- **LEM HAL 50-S** (better accuracy, higher cost)
- **Shunt resistor + diff amp** (no isolation, but precise)
- **Current transformer** (AC only, no DC component)

### Voltage Sensor: Resistive Divider

**For measuring DC bus voltage (0-60V):**

```
           Input
         (0-60V DC)
              │
              │
             ┌┴┐
             │ │ R1 = 180kΩ (1/4W)
             │ │
             └┬┘
              ├──────────┬─────────► To ADC
              │          │          (0-3.3V)
             ┌┴┐        ═╪═
             │ │ R2 =    │ C1 = 100nF
             │ │ 10kΩ    │ (filter)
             └┬┘         │
              │          │
             GND        GND

Divider Ratio:
  R2 / (R1 + R2) = 10k / (180k + 10k) = 10/190 = 0.0526

Output Voltage:
  Vout = Vin × 0.0526

Examples:
  Vin = 10V  → Vout = 0.526V
  Vin = 50V  → Vout = 2.63V
  Vin = 60V  → Vout = 3.16V (within 3.3V max)

Cutoff Frequency:
  fc = 1 / (2π × Req × C)
  Req = R1 || R2 = (180k × 10k) / (180k + 10k) ≈ 9.5kΩ
  fc = 1 / (2π × 9.5kΩ × 100nF) ≈ 168 Hz
```

**Design notes:**
- Choose R1, R2 such that max input voltage → ~3.0V (leave margin)
- Use 1% tolerance resistors for accuracy
- Add capacitor for filtering (but not too large, or slow response)
- Consider using precision voltage reference for ADC (improves accuracy)

**Safety:**
- ⚠️ High-side measurement requires isolation (optocoupler or isolated ADC)
- ⚠️ Use adequate creepage/clearance on PCB
- ⚠️ Resistor power rating: P = V²/R → check max power

### Output Voltage Sensor

**For measuring AC output voltage (±150V peak):**

**Option 1: Voltage divider (same as DC bus)**
- Simple, low cost
- Need higher ratio (e.g., 50:1 for 150V → 3.0V)
- Isolation required for safety!

**Option 2: Voltage transformer**
- AC only (no DC component)
- Provides galvanic isolation
- More expensive
- Bandwidth limited

**Recommended:** Isolated voltage sensor IC (e.g., AMC1200)

### Sensor Summary Table

| Sensor | Input Range | Output Range | ADC Pin | Isolation | Accuracy |
|--------|-------------|--------------|---------|-----------|----------|
| Current (ACS712) | ±20A | 0.5-4.5V | ADC_CH0 | Yes (2.1kV) | ±1.5% |
| Output Voltage | ±150V | 0-3.3V | ADC_CH1 | Yes | ±2% |
| DC Bus 1 | 0-60V | 0-3.16V | ADC_CH2 | Optional | ±1% |
| DC Bus 2 | 0-60V | 0-3.16V | ADC_CH3 | Optional | ±1% |

---

## Signal Conditioning

### Why Signal Conditioning is Needed

**Problem 1: Voltage range mismatch**
- Sensor output: 0.5V to 4.5V (ACS712)
- ADC input: 0V to 3.3V
- **Solution:** Voltage divider or level shifter

**Problem 2: High-frequency noise**
- PWM switching at 10 kHz creates noise
- Switching edges have harmonics up to MHz
- **Solution:** Low-pass RC filter

**Problem 3: DC bias**
- Some sensors need bipolar supply but we only have 3.3V
- **Solution:** Op-amp level shifter (Vcc/2 reference)

### Current Sensor Conditioning

**Goal:** Scale 0.5-4.5V sensor output to 0-3.3V ADC input

```
ACS712 Output          Voltage Divider           RC Filter              ADC Input
(0.5V - 4.5V)         (Scale to 0-3.3V)       (Remove noise)          (0-3.3V)
      │                      │                      │                      │
      │                      │                      │                      │
      ├──────────────────────┤                      │                      │
      │       R1=10kΩ        │                      │                      │
      ├──────────┬───────────┤                      │                      │
      │          │           │      R2=1kΩ          │                      │
      │         R3=12kΩ      ├────/\/\/\────┬──────┴──────► To ADC_CH0
      │          │           │               │                (0-3.3V)
      │         GND          │              ═╪═
      │                      │               │ C=100nF
      │                      │              GND
      └──────────────────────┴───────────────┴──────────────────────────

Divider calculation:
  Vout = Vin × R3/(R1+R3)
  Vout = 4.5V × 12/(10+12) = 4.5V × 0.545 = 2.45V ✓ (within 3.3V)

Filter cutoff:
  fc = 1/(2π × 1kΩ × 100nF) = 1.6 kHz
  Attenuates 10 kHz PWM noise while passing 50-60 Hz fundamental
```

**Alternative: Op-amp level shifter**

If you need better precision:

```
       ACS712                     Op-Amp Buffer           ADC
      (0.5-4.5V)                  + Level Shift         (0-3.3V)
          │                             │                  │
          │         ┌────────────┐      │                  │
          └────────►│+           │      │                  │
                    │   Op-Amp   │──────┴──────────────────┤
         Vref ─────►│-  (TLV271) │                         │
         (0.5V)     └────────────┘                         │
                                                            │
Configuration:                                              │
  Gain = 0.733 (to scale 4.5V → 3.3V)                     │
  Offset = -0.5V (shift 0.5V → 0V)                        │
  Vout = (Vin - 0.5V) × 0.733                             │
```

### Voltage Divider Design Spreadsheet

**Use this to calculate your own dividers:**

```
Target:
  Input range:    Vin_min =  0V,    Vin_max = 60V
  Output range:   Vout_min = 0V,    Vout_max = 3.0V (leave 0.3V margin)

Calculation:
  Ratio = Vout_max / Vin_max = 3.0 / 60 = 0.05

Choose R2:
  R2 = 10kΩ (standard value)

Calculate R1:
  R1 = R2 × (1/Ratio - 1)
  R1 = 10k × (1/0.05 - 1) = 10k × 19 = 190kΩ

Nearest standard: 180kΩ or 200kΩ

Check max voltage:
  Vout = 60V × 10k/(180k+10k) = 3.16V ✓ (OK, within 3.3V)

Check power dissipation:
  P_R1 = Vin² / R1 = 60² / 180k = 0.02W ✓ (1/4W resistor OK)
  P_R2 = Vout² / R2 = 3.16² / 10k = 0.001W ✓
```

---

## ADC Interface Hardware

### ADC Peripheral Design for RISC-V

**Simplified sigma-delta ADC interface:**

```verilog
// adc_peripheral.v - ADC interface for RISC-V

module adc_peripheral #(
    parameter BASE_ADDR = 32'h40001000,
    parameter NUM_CHANNELS = 4
)(
    // Wishbone slave interface
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    input  wire        wb_cyc_i,
    output reg         wb_ack_o,

    // External ADC interface (SPI to external chip, e.g., MCP3204)
    output reg         spi_cs_n_o,
    output reg         spi_clk_o,
    output reg         spi_mosi_o,
    input  wire        spi_miso_i,

    // Interrupt (conversion complete)
    output wire        irq_o
);

    // Register map
    localparam ADDR_CONTROL  = 8'h00;  // [0]=start, [1]=continuous, [3:2]=channel
    localparam ADDR_STATUS   = 8'h04;  // [0]=busy, [1]=complete, [2]=error
    localparam ADDR_DATA0    = 8'h08;  // Channel 0 result (12-bit in [11:0])
    localparam ADDR_DATA1    = 8'h0C;
    localparam ADDR_DATA2    = 8'h10;
    localparam ADDR_DATA3    = 8'h14;
    localparam ADDR_PRESCALE = 8'h18;  // SPI clock prescaler
    localparam ADDR_IRQ_EN   = 8'h1C;  // Interrupt enable

    // Registers
    reg [31:0] control;
    reg [31:0] status;
    reg [11:0] data_regs [0:NUM_CHANNELS-1];
    reg [7:0]  prescaler;
    reg        irq_enable;
    reg        irq_pending;

    // ADC state machine
    localparam IDLE        = 3'd0;
    localparam SETUP       = 3'd1;
    localparam CONVERT     = 3'd2;
    localparam READ_DATA   = 3'd3;
    localparam STORE       = 3'd4;
    localparam NEXT_CH     = 3'd5;

    reg [2:0]  adc_state;
    reg [1:0]  channel;
    reg [4:0]  bit_counter;
    reg [15:0] shift_reg;
    reg [7:0]  clk_div;

    // Wishbone interface logic
    wire [7:0] reg_addr = wb_adr_i[7:0];

    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
            control <= 32'd0;
            prescaler <= 8'd4;  // Default: divide by 4
            irq_enable <= 1'b0;
        end else begin
            wb_ack_o <= 1'b0;

            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;

                if (wb_we_i) begin
                    // Write registers
                    case (reg_addr)
                        ADDR_CONTROL:  control <= wb_dat_i;
                        ADDR_PRESCALE: prescaler <= wb_dat_i[7:0];
                        ADDR_IRQ_EN:   irq_enable <= wb_dat_i[0];
                    endcase
                end else begin
                    // Read registers
                    case (reg_addr)
                        ADDR_CONTROL:  wb_dat_o <= control;
                        ADDR_STATUS: begin
                            wb_dat_o <= status;
                            irq_pending <= 1'b0;  // Clear on read
                        end
                        ADDR_DATA0:    wb_dat_o <= {20'd0, data_regs[0]};
                        ADDR_DATA1:    wb_dat_o <= {20'd0, data_regs[1]};
                        ADDR_DATA2:    wb_dat_o <= {20'd0, data_regs[2]};
                        ADDR_DATA3:    wb_dat_o <= {20'd0, data_regs[3]};
                        ADDR_PRESCALE: wb_dat_o <= {24'd0, prescaler};
                        ADDR_IRQ_EN:   wb_dat_o <= {31'd0, irq_enable};
                        default:       wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

    // SPI clock generation
    wire spi_clk_en = (clk_div == prescaler);

    always @(posedge wb_clk_i) begin
        if (adc_state == IDLE) begin
            clk_div <= 8'd0;
        end else begin
            if (clk_div >= prescaler) begin
                clk_div <= 8'd0;
            end else begin
                clk_div <= clk_div + 1;
            end
        end
    end

    // ADC control state machine
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            adc_state <= IDLE;
            spi_cs_n_o <= 1'b1;
            spi_clk_o <= 1'b0;
            spi_mosi_o <= 1'b0;
            channel <= 2'd0;
            status <= 32'd0;
            irq_pending <= 1'b0;
        end else begin
            case (adc_state)
                IDLE: begin
                    spi_cs_n_o <= 1'b1;
                    status[0] <= 1'b0;  // Not busy

                    if (control[0]) begin  // Start conversion
                        adc_state <= SETUP;
                        channel <= control[3:2];  // Channel selection
                        status[0] <= 1'b1;        // Busy
                        status[1] <= 1'b0;        // Not complete
                    end
                end

                SETUP: begin
                    if (spi_clk_en) begin
                        spi_cs_n_o <= 1'b0;       // Assert CS
                        bit_counter <= 5'd0;
                        shift_reg <= 16'h0600;    // Start bit + single-ended mode
                        shift_reg[10:9] <= channel;  // Channel select
                        adc_state <= CONVERT;
                    end
                end

                CONVERT: begin
                    if (spi_clk_en) begin
                        // Toggle SPI clock
                        spi_clk_o <= ~spi_clk_o;

                        if (spi_clk_o) begin  // Rising edge: shift out
                            spi_mosi_o <= shift_reg[15];
                            shift_reg <= {shift_reg[14:0], 1'b0};
                        end else begin  // Falling edge: shift in
                            shift_reg <= {shift_reg[14:0], spi_miso_i};
                            bit_counter <= bit_counter + 1;

                            if (bit_counter >= 5'd16) begin
                                adc_state <= STORE;
                            end
                        end
                    end
                end

                STORE: begin
                    // Store 12-bit result (bits [11:0] of shift_reg)
                    data_regs[channel] <= shift_reg[11:0];

                    if (control[1]) begin  // Continuous mode
                        adc_state <= NEXT_CH;
                    end else begin
                        adc_state <= IDLE;
                        status[1] <= 1'b1;         // Complete
                        irq_pending <= irq_enable;
                    end
                end

                NEXT_CH: begin
                    channel <= channel + 1;
                    if (channel == 2'd3) begin
                        // All channels done
                        channel <= 2'd0;
                        adc_state <= IDLE;
                        status[1] <= 1'b1;         // Complete
                        irq_pending <= irq_enable;
                    end else begin
                        adc_state <= SETUP;
                    end
                end

                default: adc_state <= IDLE;
            endcase
        end
    end

    assign irq_o = irq_pending;

endmodule
```

### Firmware ADC Driver

```c
// adc_driver.h

#ifndef ADC_DRIVER_H
#define ADC_DRIVER_H

#include <stdint.h>
#include <stdbool.h>

// ADC register base address
#define ADC_BASE  0x40001000

// ADC registers
typedef struct {
    volatile uint32_t CONTROL;   // 0x00
    volatile uint32_t STATUS;    // 0x04
    volatile uint32_t DATA[4];   // 0x08-0x14
    volatile uint32_t PRESCALE;  // 0x18
    volatile uint32_t IRQ_EN;    // 0x1C
} adc_regs_t;

#define ADC  ((adc_regs_t*)ADC_BASE)

// Control register bits
#define ADC_CTRL_START      (1 << 0)
#define ADC_CTRL_CONT       (1 << 1)
#define ADC_CTRL_CH_SHIFT   2
#define ADC_CTRL_CH_MASK    (0x3 << ADC_CTRL_CH_SHIFT)

// Status register bits
#define ADC_STATUS_BUSY     (1 << 0)
#define ADC_STATUS_DONE     (1 << 1)

// Functions
void adc_init(void);
void adc_start_single(uint8_t channel);
void adc_start_continuous(void);
bool adc_is_busy(void);
bool adc_is_done(void);
uint16_t adc_read_channel(uint8_t channel);

#endif
```

```c
// adc_driver.c

#include "adc_driver.h"

void adc_init(void) {
    // Set SPI clock prescaler (72 MHz / 4 = 18 MHz)
    ADC->PRESCALE = 4;

    // Disable interrupts initially
    ADC->IRQ_EN = 0;

    // Clear control
    ADC->CONTROL = 0;
}

void adc_start_single(uint8_t channel) {
    // Set channel and start
    ADC->CONTROL = ADC_CTRL_START | ((channel & 0x3) << ADC_CTRL_CH_SHIFT);
}

void adc_start_continuous(void) {
    // Start continuous mode (all 4 channels)
    ADC->CONTROL = ADC_CTRL_START | ADC_CTRL_CONT;
}

bool adc_is_busy(void) {
    return (ADC->STATUS & ADC_STATUS_BUSY) != 0;
}

bool adc_is_done(void) {
    return (ADC->STATUS & ADC_STATUS_DONE) != 0;
}

uint16_t adc_read_channel(uint8_t channel) {
    return ADC->DATA[channel] & 0xFFF;  // 12-bit mask
}
```

---

## Raw Data Conversion

### Understanding ADC Counts

**12-bit ADC:** Values from 0 to 4095

```
ADC Value    Voltage    Physical Quantity
---------    -------    ------------------
   0         0.000 V    Minimum
  512        0.413 V
 1024        0.827 V
 2048        1.650 V    Midpoint (bipolar signals)
 3072        2.477 V
 4095        3.300 V    Maximum (Vref)

Conversion formula:
  V_adc = (ADC_counts / 4095) × 3.3V
```

### Current Conversion (ACS712)

**Step-by-step conversion:**

```c
// Convert ADC counts to current (Amps)

#define ADC_RESOLUTION  4096.0f
#define ADC_VREF        3.3f
#define ACS712_ZERO_V   2.5f     // Output at 0A
#define ACS712_SENS     0.1f     // 100 mV/A
#define DIVIDER_RATIO   0.545f   // Voltage divider applied

float adc_to_current(uint16_t adc_raw) {
    // Step 1: ADC counts → Voltage at ADC input
    float v_adc = ((float)adc_raw / ADC_RESOLUTION) * ADC_VREF;

    // Step 2: Reverse voltage divider to get sensor output
    float v_sensor = v_adc / DIVIDER_RATIO;

    // Step 3: Apply sensor transfer function
    // I = (Vout - Vzero) / Sensitivity
    float current = (v_sensor - ACS712_ZERO_V) / ACS712_SENS;

    return current;
}

// Example:
// ADC reads 2456 counts
// v_adc = (2456 / 4096) × 3.3V = 1.98V
// v_sensor = 1.98V / 0.545 = 3.63V
// current = (3.63V - 2.5V) / 0.1V/A = 11.3A
```

**Optimized version (pre-calculated constants):**

```c
// Pre-calculate all constants for efficiency
#define ADC_TO_AMPS  ((ADC_VREF / ADC_RESOLUTION) / (DIVIDER_RATIO * ACS712_SENS))
#define ZERO_OFFSET  (ACS712_ZERO_V / (DIVIDER_RATIO * ACS712_SENS))

// Simplified calculation:
float adc_to_current_fast(uint16_t adc_raw) {
    return ((float)adc_raw * ADC_TO_AMPS) - ZERO_OFFSET;
}

// With calibration offset:
float adc_to_current_calibrated(uint16_t adc_raw, float cal_offset, float cal_scale) {
    float i = ((float)adc_raw * ADC_TO_AMPS) - ZERO_OFFSET;
    return (i - cal_offset) * cal_scale;
}
```

### Voltage Conversion (DC Bus)

```c
// Convert ADC counts to voltage (DC bus)

#define VDIV_RATIO  (10.0f / 190.0f)  // 10k / (180k + 10k)

float adc_to_voltage(uint16_t adc_raw) {
    // ADC counts → voltage at ADC pin
    float v_adc = ((float)adc_raw / ADC_RESOLUTION) * ADC_VREF;

    // Reverse voltage divider
    float v_actual = v_adc / VDIV_RATIO;

    return v_actual;
}

// Optimized:
#define ADC_TO_VOLTS  ((ADC_VREF / ADC_RESOLUTION) / VDIV_RATIO)

float adc_to_voltage_fast(uint16_t adc_raw) {
    return (float)adc_raw * ADC_TO_VOLTS;
}

// Example:
// ADC reads 1500 counts
// v_adc = (1500 / 4096) × 3.3V = 1.21V
// v_actual = 1.21V / 0.0526 = 23.0V
```

### Lookup Table (For Complex Conversions)

**Use when conversion involves non-linear functions:**

```c
// Pre-calculated lookup table for thermistor (NTC)
// Maps ADC counts → Temperature in °C

const float temp_lut[256] = {
    -40.0f,  // ADC = 0
    -38.5f,  // ADC = 16
    -37.0f,  // ADC = 32
    // ... fill in based on thermistor β curve
    125.0f   // ADC = 4095
};

float adc_to_temperature(uint16_t adc_raw) {
    // Use upper 8 bits as index (reduces table size)
    uint8_t index = adc_raw >> 4;  // Divide by 16

    // Linear interpolation between table entries (optional)
    uint8_t frac = adc_raw & 0xF;
    float temp = temp_lut[index];

    if (index < 255) {
        float delta = temp_lut[index + 1] - temp;
        temp += (delta * frac) / 16.0f;
    }

    return temp;
}
```

---

## Sensor Calibration

### Why Calibration is Essential

**Sources of error:**
1. **Sensor tolerance:** ±1-2% (specified by manufacturer)
2. **Resistor tolerance:** ±1-5% (for voltage dividers)
3. **ADC non-linearity:** ±0.5 LSB
4. **PCB layout:** Parasitic resistance, ground loops
5. **Temperature drift:** Components change with temperature

**Result without calibration:**
- Sensor reads 5.3A when actual is 5.0A (6% error!)
- Unacceptable for control systems

### Two-Point Calibration Method

**Calibrate offset and scale:**

```c
// Calibration procedure

typedef struct {
    float offset;  // Zero offset (when input = 0)
    float scale;   // Scaling factor
} calibration_t;

calibration_t current_cal;
calibration_t voltage_cal;

void calibrate_current(void) {
    printf("Current Calibration\n");
    printf("===================\n\n");

    // Point 1: Zero current
    printf("Step 1: Disconnect load (0A flowing)\n");
    printf("Press Enter when ready...");
    wait_for_enter();

    float zero_sum = 0.0f;
    for (int i = 0; i < 100; i++) {
        uint16_t raw = ADC->DATA[0];
        zero_sum += adc_to_current_fast(raw);
        delay_ms(10);
    }
    float zero_reading = zero_sum / 100.0f;

    printf("Zero reading: %.3f A\n", zero_reading);
    printf("Should be 0.00A, offset = %.3f A\n\n", zero_reading);

    // Point 2: Known current
    printf("Step 2: Apply known test current\n");
    printf("Example: 10V across 10Ω resistor = 1.0A\n");
    printf("Enter actual current (A): ");
    float actual_current = read_float();

    float span_sum = 0.0f;
    for (int i = 0; i < 100; i++) {
        uint16_t raw = ADC->DATA[0];
        span_sum += adc_to_current_fast(raw);
        delay_ms(10);
    }
    float span_reading = span_sum / 100.0f;

    printf("Reading: %.3f A (expected %.3f A)\n", span_reading, actual_current);

    // Calculate calibration factors
    current_cal.offset = zero_reading;
    current_cal.scale = actual_current / (span_reading - zero_reading);

    printf("\nCalibration complete:\n");
    printf("  offset = %.4f A\n", current_cal.offset);
    printf("  scale  = %.4f\n\n", current_cal.scale);

    // Save to flash
    save_calibration(&current_cal);
}

// Apply calibration
float get_calibrated_current(void) {
    uint16_t raw = ADC->DATA[0];
    float uncal = adc_to_current_fast(raw);
    float cal = (uncal - current_cal.offset) * current_cal.scale;
    return cal;
}
```

### Three-Point Calibration (Better Accuracy)

**For non-linear sensors or improving linearity:**

```c
typedef struct {
    float points[3];    // Calibration points (input)
    float values[3];    // Measured values (output)
} cal_3point_t;

cal_3point_t current_cal_3p = {
    .points = {0.0f, 5.0f, 10.0f},    // 0A, 5A, 10A test points
    .values = {0.0f, 0.0f, 0.0f}      // Filled during calibration
};

float apply_3point_cal(float raw_value) {
    // Find which segment we're in
    if (raw_value <= current_cal_3p.values[1]) {
        // Between point 0 and 1
        float t = (raw_value - current_cal_3p.values[0]) /
                  (current_cal_3p.values[1] - current_cal_3p.values[0]);
        return current_cal_3p.points[0] +
               t * (current_cal_3p.points[1] - current_cal_3p.points[0]);
    } else {
        // Between point 1 and 2
        float t = (raw_value - current_cal_3p.values[1]) /
                  (current_cal_3p.values[2] - current_cal_3p.values[1]);
        return current_cal_3p.points[1] +
               t * (current_cal_3p.points[2] - current_cal_3p.points[1]);
    }
}
```

### Storing Calibration in Flash

```c
// Store calibration persistently in flash memory

#define CAL_FLASH_ADDR  0x0001F000  // Last sector of flash

typedef struct {
    uint32_t magic;               // 0xCAFECAFE if valid
    calibration_t current_cal;
    calibration_t voltage_cal;
    calibration_t dc_bus1_cal;
    calibration_t dc_bus2_cal;
    uint32_t crc32;               // CRC for integrity
} calibration_data_t;

void save_calibration(void) {
    calibration_data_t cal_data;

    cal_data.magic = 0xCAFECAFE;
    cal_data.current_cal = current_cal;
    cal_data.voltage_cal = voltage_cal;
    cal_data.dc_bus1_cal = dc_bus1_cal;
    cal_data.dc_bus2_cal = dc_bus2_cal;

    // Calculate CRC
    cal_data.crc32 = crc32_calculate((uint8_t*)&cal_data,
                                    sizeof(cal_data) - 4);

    // Erase flash sector
    flash_erase(CAL_FLASH_ADDR, sizeof(calibration_data_t));

    // Write to flash
    flash_write(CAL_FLASH_ADDR, (uint8_t*)&cal_data,
               sizeof(calibration_data_t));

    printf("Calibration saved to flash\n");
}

bool load_calibration(void) {
    calibration_data_t *cal_data = (calibration_data_t*)CAL_FLASH_ADDR;

    // Check magic
    if (cal_data->magic != 0xCAFECAFE) {
        printf("No valid calibration found\n");
        return false;
    }

    // Verify CRC
    uint32_t crc = crc32_calculate((uint8_t*)cal_data,
                                   sizeof(*cal_data) - 4);
    if (crc != cal_data->crc32) {
        printf("Calibration CRC mismatch\n");
        return false;
    }

    // Load calibration
    current_cal = cal_data->current_cal;
    voltage_cal = cal_data->voltage_cal;
    dc_bus1_cal = cal_data->dc_bus1_cal;
    dc_bus2_cal = cal_data->dc_bus2_cal;

    printf("Calibration loaded from flash\n");
    printf("  Current: offset=%.4f, scale=%.4f\n",
          current_cal.offset, current_cal.scale);
    printf("  Voltage: offset=%.4f, scale=%.4f\n",
          voltage_cal.offset, voltage_cal.scale);

    return true;
}
```

---

## Digital Filtering

### Why Filtering is Needed

**Problem:** Raw ADC readings are noisy!

```
Ideal signal:  5.0A ────────────────────────────

Real signal:   5.2A ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲
               4.8A ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱

Sources of noise:
• PWM switching (10 kHz square waves)
• High-frequency harmonics
• EMI from power circuit
• Ground loops
• ADC quantization noise
```

**Goal:** Extract true signal from noisy measurements

### Filter Types

| Filter Type | Use Case | Latency | Complexity |
|-------------|----------|---------|------------|
| Moving Average | Periodic noise removal | Medium | Low |
| Exponential (IIR) | General low-pass | Low | Very low |
| FIR Filter | Precise frequency response | High | High |
| Median Filter | Spike removal | Medium | Medium |
| Kalman Filter | Optimal estimation | Low | High |

### Exponential Moving Average (IIR Low-Pass)

**Best for real-time control - very low latency and CPU usage.**

```c
// Low-pass filter (1st order IIR)

typedef struct {
    float prev_output;
    float alpha;  // Filter coefficient (0 to 1)
} lpf_t;

void lpf_init(lpf_t *lpf, float cutoff_hz, float sample_rate_hz) {
    // Calculate alpha from cutoff frequency
    // alpha = dt / (RC + dt), where RC = 1 / (2π × fc)

    float rc = 1.0f / (2.0f * 3.14159265359f * cutoff_hz);
    float dt = 1.0f / sample_rate_hz;

    lpf->alpha = dt / (rc + dt);
    lpf->prev_output = 0.0f;
}

float lpf_update(lpf_t *lpf, float input) {
    // Y[n] = α × X[n] + (1 - α) × Y[n-1]
    lpf->prev_output = lpf->alpha * input +
                      (1.0f - lpf->alpha) * lpf->prev_output;
    return lpf->prev_output;
}

// Usage example:
lpf_t current_filter;
lpf_init(&current_filter, 500.0f, 10000.0f);  // 500 Hz cutoff, 10 kHz sampling

// In ISR (every 100 µs):
float raw_current = get_calibrated_current();
float filtered_current = lpf_update(&current_filter, raw_current);
```

**Choosing alpha (cutoff frequency):**

```
Alpha   Cutoff (@ 10kHz sample rate)   Response Time   Noise Reduction
-----   -----------------------------   -------------   ----------------
0.01    ~16 Hz                          Very slow       Excellent
0.05    ~80 Hz                          Slow            Very good
0.10    ~160 Hz                         Medium          Good
0.20    ~320 Hz                         Fast            Moderate
0.50    ~800 Hz                         Very fast       Poor

For 50 Hz inverter:
  Recommended: α = 0.05 to 0.10 (cutoff 80-160 Hz)
  Passes fundamental (50 Hz) ✓
  Blocks PWM switching (10 kHz) ✓
```

### Moving Average Filter

**Good for removing periodic noise (e.g., 10 kHz PWM).**

```c
// Moving average filter

#define MA_SIZE  8  // Power of 2 for efficiency

typedef struct {
    float buffer[MA_SIZE];
    uint8_t index;
    float sum;
    bool filled;
} moving_avg_t;

void ma_init(moving_avg_t *ma) {
    for (int i = 0; i < MA_SIZE; i++) {
        ma->buffer[i] = 0.0f;
    }
    ma->index = 0;
    ma->sum = 0.0f;
    ma->filled = false;
}

float ma_update(moving_avg_t *ma, float input) {
    // Remove oldest sample from sum
    ma->sum -= ma->buffer[ma->index];

    // Add new sample
    ma->buffer[ma->index] = input;
    ma->sum += input;

    // Advance index (circular buffer)
    ma->index = (ma->index + 1) & (MA_SIZE - 1);  // Modulo using bitwise AND

    if (ma->index == 0) {
        ma->filled = true;
    }

    // Return average
    return ma->filled ? (ma->sum / MA_SIZE) : (ma->sum / (ma->index + 1));
}

// Optimized version for power-of-2 sizes:
float ma_update_fast(moving_avg_t *ma, float input) {
    ma->sum -= ma->buffer[ma->index];
    ma->buffer[ma->index] = input;
    ma->sum += input;
    ma->index = (ma->index + 1) & (MA_SIZE - 1);

    return ma->sum * (1.0f / MA_SIZE);  // Multiply instead of divide
}
```

**Choosing window size:**

```
Window Size   Latency (@ 10kHz)   Smoothing   Best For
-----------   -----------------   ---------   --------
4             0.4 ms             Low         Fast response
8             0.8 ms             Medium      Balanced
16            1.6 ms             High        Smooth signal
32            3.2 ms             Very high   Slow-changing
```

### Median Filter (Spike Removal)

**Removes outliers and spikes.**

```c
// Median filter (3-tap for efficiency)

typedef struct {
    float buffer[3];
    uint8_t index;
} median_filter_t;

void median_init(median_filter_t *mf) {
    mf->buffer[0] = 0.0f;
    mf->buffer[1] = 0.0f;
    mf->buffer[2] = 0.0f;
    mf->index = 0;
}

float median_update(median_filter_t *mf, float input) {
    // Add new sample
    mf->buffer[mf->index] = input;
    mf->index = (mf->index + 1) % 3;

    // Find median of 3 samples (sorting network)
    float a = mf->buffer[0];
    float b = mf->buffer[1];
    float c = mf->buffer[2];

    // Sort
    if (a > b) { float t = a; a = b; b = t; }
    if (b > c) { float t = b; b = c; c = t; }
    if (a > b) { float t = a; a = b; b = t; }

    return b;  // Middle value = median
}
```

### Combined Filter Strategy

**Use multiple filters for best results:**

```c
// Complete filtering pipeline

typedef struct {
    median_filter_t median;   // Stage 1: Remove spikes
    moving_avg_t mavg;        // Stage 2: Remove periodic noise
    lpf_t lpf;                // Stage 3: Final smoothing
} sensor_filter_t;

void sensor_filter_init(sensor_filter_t *sf) {
    median_init(&sf->median);
    ma_init(&sf->mavg);
    lpf_init(&sf->lpf, 200.0f, 10000.0f);
}

float sensor_filter_update(sensor_filter_t *sf, float raw_input) {
    // Stage 1: Remove outliers
    float stage1 = median_update(&sf->median, raw_input);

    // Stage 2: Remove periodic noise
    float stage2 = ma_update(&sf->mavg, stage1);

    // Stage 3: Final low-pass
    float filtered = lpf_update(&sf->lpf, stage2);

    return filtered;
}

// Usage:
sensor_filter_t current_filt;
sensor_filter_init(&current_filt);

// In ISR:
float raw = get_calibrated_current();
float clean = sensor_filter_update(&current_filt, raw);
```

---

## Control Decisions

### Threshold-Based Decisions (Safety)

```c
// Safety monitoring with hysteresis

typedef struct {
    // Thresholds
    float max_current;
    float max_voltage;
    float min_dc_bus;
    float max_dc_bus;
    float max_temp;

    // Hysteresis (prevent chattering)
    float hysteresis_pct;

    // State
    uint32_t fault_flags;
    uint32_t fault_count;
    bool in_fault;
} safety_monitor_t;

// Fault flags
#define FAULT_OVERCURRENT    (1 << 0)
#define FAULT_OVERVOLTAGE    (1 << 1)
#define FAULT_UNDERVOLTAGE   (1 << 2)
#define FAULT_BUS_IMBALANCE  (1 << 3)
#define FAULT_OVERTEMPERATURE (1 << 4)

void safety_init(safety_monitor_t *sm) {
    sm->max_current = 15.0f;      // 15A trip
    sm->max_voltage = 125.0f;     // 125V trip
    sm->min_dc_bus = 45.0f;       // 45V minimum
    sm->max_dc_bus = 55.0f;       // 55V maximum
    sm->max_temp = 85.0f;         // 85°C maximum
    sm->hysteresis_pct = 0.1f;    // 10% hysteresis
    sm->fault_flags = 0;
    sm->fault_count = 0;
    sm->in_fault = false;
}

bool safety_check(safety_monitor_t *sm, float current, float voltage,
                  float dc1, float dc2, float temp) {
    bool new_fault = false;

    // Overcurrent check with hysteresis
    float i_abs = fabsf(current);
    if (!sm->in_fault) {
        // Normal operation: check upper threshold
        if (i_abs > sm->max_current) {
            sm->fault_flags |= FAULT_OVERCURRENT;
            new_fault = true;
        }
    } else {
        // Already in fault: need hysteresis to clear
        float clear_threshold = sm->max_current * (1.0f - sm->hysteresis_pct);
        if (i_abs < clear_threshold) {
            sm->fault_flags &= ~FAULT_OVERCURRENT;
        }
    }

    // Overvoltage
    float v_abs = fabsf(voltage);
    if (v_abs > sm->max_voltage) {
        sm->fault_flags |= FAULT_OVERVOLTAGE;
        new_fault = true;
    } else {
        float clear_threshold = sm->max_voltage * (1.0f - sm->hysteresis_pct);
        if (v_abs < clear_threshold) {
            sm->fault_flags &= ~FAULT_OVERVOLTAGE;
        }
    }

    // Undervoltage on DC buses
    if (dc1 < sm->min_dc_bus || dc2 < sm->min_dc_bus) {
        sm->fault_flags |= FAULT_UNDERVOLTAGE;
        new_fault = true;
    }

    // DC bus overvoltage
    if (dc1 > sm->max_dc_bus || dc2 > sm->max_dc_bus) {
        sm->fault_flags |= FAULT_OVERVOLTAGE;
        new_fault = true;
    }

    // Bus imbalance
    float imbalance = fabsf(dc1 - dc2);
    if (imbalance > 5.0f) {  // 5V max difference
        sm->fault_flags |= FAULT_BUS_IMBALANCE;
        new_fault = true;
    }

    // Temperature
    if (temp > sm->max_temp) {
        sm->fault_flags |= FAULT_OVERTEMPERATURE;
        new_fault = true;
    }

    // Update fault state
    sm->in_fault = (sm->fault_flags != 0);

    if (new_fault) {
        sm->fault_count++;
    }

    return !sm->in_fault;  // Return true if safe
}
```

### Proportional-Resonant (PR) Controller

**For sinusoidal reference tracking:**

```c
// PR controller implementation

typedef struct {
    // Gains
    float Kp;      // Proportional gain
    float Kr;      // Resonant gain
    float Wc;      // Cutoff frequency (bandwidth)

    // State variables
    float x1;      // State 1 (integral of cos term)
    float x2;      // State 2 (integral of sin term)

    // Parameters
    float omega;   // Resonant frequency (2π × f)
    float Ts;      // Sample time

    // Output limits
    float min_out;
    float max_out;
} pr_controller_t;

void pr_init(pr_controller_t *pr, float Kp, float Kr, float Wc,
             float resonant_freq_hz, float sample_rate_hz) {
    pr->Kp = Kp;
    pr->Kr = Kr;
    pr->Wc = Wc;
    pr->omega = 2.0f * 3.14159265359f * resonant_freq_hz;
    pr->Ts = 1.0f / sample_rate_hz;
    pr->x1 = 0.0f;
    pr->x2 = 0.0f;
    pr->min_out = 0.0f;
    pr->max_out = 1.0f;
}

void pr_reset(pr_controller_t *pr) {
    pr->x1 = 0.0f;
    pr->x2 = 0.0f;
}

float pr_update(pr_controller_t *pr, float error) {
    // Discrete PR controller (Tustin discretization)
    // Transfer function: G(s) = Kp + Kr × (2ωc × s) / (s² + 2ωc×s + ω²)

    // State update (Euler integration for simplicity)
    float dx1 = -pr->Wc * pr->x1 + error;
    float dx2 = -pr->Wc * pr->x2 + pr->omega * error;

    pr->x1 += dx1 * pr->Ts;
    pr->x2 += dx2 * pr->Ts;

    // Output calculation
    float p_term = pr->Kp * error;
    float r_term = pr->Kr * (pr->Wc * pr->x1 + pr->x2);

    float output = p_term + r_term;

    // Anti-windup: clamp output and back-calculate states if needed
    if (output > pr->max_out) {
        output = pr->max_out;
        // Back-calculate to prevent windup
        float excess = output - (p_term + r_term);
        pr->x1 -= excess / (pr->Kr * pr->Wc) * 0.5f;
        pr->x2 -= excess / pr->Kr * 0.5f;
    } else if (output < pr->min_out) {
        output = pr->min_out;
        float excess = output - (p_term + r_term);
        pr->x1 -= excess / (pr->Kr * pr->Wc) * 0.5f;
        pr->x2 -= excess / pr->Kr * 0.5f;
    }

    return output;
}

// Example usage:
pr_controller_t current_controller;
pr_init(&current_controller, 2.0f, 200.0f, 5.0f, 50.0f, 10000.0f);
//                           Kp    Kr     Wc   freq   sample_rate

// In ISR:
float error = current_ref - current_meas;
float modulation_index = pr_update(&current_controller, error);
```

### Modulation Decision (5-Level Inverter)

```c
// 5-level modulation algorithm

void calculate_5level_duties(float mi, float theta, uint16_t period,
                             uint16_t duties[8]) {
    // mi: Modulation index (0.0 to 1.0)
    // theta: Phase angle (0 to 2π)
    // period: PWM period in counts
    // duties: Output array [S1, S2, S3, S4, S5, S6, S7, S8]

    // Generate sine reference
    float sine_ref = mi * sinf(theta);  // Range: -mi to +mi

    // Level-shifted carrier centers
    const float carrier1_center = -0.5f;  // H-bridge 1: -1 to 0
    const float carrier2_center = +0.5f;  // H-bridge 2: 0 to +1

    // H-bridge 1 decision
    if (sine_ref > carrier1_center) {
        // Positive half of HB1
        float duty = (sine_ref - carrier1_center) * 2.0f;  // Normalize 0-1
        if (duty > 1.0f) duty = 1.0f;

        duties[0] = (uint16_t)(duty * period);  // S1 (high, leg 1)
        duties[1] = 0;                           // S2 (low, leg 1)
        duties[2] = 0;                           // S3 (high, leg 2)
        duties[3] = period;                      // S4 (low, leg 2)
    } else {
        // Negative half of HB1
        float duty = (carrier1_center - sine_ref) * 2.0f;
        if (duty > 1.0f) duty = 1.0f;

        duties[0] = 0;                           // S1
        duties[1] = period;                      // S2
        duties[2] = (uint16_t)(duty * period);  // S3
        duties[3] = 0;                           // S4
    }

    // H-bridge 2 decision (same logic, different carrier)
    if (sine_ref > carrier2_center) {
        float duty = (sine_ref - carrier2_center) * 2.0f;
        if (duty > 1.0f) duty = 1.0f;

        duties[4] = (uint16_t)(duty * period);  // S5
        duties[5] = 0;                           // S6
        duties[6] = 0;                           // S7
        duties[7] = period;                      // S8
    } else {
        float duty = (carrier2_center - sine_ref) * 2.0f;
        if (duty > 1.0f) duty = 1.0f;

        duties[4] = 0;                           // S5
        duties[5] = period;                      // S6
        duties[6] = (uint16_t)(duty * period);  // S7
        duties[7] = 0;                           // S8
    }
}
```

---

## Complete ISR Example

### Real-Time Control Loop (10 kHz)

```c
// Complete ISR implementation for 5-level inverter control

// Global state
pr_controller_t pr_ctrl;
safety_monitor_t safety;
sensor_filter_t current_filt;
sensor_filter_t voltage_filt;
moving_avg_t dc1_filt;
moving_avg_t dc2_filt;

float current_setpoint = 5.0f;  // 5A RMS = 7.07A peak
float freq_hz = 50.0f;
float phase = 0.0f;
float phase_increment;
uint32_t isr_count = 0;

void init_control_system(void) {
    // Initialize controller
    pr_init(&pr_ctrl, 2.0f, 200.0f, 5.0f, freq_hz, 10000.0f);
    pr_ctrl.min_out = 0.0f;
    pr_ctrl.max_out = 0.95f;  // Limit to 95% MI for margin

    // Initialize safety
    safety_init(&safety);

    // Initialize filters
    sensor_filter_init(&current_filt);
    sensor_filter_init(&voltage_filt);
    ma_init(&dc1_filt);
    ma_init(&dc2_filt);

    // Calculate phase increment
    phase_increment = 2.0f * 3.14159265359f * freq_hz / 10000.0f;

    // Enable ADC interrupt
    ADC->IRQ_EN = 1;
    ADC->CONTROL = ADC_CTRL_START | ADC_CTRL_CONT;

    // Enable PWM interrupt
    PWM->IRQ_ENABLE = 1;
}

// PWM update ISR - called at 10 kHz
void pwm_isr(void) {
    // ====================================================================
    // STEP 1: READ AND CONVERT SENSOR DATA
    // ====================================================================

    uint16_t adc_raw[4];
    adc_raw[0] = ADC->DATA[0];  // Output current
    adc_raw[1] = ADC->DATA[1];  // Output voltage
    adc_raw[2] = ADC->DATA[2];  // DC bus 1
    adc_raw[3] = ADC->DATA[3];  // DC bus 2

    // Convert to engineering units
    float current_raw = adc_to_current_calibrated(adc_raw[0],
                                                   current_cal.offset,
                                                   current_cal.scale);
    float voltage_raw = adc_to_voltage_calibrated(adc_raw[1],
                                                   voltage_cal.offset,
                                                   voltage_cal.scale);
    float dc1_raw = adc_to_voltage(adc_raw[2]);
    float dc2_raw = adc_to_voltage(adc_raw[3]);

    // ====================================================================
    // STEP 2: FILTER SIGNALS
    // ====================================================================

    float current_meas = sensor_filter_update(&current_filt, current_raw);
    float voltage_meas = sensor_filter_update(&voltage_filt, voltage_raw);
    float dc1_meas = ma_update(&dc1_filt, dc1_raw);
    float dc2_meas = ma_update(&dc2_filt, dc2_raw);

    // ====================================================================
    // STEP 3: SAFETY CHECKS
    // ====================================================================

    if (!safety_check(&safety, current_meas, voltage_meas, dc1_meas, dc2_meas, 25.0f)) {
        // FAULT DETECTED - EMERGENCY SHUTDOWN!
        PWM->ENABLE = 0x00;  // Disable all PWM outputs

        // Trigger fault handler (non-ISR)
        trigger_fault_handler(safety.fault_flags);

        // Clear interrupt and exit
        volatile uint32_t status = PWM->STATUS;
        return;
    }

    // ====================================================================
    // STEP 4: GENERATE REFERENCE SIGNAL
    // ====================================================================

    // Sinusoidal current reference (peak amplitude)
    float peak_current = current_setpoint * 1.414f;  // RMS to peak
    float current_ref = peak_current * sinf(phase);

    // Advance phase
    phase += phase_increment;
    if (phase >= 2.0f * 3.14159265359f) {
        phase -= 2.0f * 3.14159265359f;
    }

    // ====================================================================
    // STEP 5: CALCULATE ERROR
    // ====================================================================

    float error = current_ref - current_meas;

    // ====================================================================
    // STEP 6: CONTROL ALGORITHM (PR CONTROLLER)
    // ====================================================================

    float modulation_index = pr_update(&pr_ctrl, error);

    // ====================================================================
    // STEP 7: CALCULATE PWM DUTIES
    // ====================================================================

    uint16_t duties[8];
    calculate_5level_duties(modulation_index, phase, PWM->PERIOD, duties);

    // ====================================================================
    // STEP 8: UPDATE PWM OUTPUTS
    // ====================================================================

    for (int i = 0; i < 8; i++) {
        PWM->DUTY[i] = duties[i];
    }

    // ====================================================================
    // STEP 9: LOGGING (Optional - low priority)
    // ====================================================================

    isr_count++;

    // Log every 1000 samples (10 Hz data rate)
    if ((isr_count % 1000) == 0) {
        log_data_point(current_meas, voltage_meas, modulation_index);
    }

    // ====================================================================
    // STEP 10: CLEAR INTERRUPT
    // ====================================================================

    volatile uint32_t status = PWM->STATUS;
    (void)status;  // Reading clears interrupt
}
```

### Performance Metrics

**ISR execution time budget:**

```
Target ISR frequency: 10 kHz
ISR period: 100 µs
Maximum ISR time: ~50 µs (50% CPU usage)

Estimated execution time breakdown:
Step 1 (Read ADC):        2 µs   (4 reads @ 0.5 µs each)
Step 2 (Filtering):       5 µs   (4 filters × ~1.25 µs)
Step 3 (Safety):          3 µs   (comparisons)
Step 4 (Reference):       2 µs   (sin calculation)
Step 5 (Error):           0.5 µs (subtraction)
Step 6 (PR controller):   8 µs   (floating point math)
Step 7 (Modulation):      10 µs  (trig + decisions)
Step 8 (PWM update):      4 µs   (8 writes @ 0.5 µs)
Step 9 (Logging):         1 µs   (conditional)
Step 10 (Clear IRQ):      0.5 µs (register read)
----------------------------------------
TOTAL:                    ~36 µs ✓ (within 50 µs budget)

CPU utilization: 36 µs / 100 µs = 36% ✓
```

**Optimization tips if ISR is too slow:**
1. Use Q15 fixed-point instead of float
2. Pre-calculate constants
3. Use lookup tables for sin/cos
4. Reduce filter complexity
5. Run logging in main loop, not ISR

---

## Troubleshooting

### Problem: Noisy Sensor Readings

**Symptoms:** Large variation in ADC values, jittery control

**Checks:**
1. Scope analog signal before ADC - is it clean?
2. Check grounding - use star ground topology
3. Verify shielding on sensor cables
4. Check for ground loops

**Solutions:**
```c
// Increase filtering
lpf_init(&current_filter, 100.0f, 10000.0f);  // Lower cutoff

// Add moving average
ma_init(&current_mavg);  // Size 16 or 32

// Use combined filtering
sensor_filter_init(&current_filt);
```

### Problem: Sensor Offset Drift

**Symptoms:** Zero reading changes over time or with temperature

**Solution:** Implement runtime zero tracking

```c
// Track zero during idle periods
void track_zero_offset(void) {
    static float zero_tracker = 0.0f;
    static int idle_count = 0;

    // If output is disabled (idle)
    if (PWM->ENABLE == 0x00) {
        float reading = get_calibrated_current();
        zero_tracker = 0.99f * zero_tracker + 0.01f * reading;
        idle_count++;

        if (idle_count >= 1000) {  // After 100ms
            // Update offset
            current_cal.offset = zero_tracker;
            idle_count = 0;
        }
    }
}
```

### Problem: Incorrect Sensor Values

**Symptoms:** Current reads wrong value (e.g., 10A but multimeter shows 5A)

**Checks:**
1. Verify voltage divider resistor values
2. Check ADC reference voltage (should be 3.3V)
3. Re-run calibration procedure
4. Check sensor power supply voltage

**Debug:**
```c
void debug_sensor_chain(void) {
    uint16_t raw = ADC->DATA[0];
    float v_adc = ((float)raw / 4096.0f) * 3.3f;
    float v_sensor = v_adc / DIVIDER_RATIO;
    float current = (v_sensor - ACS712_ZERO_V) / ACS712_SENS;

    printf("Raw ADC: %u counts\n", raw);
    printf("V_adc: %.3f V\n", v_adc);
    printf("V_sensor: %.3f V\n", v_sensor);
    printf("Current: %.3f A\n", current);

    // Expected for 5A:
    // V_sensor should be ~3.0V (2.5V + 5A × 0.1V/A)
    // V_adc should be ~1.6V (3.0V × 0.545)
    // Raw should be ~2000 counts (1.6V / 3.3V × 4096)
}
```

### Problem: Control Loop Unstable

**Symptoms:** Oscillation, instability, runaway

**Checks:**
1. Controller gains too high
2. Insufficient filtering (noise fed to controller)
3. Positive feedback (wiring error)
4. Sample rate too low

**Solutions:**
```c
// Reduce gains
pr_init(&pr_ctrl, 1.0f, 100.0f, 3.0f, 50.0f, 10000.0f);
//                ^^^^   ^^^^^^  ^^^^
//                Lower  Lower   Lower bandwidth

// Increase filtering on feedback signal
lpf_init(&current_filter, 200.0f, 10000.0f);  // Was 500 Hz, now 200 Hz

// Add derivative filtering (if using PID)
lpf_init(&derivative_filter, 100.0f, 10000.0f);
```

---

## Summary

### Sensor Processing Pipeline Checklist

**Hardware:**
- [x] Select appropriate sensors (current, voltage)
- [x] Design signal conditioning (dividers, filters)
- [x] Verify ADC specifications (resolution, sample rate)
- [x] Layout PCB with good grounding practice

**Firmware:**
- [x] Implement ADC driver
- [x] Write conversion functions (ADC counts → engineering units)
- [x] Calibrate sensors (two-point minimum)
- [x] Implement digital filtering (LPF + moving average)
- [x] Add safety checks (thresholds with hysteresis)
- [x] Implement control algorithm (PR controller)
- [x] Calculate modulation (5-level)
- [x] Update PWM outputs

**Testing:**
- [x] Verify sensor accuracy with known inputs
- [x] Measure ISR execution time
- [x] Test safety trip conditions
- [x] Validate control loop stability
- [x] Long-duration reliability test

### Key Takeaways

1. **Signal chain matters** - Clean analog design = easier software
2. **Calibration is essential** - Don't trust nominal values
3. **Filtering is critical** - PWM switching creates significant noise
4. **Safety first** - Always check limits before applying control
5. **Optimize carefully** - Measure before optimizing (ISR time budget)

---

**Document Version:** 1.0
**Last Updated:** 2025-12-09
**Target:** RISC-V RV32IM Embedded Systems
**For:** 5-Level Cascaded H-Bridge Inverter Control
