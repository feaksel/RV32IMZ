# Firmware Initialization Guide for RV32IM SoC

## Overview

Your SoC has multiple ways to initialize firmware depending on the use case (simulation, FPGA, or ASIC). The memory macro uses SRAM blocks which need to be loaded with program code.

---

## Available Firmware Files

```
firmware/
├── bootloader.hex          (5,268 lines) - Main bootloader
├── firmware.hex            (small test)
└── examples/
    └── chb_test_simple.hex - Simple test program
```

**Hex File Format**: Each line = 32-bit instruction in hexadecimal

```
0000a117    # auipc x2, 0xa000
00010113    # addi x2, x2, 0x1
```

---

## Initialization Methods

### 1. **Simulation (RTL Pre-Synthesis)** ⭐ RECOMMENDED

Add `$readmemh` to the SRAM behavioral model to load firmware:

**Location**: `pdk/sky130A/libs.ref/sky130_sram_macros/sky130_sram_2kbyte_1rw1r_32x512_8.v`

```verilog
// Current initialization (zeros):
initial begin
    for (i = 0; i < 512; i = i + 1) begin
        memory[i] = 32'h0;
    end
end

// MODIFIED for firmware loading:
initial begin
    // Option A: Load specific hex file
    if ($test$plusargs("PRELOAD_ROM")) begin
        $readmemh("firmware/bootloader.hex", memory);
        $display("ROM initialized from bootloader.hex");
    end else begin
        // Initialize to zeros
        for (i = 0; i < 512; i = i + 1) begin
            memory[i] = 32'h0;
        end
    end
end
```

**Run simulation with preload**:

```bash
vvp build/tb_soc_complete.vvp +PRELOAD_ROM
```

---

### 2. **Testbench Direct Initialization** (For Quick Tests)

Load firmware directly in the testbench using hierarchical access:

**Location**: `sim/testbench/tb_macro_soc_complete.v`

```verilog
initial begin
    // Wait for reset
    @(posedge rst_n);
    @(posedge clk);

    // Load firmware into ROM banks (hierarchical path)
    $readmemh("../../firmware/bootloader.hex",
              dut.u_memory.rom_bank[0].sram_rom.memory);

    $display("Firmware loaded into ROM");
end
```

This directly accesses the SRAM memory array inside the macro.

---

### 3. **FPGA Synthesis** (Block RAM Initialization)

For FPGA deployment, use synthesis directives:

**Location**: `distribution/rv32im_core_only/macros/memory_macro/rtl/memory_macro.v`

```verilog
// Add initialization attributes for FPGA
generate
    for (i = 0; i < ROM_NUM_MACROS; i = i + 1) begin : rom_bank

        // For Xilinx: Use INIT_FILE attribute
        (* INIT_FILE = "bootloader.mem" *)
        sky130_sram_2kbyte_1rw1r_32x512_8 sram_rom (
            .clk0(clk),
            .csb0(!(rom_sel && (iwb_adr_i[14:11] == i[3:0]))),
            // ... rest of connections
        );
    end
endgenerate
```

Then convert hex to COE/MEM format:

```bash
python3 tools/hex2coe.py firmware/bootloader.hex > bootloader.coe
```

---

### 4. **ASIC Implementation** (External Flash/OTP)

For ASIC tape-out, firmware is typically NOT pre-loaded in ROM. Instead:

#### Option A: External Flash Boot

```
Power-On → Bootloader ROM (small, embedded) → Load from SPI Flash → Execute from RAM
```

- Small bootloader (~2KB) hardcoded in ROM using mask programming
- Main firmware stored in external Flash (SPI/QSPI)
- Bootloader copies firmware to RAM and jumps to it

#### Option B: One-Time Programmable (OTP) Memory

```
Foundry programs ROM during fab → Permanent firmware
```

- ROM programmed by foundry using special mask layers
- Firmware becomes part of the chip (cannot be changed)
- Requires GDS file with memory initialization data

#### Option C: Embedded Flash (eFlash)

```
Field-programmable non-volatile memory on-chip
```

- Some PDKs (not SKY130) have embedded Flash IP
- Can be programmed after fabrication
- Typical: 1-10 MB embedded Flash

---

## Practical Steps for Your SoC

### For Current Simulation Testing:

**Step 1**: Modify SRAM model to support preload

