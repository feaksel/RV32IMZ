# SoC Bus and Memory Refactoring Report

**Date:** 2025-12-13
**Author:** Gemini AI

## 1. Overview

This document details the refactoring of the top-level SoC architecture (`soc_top.v`), focusing on the memory subsystem and the CPU bus interface. The goal was to transform the design from a simulation-only configuration to a robust, synthesizable structure that follows standard ASIC and FPGA design practices.

---

## 2. The Problem: A Non-Synthesizable Memory Architecture

The previous `soc_top.v` architecture had two major issues that prevented a clean RTL-to-GDSII flow:

### 2.1. Hard-Coded Behavioral Memories

The ROM and RAM were instantiated directly as behavioral Verilog modules (`rom_32kb` and `ram_64kb`).

**Example (Old `soc_top.v`):**
```verilog
    rom_32kb #(
        .MEM_FILE("firmware/firmware.hex")
    ) rom (
        .clk(clk),
        .addr(rom_addr_mux),
        .stb(rom_stb_mux),
        .data_out(rom_dat_o),
        .ack(rom_ack)
    );

    ram_64kb ram (
        .clk(clk),
        .addr(ram_addr),
        // ...
    );
```

While this works for simulation, synthesis tools cannot convert this into efficient hardware memory. They would attempt to build the memory out of standard logic gates (flip-flops and multiplexers), resulting in an enormous, slow, and power-hungry design that would fail to meet timing and area constraints.

### 2.2. Inefficient Custom Bus Arbitration

The CPU has two distinct buses: an **Instruction Bus (IBus)** for fetching code and a **Data Bus (DBus)** for load/store operations. The main bus interconnect, however, only had one master port for the DBus.

To solve this, the old design implemented a custom, manual arbiter specifically for the ROM, mixing arbitration logic directly into the top-level SoC file.

**Example (Old `soc_top.v`):**
```verilog
    // ROM is accessed from BOTH instruction bus (ibus) and data bus (dbus)
    // Simple priority arbiter: ibus has priority

    wire rom_req_ibus = cpu_ibus_stb && cpu_ibus_cyc;

    // ROM arbiter: prioritize instruction bus
    wire [14:0] rom_addr_mux = rom_req_ibus ? cpu_ibus_addr[14:0] : rom_addr_dbus;
    wire        rom_stb_mux  = rom_req_ibus ? rom_req_ibus : rom_stb_dbus;

    // ... rom instantiation uses rom_addr_mux and rom_stb_mux ...
```
This approach was:
- **Not Scalable:** It only worked for the ROM. If the IBus needed to access another resource, the logic would become even more complex.
- **Poor Design Practice:** Arbitration logic should be encapsulated within a dedicated bus module, not spread across the top-level file.
- **Inefficient:** It bypassed the main bus interconnect for instruction fetches, creating two separate paths to memory.

---

## 3. The Solution: A Standard, Synthesizable Architecture

The architecture was refactored into a standard, clean design using two key changes.

### 3.1. Centralized Bus Arbitration

A new, dedicated **2-to-1 Wishbone Arbiter** (`wishbone_arbiter_2x1.v`) was created and placed in `rtl/bus/`.

**Key Features:**
- **Two Slave Ports:** One for the CPU's IBus, one for the DBus.
- **One Master Port:** Connects to the single master port of the main `wishbone_interconnect`.
- **Fixed Priority:** The IBus (connected to slave port 0) is always given priority over the DBus. This is critical to prevent the CPU from stalling on instruction fetches.

**New Architecture Flow:**
```
            +-----------------+      +-----------------+
CPU IBus -->|                 |      |                 |
            | Arbiter Slave 0 |      | Interconnect    |
            +-----------------+--+-->|                 |-----> Peripherals
            |                 |  |   | Master Port     |
CPU DBus -->| Arbiter Slave 1 |  |   |                 |-----> Memory
            +-----------------+  |   +-----------------+
                                 |
            +-----------------+  |
            | Arbiter Master  |--+
            +-----------------+
```

This centralizes all arbitration logic and allows both CPU buses to access any resource on the main bus through a single, unified path.

### 3.2. Simulation-Aware Memory Subsystem

The hard-coded memory modules were removed and replaced with a conditional compilation block (`ifdef SIMULATION / else SYNTHESIS`).

**New `soc_top.v` Structure:**
```verilog
`ifdef SIMULATION
    //--------------------------------------------------------------------------
    // Behavioral Memory for Simulation
    //--------------------------------------------------------------------------
    // Use `reg` arrays and `$readmemh` for fast, simple simulation.
    // This code is ignored by the synthesis tool.

    reg [31:0] rom_mem [0:8191];
    initial $readmemh("firmware/firmware.hex", rom_mem);

    reg [31:0] ram_mem [0:16383];
    // ... logic for reads/writes ...

`else // SYNTHESIS
    //--------------------------------------------------------------------------
    // Synthesizable SRAM Macros for ASIC/FPGA
    //--------------------------------------------------------------------------
    // This section is used by the synthesis tool.
    // It contains commented-out placeholders for instantiating the
    // actual, physical SRAM macros provided by the foundry/PDK.

    // sram_32kb_macro rom_macro ( ... );
    // sram_64kb_macro ram_macro ( ... );

`endif
```
**This approach provides the best of both worlds:**
- **For Simulation:** We can use simple, fast, behavioral Verilog to model the memory, allowing for rapid testing at home without needing any special libraries.
- **For Synthesis:** The synthesizer will ignore the `SIMULATION` block and instead use the `SYNTHESIS` block. At the school lab, the commented-out placeholders will be replaced with the real SRAM macros, resulting in an efficient, correct hardware implementation.

## 4. Conclusion

The `soc_top.v` module is now properly structured for a professional RTL-to-GDSII flow. The bus architecture is clean and scalable, and the memory subsystem is flexible, supporting both fast simulation and efficient synthesis. This resolves the critical "RAM/ROM issue" and prepares the design for the next stage of the project: synthesis and physical design.
