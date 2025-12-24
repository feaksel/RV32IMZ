# 📐 SDC Constraints Template for Peripheral Macros

## ✅ Quick Setup

### For Each Peripheral Macro:

```bash
# 1. Create constraints directory
cd macros/memory_macro
mkdir -p constraints

# 2. Copy generic SDC template
cp /path/to/peripheral_generic.sdc constraints/memory_macro.sdc

# 3. (Optional) Customize clock period if needed
# Edit constraints/memory_macro.sdc, change line 13:
# create_clock -period 10.0 ...  # Adjust period as needed
```

**That's it!** The default values work for most peripherals.

---

## 🎯 Apply to All Peripherals

### Quick Script to Copy SDC to All Macros:

```bash
#!/bin/bash
# Copy generic SDC to all peripheral macros

MACROS=(
    "core_macro"
    "mdu_macro"
    "memory_macro"
    "communication_macro"
    "protection_macro"
    "adc_subsystem_macro"
    "pwm_accelerator_macro"
)

for macro in "${MACROS[@]}"; do
    echo "Setting up SDC for $macro..."
    mkdir -p macros/$macro/constraints
    cp peripheral_generic.sdc macros/$macro/constraints/${macro}.sdc
    echo "✓ Created constraints/${macro}.sdc"
done

echo ""
echo "✓ All SDC files created!"
```

---

## 🔧 Customization for Specific Macros

### Default Values (Good for All):
```tcl
Clock period:     10ns (100MHz)
Clock uncertainty: 0.5ns
Input delay:       2.0ns max, 1.0ns min
Output delay:      2.0ns max, 1.0ns min
```

### If You Need Different Clock Frequencies:

**For 50MHz:**
```tcl
create_clock -period 20.0 -name clk [get_ports clk]
set_clock_uncertainty 1.0 [get_clocks clk]
set_input_delay -clock clk -max 4.0 [all_inputs]
set_output_delay -clock clk -max 4.0 [all_outputs]
```

**For 200MHz:**
```tcl
create_clock -period 5.0 -name clk [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay -clock clk -max 1.0 [all_inputs]
set_output_delay -clock clk -max 1.0 [all_outputs]
```

---

## 📋 Per-Macro Notes

### **memory_macro** (with SRAM):
The generic SDC works fine. SRAM has internal timing.
```tcl
# No special changes needed
# SRAM constraints are internal to the SRAM macro
```

### **communication_macro** (UART, SPI, I2C):
Generic works fine. Adjust if you have specific I/O timing requirements.

### **protection_macro**:
Generic works perfectly.

### **adc_subsystem_macro**:
Generic works. Consider if ADC has multi-cycle paths.

### **pwm_accelerator_macro**:
Generic works. PWM output timing is usually not critical.

### **core_macro** / **mdu_macro**:
These are CPU components - might want tighter timing:
```tcl
create_clock -period 10.0 -name clk [get_ports clk]
set_clock_uncertainty 0.3 [get_clocks clk]  # Tighter
set_input_delay -clock clk -max 1.5 [all_inputs]  # Tighter
set_output_delay -clock clk -max 1.5 [all_outputs]
```

---

## 🚀 Using SDC in Your Build Flow

### In Synthesis Script:
```tcl
# After elaborate, before synthesis:
if {[file exists "constraints/memory_macro.sdc"]} {
    read_sdc constraints/memory_macro.sdc
} else {
    # Fallback: create basic constraints
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    remove_input_delay [get_ports clk]
}
```

### In P&R Script:
```tcl
# During init/setup:
if {[file exists "constraints/memory_macro.sdc"]} {
    read_sdc constraints/memory_macro.sdc
} elseif {[file exists "outputs/memory_macro.sdc"]} {
    read_sdc outputs/memory_macro.sdc  # From synthesis
}
```

---

## ✅ Verification

After applying constraints, check timing reports:

```bash
# Synthesis timing report
cat reports/timing.rpt

# P&R timing report
cat RPT/setup.rpt
cat RPT/hold.rpt

# Look for:
✓ No negative slack (timing met)
✓ WNS (Worst Negative Slack) >= 0
✓ TNS (Total Negative Slack) = 0
```

---

## 🎯 Summary

**One SDC template works for all peripherals!**

Just copy `peripheral_generic.sdc` to each macro's `constraints/` directory and rename it. The default 100MHz timing works for most designs.

Only customize if you need:
- Different clock frequency
- Special multi-cycle paths
- Asynchronous interfaces
- Very tight timing requirements

**For 95% of peripheral macros, the generic SDC works perfectly as-is!** ✅
