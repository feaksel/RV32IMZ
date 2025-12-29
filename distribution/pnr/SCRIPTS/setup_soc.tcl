set DESIGN "rv32im_soc_with_integrated_core"
set LIB_PATH "../sky130_osu_sc_t18"
set MACRO_DIR "outputs"

set init_verilog "../synth/outputs/soc_integrated/${DESIGN}.vh"
set init_top_cell "$DESIGN"

set init_lef_file [list \
    "${LIB_PATH}/sky130_osu_sc_18T.tlef" \
    "${LIB_PATH}/18T_ms/lef/sky130_osu_sc_18T_ms.lef" \
    "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro.lef" \
    "${MACRO_DIR}/memory_macro/memory_macro.lef" \
    "${MACRO_DIR}/communication_macro/communication_macro.lef" \
    "${MACRO_DIR}/protection_macro/protection_macro.lef" \
    "${MACRO_DIR}/adc_subsystem_macro/adc_subsystem_macro.lef" \
    "${MACRO_DIR}/pwm_accelerator_macro/pwm_accelerator_macro.lef" \
]

set init_mmmc_file "SCRIPTS/viewDefinition_soc.tcl"
set init_pwr_net "vccd1"
set init_gnd_net "vssd1"
