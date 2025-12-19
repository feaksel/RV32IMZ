# 🏗️ RV32IM SoC 6-MACRO ARCHITECTURE SCHEMATIC

## Complete System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RV32IM SoC COMPLETE CHIP                            │
│                         ~31K cells + 48 SRAM macros                         │
│                         Target: SKY130 130nm, 100 MHz                       │
└─────────────────────────────────────────────────────────────────────────────┘

                                  ┌──────────┐
                                  │   CLK    │
                                  │  100MHz  │
                                  └────┬─────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         ▼                             ▼                             ▼
┌─────────────────┐          ┌──────────────────┐          ┌─────────────────┐
│  CORE MACRO     │◄────────►│  MEMORY MACRO    │          │  PERIPHERALS    │
│  ~11K cells     │ Wishbone │  ~10K + 48 SRAMs │          │  ~10K cells     │
│                 │   Bus    │                  │          │                 │
│  • Pipeline     │          │  • ROM (32KB)    │          │  • PWM (4ch)    │
│  • ALU          │          │  • RAM (64KB)    │          │  • ADC (4ch)    │
│  • MDU          │          │  • Banking Mux   │          │  • UART         │
│  • CSRs         │          │  • WB Slave      │          │  • SPI          │
│  • WB Master    │          │                  │          │  • Protection   │
└─────────────────┘          └──────────────────┘          └─────────────────┘
         │                             │                             │
         └─────────────────────────────┴─────────────────────────────┘
                                       │
                                       ▼
                              ┌────────────────┐
                              │  CHIP I/O PADS │
                              │  GPIO, UART,   │
                              │  PWM, ADC      │
                              └────────────────┘
```

---

## Detailed Macro Breakdown

### 1. CORE MACRO (11,000 cells)

```
┌────────────────────────────────────────────────────────────────┐
│                      CORE MACRO                                │
│                  RV32IM CPU with MDU                           │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  FETCH   │─>│  DECODE  │─>│ EXECUTE  │─>│  MEMORY  │─┐    │
│  └──────────┘  └──────────┘  └────┬─────┘  └──────────┘ │    │
│       ▲                            │                      │    │
│       │                            ▼                      │    │
│       │                      ┌──────────┐                 │    │
│       └──────────────────────┤WRITEBACK │◄────────────────┘    │
│                              └──────────┘                      │
│                                    │                           │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    CORE COMPONENTS                       │ │
│  │                                                          │ │
│  │  • Register File (32 × 32-bit registers)                │ │
│  │  • ALU (ADD, SUB, AND, OR, XOR, SLT, shifts)            │ │
│  │  • Branch Unit (BEQ, BNE, BLT, BGE, BLTU, BGEU)         │ │
│  │  • MDU (MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU) │ │
│  │  • CSRs (mstatus, mtvec, mepc, mcause, etc.)            │ │
│  │  • Hazard Detection & Forwarding Logic                  │ │
│  │  • Exception & Interrupt Handler                        │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  Inputs:  clk, rst_n, interrupts[31:0]                        │
│  Outputs: iwb_* (Instruction Wishbone), dwb_* (Data WB)       │
│                                                                │
└────────────────────────────────────────────────────────────────┘
         │                                     │
         │ Instruction WB                      │ Data WB
         ▼                                     ▼