```bash
cd /home/furka/RV32IMZ
nano pdk/sky130A/libs.ref/sky130_sram_macros/sky130_sram_2kbyte_1rw1r_32x512_8.v
```

Add this after line 22:

```verilog
initial begin
    if ($test$plusargs("FIRMWARE")) begin
        $value$plusargs("FIRMWARE=%s", firmware_file);
        $readmemh(firmware_file, memory);
        $display("[SRAM] Loaded firmware from %s", firmware_file);
    end else begin
        for (i = 0; i < 512; i = i + 1) begin
            memory[i] = 32'h0;
        end
    end
end
```

**Step 2**: Run simulation with firmware

```bash
cd sim
vvp build/tb_soc_complete.vvp +FIRMWARE=../firmware/bootloader.hex
```

---

### For FPGA Deployment:

**Step 1**: Create COE file from hex

```bash
python3 firmware/bin2verilog.py firmware/bootloader.hex > bootloader.mem
```

**Step 2**: Add to XDC constraints

```tcl
set_property INIT_FILE bootloader.mem [get_cells u_memory/rom_bank[*]/sram_rom]
```

**Step 3**: Synthesize with Vivado

```bash
vivado -mode batch -source build_fpga.tcl
```

---

### For ASIC (SKY130):

**Option 1**: Use small embedded bootloader

- Put tiny bootloader (< 1KB) in ROM
- Load main firmware from external SPI Flash
- Example: `firmware/bootloader/bootloader.c` (currently 13KB, needs trimming)

**Option 2**: Mask-programmed ROM

- Convert firmware to GDS using memory compiler
- Foundry programs ROM during fabrication
- Requires special foundry service

**Option 3**: Use external memory only

- Keep internal ROM as boot stub only
- Execute directly from external QSPI Flash (XIP mode)
- Slower but flexible

---

## Memory Map Reference

```
Address Range         | Size  | Type | Purpose
---------------------|-------|------|---------------------------
0x0000_0000          |       |      | ROM/Flash
0x0000_7FFF          | 32 KB | ROM  | Firmware code
---------------------|-------|------|---------------------------
0x2000_0000          |       |      | RAM
0x2000_FFFF          | 64 KB | RAM  | Data/Stack/Heap
---------------------|-------|------|---------------------------
0x4000_0000          | 64 KB | REG  | PWM Accelerator
0x4001_0000          | 64 KB | REG  | ADC Subsystem
0x4002_0000          | 64 KB | REG  | Protection System
0x4003_0000          | 64 KB | REG  | Communication (UART/SPI/GPIO)
---------------------|-------|------|---------------------------
0x8000_0000+         | Ext   | Ext  | External memory (bootloader)
```

---

## Quick Start: Test With Bootloader

**Simplest approach** for simulation:

```bash
# 1. Create a simple test program
cat > sim/test_program.hex << 'EOF'
00000013  # nop
00100093  # addi x1, x0, 1
00200113  # addi x2, x0, 2
002081b3  # add x3, x1, x2
0000006f  # j 0 (loop forever)
EOF

# 2. Load it in testbench
# Edit sim/testbench/tb_macro_soc_complete.v, add after line 60:
initial begin
    #200;  // Wait for reset
    $readmemh("test_program.hex",
              dut.u_memory.rom_bank[0].sram_rom.memory);
    $display("Test program loaded");
end

# 3. Recompile and run
cd sim
make -f Makefile.hierarchical clean
make -f Makefile.hierarchical soc_test
```

---

## Summary

| Method                      | Use Case   | Complexity | Flexibility |
| --------------------------- | ---------- | ---------- | ----------- |
| `$readmemh` in SRAM model   | Simulation | Low        | High        |
| Testbench hierarchical load | Quick sim  | Very Low   | High        |
| FPGA INIT_FILE              | FPGA       | Medium     | Medium      |
| External Flash boot         | ASIC       | High       | Very High   |
| Mask-programmed ROM         | ASIC       | Very High  | None        |

**For your current testing**: Use testbench hierarchical load (Method 2) - simplest and fastest!

**For ASIC tape-out**: Use external Flash boot with small embedded bootloader (Method 4, Option A)

---

## Next Steps

1. ✅ Macros compile and integrate correctly
2. 📝 Add firmware loading to testbench
3. 🧪 Run comprehensive functional tests
4. 🔍 Verify peripheral operations
5. ⚡ Proceed to synthesis with loaded firmware

Your SoC architecture is solid - now it just needs code to execute! 🚀
