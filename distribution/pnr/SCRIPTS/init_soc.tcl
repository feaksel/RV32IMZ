#===============================================================================
# FINAL INIT SCRIPT (CORRECT SEQUENCING)
#===============================================================================
set DESIGN "rv32im_soc_with_integrated_core"

# --- 1. PATH DEFINITIONS (Absolute) ---
set LIB_ROOT "/home/Student3/Documents/Masaustu/FurkanEmir/sky130_cds/sky130_osu_sc_t18"
set MACRO_ROOT "../synth/outputs"

# --- 2. DEFINE GLOBALS FOR INIT ---
set init_verilog "${MACRO_ROOT}/soc_integrated/${DESIGN}.vh"
set init_top_cell "$DESIGN"
set init_pwr_net "vccd1"
set init_gnd_net "vssd1"

# Define LEF files
set init_lef_file [list \
    "${LIB_ROOT}/sky130_osu_sc_18T.tlef" \
    "${LIB_ROOT}/18T_ms/lef/sky130_osu_sc_18T_ms.lef" \
    "${MACRO_ROOT}/rv32im_integrated/rv32im_integrated_macro.lef" \
    "${MACRO_ROOT}/memory_macro/memory_macro.lef" \
    "${MACRO_ROOT}/communication_macro/communication_macro.lef" \
    "${MACRO_ROOT}/protection_macro/protection_macro.lef" \
    "${MACRO_ROOT}/adc_subsystem_macro/adc_subsystem_macro.lef" \
    "${MACRO_ROOT}/pwm_accelerator_macro/pwm_accelerator_macro.lef" \
]

# --- 3. DEFINE MMMC (TIMING) BEFORE INIT ---
# This is the critical fix. We create a viewDefinition file on the fly.
set view_file "viewDefinition.tcl"
set f [open $view_file w]
puts $f "create_library_set -name lib_tt -timing {${LIB_ROOT}/18T_ms/lib/sky130_osu_sc_18T_ms_tt_1P80_25C.ccs.lib}"
puts $f "create_rc_corner -name rc_typ -temperature 25"
puts $f "create_delay_corner -name corner_tt -library_set lib_tt -rc_corner rc_typ"
puts $f "create_constraint_mode -name mode_setup -sdc_files {${MACRO_ROOT}/soc_integrated/rv32im_soc_with_integrated_core.sdc}"
puts $f "create_analysis_view -name view_setup -constraint_mode mode_setup -delay_corner corner_tt"
puts $f "set_analysis_view -setup {view_setup} -hold {view_setup}"
close $f

# Tell Innovus to use this MMMC file
set init_mmmc_file $view_file

# --- 4. INITIALIZE DESIGN ---
# Now it has everything: Verilog, LEF, and Timing
init_design

# --- 5. FLOORPLAN ---
floorPlan -site 18T -s 2100.0 2100.0 70.0 70.0 70.0 70.0

# --- 6. MACRO PLACEMENT ---
placeInstance u_cpu_core 150.0 150.0 -fixed
placeInstance u_pwm 150.0 1250.0 -fixed
placeInstance u_adc 1032.0 1250.0 -fixed
placeInstance u_communication 1550.0 150.0 -fixed
placeInstance u_protection 1550.0 650.0 -fixed
placeInstance u_memory 1650.0 1250.0 -fixed

# --- 7. POWER RINGS ---
globalNetConnect vccd1 -type pgpin -pin vdd -inst *
globalNetConnect vssd1 -type pgpin -pin gnd -inst *
addRing -nets {vccd1 vssd1} -type core_rings -follow core -layer {top met1 bottom met1 left met2 right met2} -width 10.0 -spacing 2.0 -offset 5.0
sroute -connect {blockPin padPin padRing corePin floatingStripe} -layerChangeRange {met1 met5} -blockPinTarget nearestTarget

# --- 8. SAVE CLEAN STATE ---
exec mkdir -p DBS/soc_integrated
saveDesign DBS/soc_integrated/init.enc
exit
