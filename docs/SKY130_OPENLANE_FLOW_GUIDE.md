# Guide: Synthesizing the RISC-V SoC with OpenLane and SKY130

**Date:** 2025-12-13
**Author:** Gemini AI

## 1. Overview

This guide provides a complete workflow for synthesizing the `soc_top` design, from Verilog RTL to a final GDSII layout, using the **OpenLane** automated flow with the open-source **SkyWater SKY130** Process Design Kit (PDK).

**What is OpenLane?**
OpenLane is an automated RTL-to-GDSII flow that uses a collection of open-source tools for each step of the ASIC design process:
- **Synthesis:** Yosys
- **Floorplanning & Placement:** OpenROAD
- **Clock Tree Synthesis:** OpenROAD
- **Routing:** OpenROAD
- **Static Timing Analysis (STA):** OpenSTA
- **Layout & Verification:** Magic, Netgen

This allows you to perform a complete synthesis and physical design flow on your own machine.

---

## 2. Prerequisites & Setup

### 2.1. Docker
The easiest and recommended way to install OpenLane and all its dependencies is with Docker. Make sure you have Docker installed and running on your system (WSL2 on Windows, Linux, or macOS).

### 2.2. OpenLane Installation
1.  **Clone the OpenLane repository:**
    ```bash
    git clone https://github.com/The-OpenROAD-Project/OpenLane.git
    cd OpenLane
    ```

2.  **Build the Docker Image:** This command sets up the environment and installs the PDKs. It will take a significant amount of time and download several gigabytes of data.
    ```bash
    make
    ```

3.  **Verify the Installation:** After the build completes, test the installation.
    ```bash
    make test
    ```
    This should run a test design and complete without errors.

