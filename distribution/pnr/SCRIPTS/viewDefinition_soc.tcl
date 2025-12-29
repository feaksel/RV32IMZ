set lib_dir "../sky130_osu_sc_t18/18T_ms/lib"
set SDC_FILE "../synth/outputs/soc_integrated/rv32im_soc_with_integrated_core.sdc"

set my_libs [glob -nocomplain $lib_dir/*.lib]
create_library_set -name libs_tt -timing $my_libs
create_rc_corner -name rc_typ
create_delay_corner -name corner_tt -library_set libs_tt -rc_corner rc_typ

if {[file exists $SDC_FILE]} {
    create_constraint_mode -name setup_mode -sdc_files [list $SDC_FILE]
} else {
    puts "FATAL ERROR: SOC SDC NOT FOUND"
    exit 1
}

create_analysis_view -name setup_func -delay_corner corner_tt -constraint_mode setup_mode
create_analysis_view -name hold_func  -delay_corner corner_tt -constraint_mode setup_mode
set_analysis_view -setup {setup_func} -hold {hold_func}