```

**Pin Placement:**

- TOP: Clock, Reset, Data inputs from memory
- LEFT: Instruction Wishbone bus (address/control out)
- RIGHT: MDU interface (if external), Data inputs
- BOTTOM: Data Wishbone bus outputs

---

### 2. MEMORY MACRO (10,000 cells + 48 SRAM hard macros)

```
┌────────────────────────────────────────────────────────────────┐
│                      MEMORY MACRO                              │
│              32KB ROM + 64KB RAM with Banking                  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    ROM (32KB)                           │  │
│  │  ┌──────┐ ┌──────┐ ┌──────┐       ┌──────┐            │  │
│  │  │Bank 0│ │Bank 1│ │Bank 2│  ...  │Bank15│ (16 banks) │  │
│  │  │ 2KB  │ │ 2KB  │ │ 2KB  │       │ 2KB  │            │  │
│  │  └───┬──┘ └───┬──┘ └───┬──┘       └───┬──┘            │  │
│  │      │        │        │               │               │  │
│  │      └────────┴────────┴───────────────┘               │  │
│  │                       │                                │  │
│  │                  ┌────▼────┐                           │  │
│  │                  │ ROM MUX │ ◄── rom_addr[14:11]       │  │
│  │                  └────┬────┘     (bank select)         │  │
│  └───────────────────────┼──────────────────────────────────┘
│                          │                                   │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    RAM (64KB)                           │  │
│  │  ┌──────┐ ┌──────┐ ┌──────┐       ┌──────┐            │  │
│  │  │Bank 0│ │Bank 1│ │Bank 2│  ...  │Bank31│ (32 banks) │  │
│  │  │ 2KB  │ │ 2KB  │ │ 2KB  │       │ 2KB  │            │  │
│  │  └───┬──┘ └───┬──┘ └───┬──┘       └───┬──┘            │  │
│  │      │        │        │               │               │  │
│  │      └────────┴────────┴───────────────┘               │  │
│  │                       │                                │  │
│  │                  ┌────▼────┐                           │  │
│  │                  │ RAM MUX │ ◄── ram_addr[15:11]       │  │
│  │                  └────┬────┘     (bank select)         │  │
│  └───────────────────────┼──────────────────────────────────┘
│                          │                                   │
│                    ┌─────▼─────┐                             │
│                    │ WB SLAVE  │                             │
│                    │ INTERFACE │                             │
│                    └───────────┘                             │
│                                                                │
│  Each SRAM: sky130_sram_2kbyte_1rw1r_32x512_8                │
│  • 512 words × 32 bits = 2048 bytes                          │
│  • 1RW + 1R ports (dual-ported)                              │
│  • Black-box hard macro (don't touch in synthesis)           │
│                                                                │
│  Inputs:  wb_adr_i, wb_dat_i, wb_we_i, wb_sel_i, wb_cyc_i    │
│  Outputs: wb_dat_o, wb_ack_o                                  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Memory Map:**

```
0x00000000 - 0x00007FFF : ROM (32 KB) - Instruction memory
0x00010000 - 0x0001FFFF : RAM (64 KB) - Data memory
```

**Pin Placement:**

- TOP: Clock, Reset
- LEFT: Wishbone slave inputs (address, data, control)
- RIGHT: Wishbone data outputs

---

### 3-6. PERIPHERAL MACROS (~10,000 cells total)

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│   PWM ACCELERATOR   │  │   ADC SUBSYSTEM     │  │   PROTECTION        │
│      ~3K cells      │  │      ~4K cells      │  │      ~1K cells      │
├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤
│                     │  │                     │  │                     │
│  ┌───────────────┐  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │
│  │ PWM Channel 0 │──┼──┼──│ Σ-Δ Modulator │  │  │  │ Thermal Sense │  │
│  ├───────────────┤  │  │  ├───────────────┤  │  │  ├───────────────┤  │
│  │ PWM Channel 1 │──┼──┼──│  CIC Filter   │  │  │  │   Watchdog    │  │
│  ├───────────────┤  │  │  ├───────────────┤  │  │  ├───────────────┤  │
│  │ PWM Channel 2 │──┼──┼──│  FIR Filter   │  │  │  │  OCP/OVP Det  │  │
│  ├───────────────┤  │  │  ├───────────────┤  │  │  ├───────────────┤  │
│  │ PWM Channel 3 │──┼──┼──│ 4-ch Sequencer│  │  │  │ Reset Logic   │  │
│  └───────────────┘  │  │  └───────────────┘  │  │  └───────────────┘  │
│         │           │  │         │           │  │         │           │
│    ┌────▼────┐      │  │    ┌────▼────┐     │  │    ┌────▼────┐     │
│    │ WB Slave│      │  │    │ WB Slave│     │  │    │ WB Slave│     │
│    └─────────┘      │  │    └─────────┘     │  │    └─────────┘     │
│                     │  │                     │  │                     │
│ Outputs:            │  │ Inputs:             │  │ Outputs:            │
│ pwm_out[3:0]        │  │ adc_in[3:0]         │  │ watchdog_rst        │
│                     │  │                     │  │ thermal_fault       │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘

┌─────────────────────────────────────────────┐
│         COMMUNICATION MACRO                 │
│              ~2K cells                      │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────┐        ┌─────────────┐    │
│  │    UART     │        │     SPI     │    │
│  ├─────────────┤        ├─────────────┤    │
│  │  TX FIFO    │        │ SPI Master  │    │
│  │  RX FIFO    │        │ SPI Slave   │    │
│  │ Baud Gen    │        │ Mode Ctrl   │    │
│  └──────┬──────┘        └──────┬──────┘    │
│         │                      │            │
│    ┌────┴────────────────┬─────┴────┐       │
│    │      WB Slave       │          │       │
│    └─────────────────────┘          │       │
│                                     │       │
│ Outputs: uart_tx, spi_sclk,         │       │
│          spi_mosi, spi_cs           │       │
│ Inputs:  uart_rx, spi_miso          │       │
│                                             │
└─────────────────────────────────────────────┘
```

**Peripheral Memory Map:**

```
0x00020000 - 0x000200FF : PWM Accelerator
0x00020100 - 0x000201FF : ADC Subsystem
0x00020200 - 0x000202FF : Protection
0x00020300 - 0x000203FF : Timer
0x00020400 - 0x000204FF : GPIO
0x00020500 - 0x000205FF : UART
0x00020600 - 0x000206FF : SPI
```

---

## Wishbone Bus Interconnect

```
                    WISHBONE SHARED BUS
                          (32-bit)

         ┌─────────────────┴─────────────────┐
         │                                   │
    ┌────▼────┐                         ┌────▼────┐
    │ MASTER  │                         │ ARBITER │
    │  (Core) │                         │         │
    └────┬────┘                         └────┬────┘
         │                                   │
         │  iwb_adr_o[31:0]                  │
         │  iwb_dat_i[31:0]                  │
         │  iwb_cyc_o, iwb_stb_o             │
         │  iwb_ack_i                        │
         │                                   │
         │  dwb_adr_o[31:0]                  │
         │  dwb_dat_o[31:0]                  │
         │  dwb_dat_i[31:0]                  │
         │  dwb_we_o, dwb_sel_o[3:0]         │
         │  dwb_cyc_o, dwb_stb_o             │
         │  dwb_ack_i                        │
         │                                   │
         └───────────────┬───────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌────▼────┐
    │ Memory  │    │Peripherals│   │  More   │
    │  Slave  │    │  Slaves   │   │ Slaves  │
    └─────────┘    └───────────┘   └─────────┘
```

**Bus Protocol:**

- Width: 32-bit address, 32-bit data
- Pipelining: Classic Wishbone (no pipelining)
- Byte enables: 4-bit sel for byte/halfword access
- Cycles: Single cycle for registers, multi-cycle for memory

---

## Physical Layout Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                         DIE LAYOUT                          │
│                     (Not to scale)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────────────────┐          │
│  │    CORE     │    │      MEMORY MACRO        │          │
│  │   MACRO     │◄──►│  ┌────┐ ┌────┐ ┌────┐   │          │
│  │             │    │  │ROM │ │ROM │ │ROM │   │          │
│  │  ~11K cells │    │  │Bank│ │Bank│ │Bank│..│          │
│  │             │    │  └────┘ └────┘ └────┘   │          │
│  │  ~120×120μm │    │  ┌────┐ ┌────┐ ┌────┐   │          │
│  └─────────────┘    │  │RAM │ │RAM │ │RAM │   │          │
│                     │  │Bank│ │Bank│ │Bank│..│          │
│                     │  └────┘ └────┘ └────┘   │          │
│                     │     ~150×150μm           │          │
│                     └──────────────────────────┘          │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   PWM    │  │   ADC    │  │   PROT   │  │   COMM   │  │
│  │ ~40×40μm │  │ ~50×50μm │  │ ~30×30μm │  │ ~35×35μm │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              POWER GRID & ROUTING                    │  │
│  │  • Power rings around each macro                     │  │
│  │  • Metal layers: 5-6 (SKY130 has 5 metal layers)     │  │
│  │  • Clock tree from top-level to all macros           │  │
│  │  • Wishbone bus routing between macros               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Estimated Total Die Size: ~400×400 μm (SKY130 130nm)
Total Gate Count: ~31,000 cells + 48 SRAM macros
```

---

## Clock Distribution

```
                    CLK_100MHz (External)
                           │
                           ▼
                    ┌──────────────┐
                    │  CLOCK TREE  │
                    │   BUFFER     │
                    └──────┬───────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │   CORE   │    │  MEMORY  │    │PERIPHERAL│
    │   CLK    │    │   CLK    │    │   CLK    │
    └──────────┘    └──────────┘    └──────────┘
```

**Clock Strategy:**

- Single 100 MHz clock domain
- Clock tree synthesis (CTS) in each macro
- Balanced clock distribution
- Skew target: <100ps between macros

---

## Power Distribution

```
                VDD (1.8V) / VSS (GND)
                           │
                ┌──────────┴──────────┐
                │   TOP-LEVEL RING    │
                └──────────┬──────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼──────┐
    │  Core Ring  │ │ Memory Ring │ │Periph Ring │
    │  + Stripes  │ │  + Stripes  │ │ + Stripes  │
    └─────────────┘ └─────────────┘ └────────────┘
```

**Power Strategy:**

- Metal 1: Power rails (VDD/VSS) for standard cells
- Metal 2/3: Power stripes (vertical/horizontal)
- Metal 4/5: Top-level power rings
- IR drop target: <50mV across die

---

## Data Flow Example: Load Instruction

```
1. FETCH (Core Macro)
   PC → iwb_adr_o → Memory Macro

2. MEMORY (Memory Macro)
   ROM Bank Select → SRAM Access → Instruction

3. RETURN
   instruction → iwb_dat_i → Core Macro

4. DECODE & EXECUTE (Core Macro)
   Decode instruction → Execute in ALU/MDU

5. MEMORY ACCESS (if needed)
   dwb_adr_o → Memory Macro or Peripheral

6. WRITEBACK
   Result → Register File
```

---

## Build Flow

```
RTL Files (.v)
     │
     ▼
┌─────────────────┐
│  SYNTHESIS      │  ← Genus
│  Per Macro      │     • Core macro: 30-40 min
│                 │     • Memory macro: 40-50 min
└────────┬────────┘     • Peripherals: 10-20 min each
         │
         ▼
   Netlist (.v)
         │
         ▼
┌─────────────────┐
│  PLACE & ROUTE  │  ← Innovus
│  Per Macro      │     • Floorplan
│                 │     • Pin placement (NEW!)
│                 │     • Power planning
│                 │     • CTS (with fallback)
│                 │     • Routing
└────────┬────────┘     • DRC fixing
         │
         ▼
   GDS + LEF
         │
         ▼
┌─────────────────┐
│  INTEGRATION    │  ← Innovus
│  Top Level      │     • Read all LEF files
│                 │     • Place macros as blocks
│                 │     • Route interconnect
│                 │     • Final DRC/LVS
└────────┬────────┘
         │
         ▼
  soc_complete.gds  ← READY FOR FABRICATION!
```

**Total Build Time:** 3-4 hours for all 7 macros + integrated option

---

## Final Die Pinout and Pad Placement

### Complete Die with I/O Pads

```
                    TOP EDGE (North)
        ┌─────────────────────────────────────────────┐
        │ VDD  CLK  RST  JTAG  JTAG  JTAG  JTAG  VSS │
        │      100  _N   TDI   TDO   TCK   TMS        │
        │      MHz                                    │
        ├─────────────────────────────────────────────┤
        │                                             │
    W   │  ┌─────────────────────────────────────┐   │  E
    E   │  │                                     │   │  A
    S   │  │         CORE + MACROS               │   │  S
    T   │  │         (Internal Die)              │   │  T
        │  │                                     │   │
    E   │  │  ┌────┐ ┌─────────┐ ┌────┐         │   │  E
    D   │  │  │Core│ │ Memory  │ │Peri│         │   │  D
    G   │  │  │    │ │ (SRAMs) │ │phs │         │   │  G
    E   │  │  └────┘ └─────────┘ └────┘         │   │  E
        │  │                                     │   │
  GPIO  │  └─────────────────────────────────────┘   │  ADC
  [7:0] │                                             │  [3:0]
        │                                             │
   VDD  │                                             │  VDD
   VSS  │                                             │  VSS
        │                                             │
        ├─────────────────────────────────────────────┤
        │ VDD  PWM  PWM  PWM  PWM  UART UART SPI  VSS│
        │      [0]  [1]  [2]  [3]  TX   RX   *        │
        └─────────────────────────────────────────────┘
                    BOTTOM EDGE (South)

* SPI = SCLK, MOSI, MISO, CS (4 pins)
```

### Detailed Pad Assignments by Edge

#### **TOP EDGE (North) - Power & Control Signals**

| Pin # | Signal     | Type   | Description                  |
| ----- | ---------- | ------ | ---------------------------- |
| 1     | VDD        | Power  | Core power supply (1.8V)     |
| 2     | CLK_100MHz | Input  | Main system clock (buffered) |
| 3     | RST_N      | Input  | Active-low reset (buffered)  |
| 4     | JTAG_TDI   | Input  | JTAG Test Data In            |
| 5     | JTAG_TDO   | Output | JTAG Test Data Out           |
| 6     | JTAG_TCK   | Input  | JTAG Test Clock              |
| 7     | JTAG_TMS   | Input  | JTAG Test Mode Select        |
| 8     | VSS        | Ground | Ground reference             |

**Reasoning:**

- Clock at top center for balanced distribution
- Power/ground at corners for low impedance
- JTAG grouped together for easy probe access
- Reset near clock for timing control

---

#### **BOTTOM EDGE (South) - Output Peripherals**

| Pin # | Signal     | Type   | Description                   |
| ----- | ---------- | ------ | ----------------------------- |
| 9     | VDD        | Power  | Core power supply (1.8V)      |
| 10    | PWM_OUT[0] | Output | PWM channel 0 (motor control) |
| 11    | PWM_OUT[1] | Output | PWM channel 1 (motor control) |
| 12    | PWM_OUT[2] | Output | PWM channel 2 (motor control) |
| 13    | PWM_OUT[3] | Output | PWM channel 3 (motor control) |
| 14    | UART_TX    | Output | UART transmit                 |
| 15    | UART_RX    | Input  | UART receive                  |
| 16    | SPI_SCLK   | Bidir  | SPI clock (master/slave)      |
| 17    | SPI_MOSI   | Bidir  | SPI master-out slave-in       |
| 18    | SPI_MISO   | Bidir  | SPI master-in slave-out       |
| 19    | SPI_CS     | Bidir  | SPI chip select               |
| 20    | VSS        | Ground | Ground reference              |

**Reasoning:**

- PWM outputs grouped for motor driver connection
- UART/SPI near each other (serial communication)
- Bottom edge good for PCB routing to external connectors
- Power/ground for local decoupling

---

#### **LEFT EDGE (West) - GPIO & Digital I/O**

| Pin # | Signal  | Type   | Description               |
| ----- | ------- | ------ | ------------------------- |
| 21    | VDD     | Power  | Core power supply (1.8V)  |
| 22    | GPIO[0] | Bidir  | General purpose I/O bit 0 |
| 23    | GPIO[1] | Bidir  | General purpose I/O bit 1 |
| 24    | GPIO[2] | Bidir  | General purpose I/O bit 2 |
| 25    | GPIO[3] | Bidir  | General purpose I/O bit 3 |
| 26    | GPIO[4] | Bidir  | General purpose I/O bit 4 |
| 27    | GPIO[5] | Bidir  | General purpose I/O bit 5 |
| 28    | GPIO[6] | Bidir  | General purpose I/O bit 6 |
| 29    | GPIO[7] | Bidir  | General purpose I/O bit 7 |
| 30    | LED[0]  | Output | Status LED 0              |
| 31    | LED[1]  | Output | Status LED 1              |
| 32    | LED[2]  | Output | Status LED 2              |
| 33    | LED[3]  | Output | Status LED 3              |
| 34    | VSS     | Ground | Ground reference          |

**Reasoning:**

- GPIO grouped together for easy PCB breakout
- LEDs near GPIO for logical grouping
- Digital signals away from analog (ADC on right edge)
- Left edge typically used for digital I/O in standard layouts

---

#### **RIGHT EDGE (East) - Analog & Sensing**

| Pin # | Signal         | Type       | Description                           |
| ----- | -------------- | ---------- | ------------------------------------- |
| 35    | VDDA           | Power      | Analog power supply (1.8V, filtered)  |
| 36    | ADC_IN[0]      | Analog In  | ADC channel 0 (Σ-Δ comparator input)  |
| 37    | ADC_IN[1]      | Analog In  | ADC channel 1                         |
| 38    | ADC_IN[2]      | Analog In  | ADC channel 2                         |
| 39    | ADC_IN[3]      | Analog In  | ADC channel 3                         |
| 40    | ADC_DAC_OUT[0] | Analog Out | Σ-Δ DAC feedback 0                    |
| 41    | ADC_DAC_OUT[1] | Analog Out | Σ-Δ DAC feedback 1                    |
| 42    | ADC_DAC_OUT[2] | Analog Out | Σ-Δ DAC feedback 2                    |
| 43    | ADC_DAC_OUT[3] | Analog Out | Σ-Δ DAC feedback 3                    |
| 44    | THERMAL_SENSE  | Analog In  | Temperature sensor input              |
| 45    | FAULT_OCP      | Input      | Overcurrent protection flag           |
| 46    | FAULT_OVP      | Input      | Overvoltage protection flag           |
| 47    | ESTOP_N        | Input      | Emergency stop (active low)           |
| 48    | VSSA           | Ground     | Analog ground (separate from digital) |

**Reasoning:**

- Analog signals isolated on one edge
- Separate analog power/ground (VDDA/VSSA)
- ADC inputs grouped for shielding
- Fault/protection signals near analog domain
- Away from noisy digital signals (PWM, UART)

---

### Power Pad Distribution

```
Corner Placement Strategy:

   VDD (Top-Left)          VDD (Top-Right)
        ┌──────────────────────┐
        │                      │
   VDD  │                      │  VDDA
  (West)│     CORE AREA        │ (East)
        │                      │
   VSS  │                      │  VSSA
  (West)│                      │ (East)
        │                      │
        └──────────────────────┘
   VSS (Bottom-Left)       VSS (Bottom-Right)
```

**Power Pad Count:**

- VDD pads: 4 (one per edge)
- VDDA pads: 2 (analog power, right edge)
- VSS pads: 4 (one per edge)
- VSSA pads: 2 (analog ground, right edge)
- **Total power pads: 12** (out of ~48 total pads)

**Power Pad Sizing:**

- Power pads: 100μm × 100μm (larger for current handling)
- Signal pads: 75μm × 75μm
- Pad pitch: 150μm (standard for SKY130)

---

### Pad Ring Cross-Section

```
                    ┌──────────────┐
                    │   Bond Pad   │ ← Wire bond or flip-chip bump
                    │   (Al/Cu)    │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  ESD Diodes  │ ← Protection against ESD
                    │  (Primary)   │    (±2kV HBM minimum)
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  I/O Buffer  │ ← Level shifters (if needed)
                    │  (Driver)    │    Slew rate control
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Internal Net │ → To core/peripherals
                    └──────────────┘
```

**Each pad includes:**

1. **Bond pad** - Metal contact for wire bonding
2. **ESD protection** - Dual diodes + resistor (HBM 2kV rating)
3. **I/O buffer** - Tri-state driver/receiver
4. **Level shifter** (if core voltage ≠ I/O voltage)

---

### Physical Die Layout with Pads

```
┌───────────────────────────────────────────────────────────────┐
│                        PAD RING                               │
│  ╔══════════════════════════════════════════════════════╗     │
│  ║              TOP PAD ROW                             ║     │
│  ║  [VDD][CLK][RST][JTAG×4][VSS]                        ║     │
│  ╠══════════════════════════════════════════════════════╣     │
│  ║ L                                                 R  ║     │
│  ║ E                  CORE AREA                      I  ║     │
│  ║ F   ┌──────────────────────────────────────┐     G  ║     │
│  ║ T   │ Core Macro                           │     H  ║     │
│  ║     │ ~120×120μm                           │     T  ║     │
│  ║ P   ├──────────────────────────────────────┤        ║     │
│  ║ A   │ Memory Macro (with SRAMs)            │     P  ║     │
│  ║ D   │ ~150×150μm                           │     A  ║     │
│  ║ S   │ ┌─┐┌─┐┌─┐ ROM Banks                 │     D  ║     │
│  ║     │ └─┘└─┘└─┘ (16×2KB)                  │     S  ║     │
│  ║ G   │ ┌─┐┌─┐┌─┐ RAM Banks                 │        ║     │
│  ║ P   │ └─┘└─┘└─┘ (32×2KB)                  │     A  ║     │
│  ║ I   ├──────────────────────────────────────┤     D  ║     │
│  ║ O   │ Peripheral Macros                    │     C  ║     │
│  ║ ×   │ [PWM][ADC][PROT][COMM]               │        ║     │
│  ║ 8   │ ~40   ~50  ~30   ~35 μm              │     ×  ║     │
│  ║ +   └──────────────────────────────────────┘     4  ║     │
│  ║ LED                                                  ║     │
│  ║ ×4                                                   ║     │
│  ╠══════════════════════════════════════════════════════╣     │
│  ║              BOTTOM PAD ROW                          ║     │
│  ║  [VDD][PWM×4][UART×2][SPI×4][VSS]                    ║     │
│  ╚══════════════════════════════════════════════════════╝     │
│                                                               │
└───────────────────────────────────────────────────────────────┘

Die Size: ~600×600 μm (including pad ring)
Core Size: ~400×400 μm (active area)
Pad Ring Width: ~100 μm per edge
```

---

### Pad Type and Drive Strength

| Pad Type                 | Count | Drive Strength | Special Features                   |
| ------------------------ | ----- | -------------- | ---------------------------------- |
| Power (VDD/VSS)          | 8     | N/A            | Wide metal, multiple vias          |
| Analog Power (VDDA/VSSA) | 4     | N/A            | Filtered, isolated from digital    |
| Clock Input              | 1     | N/A            | Low-jitter buffer, ESD protected   |
| Reset Input              | 1     | N/A            | Schmitt trigger, glitch filter     |
| JTAG                     | 4     | 2mA            | Weak pull-ups, boundary scan       |
| GPIO                     | 8     | 4/8mA          | Configurable drive, pull-up/down   |
| LED Outputs              | 4     | 8mA            | High current drive for LEDs        |
| UART                     | 2     | 4mA            | Standard CMOS levels               |
| SPI                      | 4     | 8mA            | High speed capable (25 MHz)        |
| PWM Outputs              | 4     | 8/16mA         | Configurable for motor drivers     |
| ADC Analog               | 8     | N/A            | High impedance input, no ESD clamp |
| Protection Inputs        | 3     | 2mA            | Schmitt trigger inputs             |

---

### Signal Integrity Considerations

#### **Clock Distribution to Pads**

```
External CLK → CLK Pad → ESD → Input Buffer → Clock Tree
                                    │
                                    └→ PLL (optional, future)
                                    └→ Clock Divider (50MHz, 25MHz)
```

#### **Ground Bounce Mitigation**

- **Multiple VSS pads** distributed around die
- **Separate VSSA/VSS** for analog/digital
- **On-chip decoupling caps** near each macro
- **Controlled slew rates** on outputs (minimize dI/dt)

#### **ESD Protection Strategy**

- **Primary protection:** Dual diodes at each pad
- **Secondary protection:** Internal clamps near core
- **Rating target:** 2kV HBM (Human Body Model)
- **CDM protection:** 500V (Charged Device Model)

---

### Package and Bonding

#### **Recommended Package:** QFN48 (Quad Flat No-lead)

```
                 Pin 1 (VDD)
                     ↓
        ┌─────────────────────────┐
        │ 12  11  10   9   8   7  │
        │                         │
    13 ─┤                         ├─ 6
    14 ─┤      DIE CAVITY         ├─ 5
    15 ─┤      (center)           ├─ 4
    16 ─┤                         ├─ 3
    17 ─┤                         ├─ 2
    18 ─┤                         ├─ 1
        │                         │
        │ 19  20  21  22  23  24  │
        └─────────────────────────┘

QFN48: 7mm × 7mm package
Pad pitch: 0.5mm
Exposed pad: 5mm × 5mm (for thermal and ground)
```

#### **Alternative Package:** TQFP48 (Thin Quad Flat Pack)

- Better for hand soldering
- Easier PCB routing (through-hole leads)
- Slightly larger: 7mm × 7mm body, 9mm × 9mm including leads

---

### Pin Assignment Summary Table

| Edge       | Signal Group       | Pin Count   | Purpose                           |
| ---------- | ------------------ | ----------- | --------------------------------- |
| **TOP**    | Power & Control    | 8           | VDD, VSS, CLK, RST, JTAG×4        |
| **BOTTOM** | Output Peripherals | 12          | VDD, VSS, PWM×4, UART×2, SPI×4    |
| **LEFT**   | Digital I/O        | 14          | VDD, VSS, GPIO×8, LED×4           |
| **RIGHT**  | Analog & Sensing   | 14          | VDDA, VSSA, ADC×8, FAULT×3, ESTOP |
| **Total**  |                    | **48 pads** | Including 12 power pads           |

---

### Manufacturing Notes

**For SKY130 PDK:**

- Minimum pad size: 75μm × 75μm
- Pad pitch: 100-150μm recommended
- Bond wire diameter: 25μm (1 mil) for signal, 50μm (2 mil) for power
- Passivation opening: 60μm × 60μm (smaller than pad)

**For PCB Design:**

- Use ground plane under entire chip
- Separate analog/digital ground planes (star connection)
- Decoupling caps: 100nF near each power pin
- Guard rings around analog signals
- Kelvin sensing for power measurements

---

## Key Takeaways

✅ **48 total pads** organized by function on 4 edges  
✅ **TOP:** Control signals (clock, reset, JTAG)  
✅ **BOTTOM:** Output peripherals (PWM, UART, SPI)  
✅ **LEFT:** Digital I/O (GPIO, LEDs)  
✅ **RIGHT:** Analog signals (ADC, sensors) - isolated!  
✅ **12 power pads** distributed for low impedance  
✅ **Separate analog power domain** (VDDA/VSSA)  
✅ **QFN48 or TQFP48** package recommended

---

## Key Features Summary

| Macro         | Size           | Complexity | Special Features                  |
| ------------- | -------------- | ---------- | --------------------------------- |
| Core          | 11K cells      | High       | RV32IM ISA, MDU, hazard detection |
| Memory        | 10K + 48 SRAMs | Medium     | Real SRAM macros, banking         |
| PWM           | 3K cells       | Low        | 4 channels, motor control         |
| ADC           | 4K cells       | Medium     | Σ-Δ modulator, digital filters    |
| Protection    | 1K cells       | Low        | Thermal, watchdog, fault detect   |
| Communication | 2K cells       | Low        | UART, SPI with FIFOs              |

**Total Resources:**

- Gates: ~31,000 standard cells
- SRAM: 48 hard macros (96KB total memory)
- I/O Pads: ~50-60 (GPIO, UART, SPI, PWM, ADC, power)
- Metal Layers: 5 (SKY130 limit)
- Estimated Die Area: 400×400 μm to 500×500 μm

---

**Last Updated:** December 19, 2025  
**Status:** All macros synthesized, P&R scripts ready with pin placement ✅
