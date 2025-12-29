#============================================================
# Updated Setup Script
#============================================================
set DESIGN "rv32im_integrated_macro"
set LIB_PATH "../sky130_osu_sc_t18"

# 1. Global Init Variables (Use 'set', NOT 'set_db' here)
set init_verilog "../synth/outputs/rv32im_integrated/${DESIGN}.vh"
set init_top_cell "$DESIGN"

# 2. LEF Files (Tech LEF MUST be first)
set init_lef_file [list \
    ${LIB_PATH}/sky130_osu_sc_18T.tlef \
    ${LIB_PATH}/18T_ms/lef/sky130_osu_sc_18T_ms.lef \
    ../pnr/outputs/core_macro/core_macro.lef \
    ../pnr/outputs/mdu_macro/mdu_macro.lef \
]

# 3. MMMC Link (Fixes the 'physical-only' error)
set init_mmmc_file "SCRIPTS/viewDefinition.tcl"

# 4. Power/Ground
set init_pwr_net "vccd1"
set init_gnd_net "vssd1"

puts "==> Setup variables configured with MMMC View"