For detailed installation instructions, refer to the [Official OpenLane Documentation](https://openlane.readthedocs.io/en/latest/getting_started/installation/index.html).

---

## 3. Project Integration with OpenLane

OpenLane expects a specific directory structure and a `config.json` file to define the design.

### 3.1. Create the OpenLane Project Directory

Inside the `OpenLane` directory you just cloned, create a new directory for our SoC design. OpenLane keeps its designs in `OpenLane/designs/`.

```bash
mkdir -p designs/riscv_soc
```

### 3.2. Copy/Link Verilog Source Files

OpenLane needs access to all the Verilog (`.v`) and header (`.vh`) files for the `soc_top` design. You can either copy them into `designs/riscv_soc/src/` or create symbolic links (recommended to keep a single source of truth).

From inside the `OpenLane/designs/riscv_soc/` directory, run the following (adjust paths if necessary):

```bash
# Create a source directory
mkdir src

# Link all the necessary RTL files from your project
ln -s /home/furka/5level-inverter/02-embedded/riscv/rtl/soc/soc_top.v src/
ln -s /home/furka/5level-inverter/02-embedded/riscv/rtl/core/custom_core_wrapper.v src/
ln -s /home/furka/5level-inverter/02-embedded/riscv/rtl/bus/wishbone_arbiter_2x1.v src/
ln -s /home/furka/5level-inverter/02-embedded/riscv/rtl/bus/wishbone_interconnect.v src/
ln -s /home/furka/5level-inverter/02-embedded/riscv/rtl/peripherals/*.v src/
# Note: You may need to link core files if they are not automatically found
# ln -s /home/furka/5level-inverter/02-embedded/riscv/rtl/core/*.v src/
```

### 3.3. Create the `config.json` File

This is the main control file for OpenLane. Create a new file named `config.json` inside the `OpenLane/designs/riscv_soc/` directory.

**`OpenLane/designs/riscv_soc/config.json`:**
```json
{
    "DESIGN_NAME": "soc_top",
    "VERILOG_FILES": [
        "dir::src/soc_top.v",
        "dir::src/custom_core_wrapper.v",
        "dir::src/wishbone_arbiter_2x1.v",
        "dir::src/wishbone_interconnect.v",
        "dir::src/uart.v",
        "dir::src/timer.v",
        "dir::src/protection.v",
        "dir::src/pwm_accelerator.v",
        "dir::src/sigma_delta_adc.v",
        "dir::src/gpio.v"
    ],
    "CLOCK_PORT": "clk",
    "CLOCK_PERIOD": 20,
    "CLOCK_NET": "clk",

    "FP_SIZING": "absolute",
    "DIE_AREA": "0 0 1800 1800",
    "FP_PIN_ORDER_CFG": "dir::pin_order.cfg",

    "PL_TARGET_DENSITY": 0.45,
    "FP_CORE_UTIL": 40,

    "MACROS": {
        "sky130_sram_2kbyte_1rw1r_32x512_8": {
            "gds": [
                "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/gds/sky130_sram_2kbyte_1rw1r.gds"
            ],
            "lef": [
                "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/lef/sky130_sram_2kbyte_1rw1r.lef"
            ],
            "lib": [
                "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/lib/sky130_sram_2kbyte_1rw1r_ss_1p65v_25c.lib"
            ],
            "verilog": [
                "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/verilog/sky130_sram_2kbyte_1rw1r.v"
            ],
            "instances": {
                "soc_top.ram_bank_*": {
                    "location": [0,0], "orientation": "N"
                },
                "soc_top.rom_bank_*": {
                    "location": [0,0], "orientation": "N"
                }
            }
        }
    },
    "USE_MACRO_PLACER": true,
    "MACRO_PLACEMENT_CFG": "dir::macro_placement.cfg",

    "VERILOG_FILES_BLACKBOX": [
        "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/verilog/sky130_sram_2kbyte_1rw1r.v"
    ],
    "EXTRA_LEFS": [
        "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/lef/sky130_sram_2kbyte_1rw1r.lef"
    ],
    "EXTRA_GDS_FILES": [
        "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/gds/sky130_sram_2kbyte_1rw1r.gds"
    ],
    "EXTRA_LIBS": [
        "dir::$PDK_ROOT/sky130A/libs.ref/sky130_sram_2kbyte_1rw1r/lib/sky130_sram_2kbyte_1rw1r_ss_1p65v_25c.lib"
    ]
}
```
*Note on `VERILOG_FILES`*: You may need to add more of the core's `.v` files if Yosys cannot find them automatically.

### 3.4. Create Pin Order and Macro Placement Files

For a design with macros, you need to provide guidance on pin placement and macro placement.

**`OpenLane/designs/riscv_soc/pin_order.cfg`:**
Create this file to define the order of pins on the die. You can start with a simple wildcard.
```
# A simple regex-based pin order file
# All inputs on the West, all outputs on the East
# In/outs on North/South
^clk.* W
^rst_n W
^uart_rx W
^fault_.* W
^estop_n W
^adc_comp_in.* W
^uart_tx E
^pwm_out.* E
^adc_dac_out.* E
^led.* E
^gpio.* N S
```

**`OpenLane/designs/riscv_soc/macro_placement.cfg`:**
This file helps the placer arrange the 48 SRAM macros.
```
# core_area: left_edge, bottom_edge, right_edge, top_edge
#soc_top.ram_bank_0.* 200 200 N
#soc_top.ram_bank_1.* 200 400 N
# ... and so on for all 48 macros
#
# For now, let the automatic macro placer handle it by leaving this file empty or minimal.
# You can refine this later to optimize placement.
```
For the first run, you can leave `macro_placement.cfg` empty and let the tool attempt to place them automatically.

---

## 4. Running the Synthesis Flow

With the setup complete, running the flow is simple.

1.  **Launch the OpenLane Docker Container:**
    From the `OpenLane/` directory, start the interactive session.
    ```bash
    make mount
    ```
    You will now be inside the Docker container's shell.

2.  **Run the Flow:**
    Execute the OpenLane flow script, pointing it to your design.
    ```tcl
    ./flow.tcl -design riscv_soc
    ```

This command will now execute all the steps from synthesis to final GDSII generation. It will take a considerable amount of time (30 minutes to several hours depending on your machine). You will see the tool output for each stage in the terminal.

---

## 5. Reviewing the Results

Once the flow completes, all the output files will be located in a timestamped directory inside `OpenLane/runs/`. For example: `OpenLane/runs/RUN_2025.12.13_14.30.00/`.

Inside that directory, you will find:
-   `results/final/gds/soc_top.gds`: **Your final GDSII layout file.**
-   `results/final/lef/soc_top.lef`: The final LEF file of your hardened design.
-   `results/final/verilog/soc_top.v`: The final gate-level netlist.
-   `reports/`: Contains detailed timing, area, and power reports from every stage.
-   `logs/`: Contains complete logs from every tool used in the flow.

You can view the final GDSII file using a layout viewer like **KLayout**, which is an excellent open-source tool.
```bash
klayout runs/RUN_.../results/final/gds/soc_top.gds
```

This completes the open-source RTL-to-GDSII flow for your RISC-V SoC.
