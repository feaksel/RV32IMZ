#===============================================================================
# PERFECT SOC Synthesis - Hierarchy Preservation Version
# Resolves: TUI-183 (Attribute Error) and CDFG-465 (Bus Mismatch)
#===============================================================================

set DESIGN "rv32im_soc_with_integrated_core" 
set LIB_PATH "../sky130_osu_sc_t18"
set MACRO_DIR "../pnr/outputs"

# 1. Setup Search Paths and Tool Behavior
set_db init_lib_search_path "$LIB_PATH/18T_ms/lib $LIB_PATH/18T_ms/lef"
# This tells the tool how to handle unconnected ports without erroring
set_db / .hdl_unconnected_value 0
set_db / .hdl_array_naming_style %s\[%d\]

# 2. Load Timing Libraries
puts "==> Loading libraries..."
read_libs "$LIB_PATH/18T_ms/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"

# 3. Read Macro STUBS (Direct Absolute Paths)
puts "==> Reading macro stubs..."
read_hdl -v2001 "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro_stub.v"
read_hdl -v2001 "${MACRO_DIR}/memory_macro/memory_macro_stub.v"
read_hdl -v2001 "${MACRO_DIR}/communication_macro/communication_macro_stub.v"
read_hdl -v2001 "${MACRO_DIR}/protection_macro/protection_macro_stub.v"
read_hdl -v2001 "${MACRO_DIR}/adc_subsystem_macro/adc_subsystem_macro_stub.v"
read_hdl -v2001 "${MACRO_DIR}/pwm_accelerator_macro/pwm_accelerator_macro_stub.v"

read_hdl -v2001 "hdl/soc_integrated/rv32im_soc_complete.v"

# 4. Elaborate
puts "==> Elaborating design..."
elaborate $DESIGN

# 5. PRESERVE INSTANCES (Prevents Flattening for "Nice" Layout)
# Forces Genus to treat these as distinct, untouchable blocks
set_db [get_db insts u_cpu_core] .preserve true
set_db [get_db insts u_cpu_core] .ungroup false

set_db [get_db insts u_memory] .preserve true
set_db [get_db insts u_memory] .ungroup false

# 6. Synthesize Interconnect (Glue Logic)
# Because we preserved the instances, only the bus wiring is synthesized
syn_generic
syn_map
syn_opt

# 7. Protect Mapped Top Design
set_db [get_db designs $DESIGN] .preserve true

# 8. Outputs
exec mkdir -p outputs/soc_integrated
write_hdl > outputs/soc_integrated/${DESIGN}.vh
write_sdc > outputs/soc_integrated/${DESIGN}.sdc

puts "==> SOC SYNTHESIS COMPLETE"
exit
