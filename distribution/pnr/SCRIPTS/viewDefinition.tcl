#============================================================
# Fixed View Definition File (MMMC)
#============================================================

# 1. Create Library Set
# Ensure this path matches your folder structure exactly
set lib_dir "../sky130_osu_sc_t18/18T_ms/lib"
set my_libs [glob -nocomplain $lib_dir/*.lib]

if {$my_libs == ""} {
    puts "ERROR: No .lib files found in $lib_dir"
    exit 1
}

create_library_set -name std_libs -timing $my_libs

# 2. Create RC Corner
# Using default cap table for now (Sky130 open PDK standard flow)
create_rc_corner -name default_rc_corner

# 3. Create Delay Corner
create_delay_corner -name default_delay_corner \
    -library_set std_libs \
    -rc_corner default_rc_corner

# 4. Create Constraint Mode
set SDC_FILE "../synth/outputs/rv32im_integrated/rv32im_integrated_macro.sdc"
if {![file exists $SDC_FILE]} {
    puts "ERROR: SDC file not found at $SDC_FILE"
}

create_constraint_mode -name default_constraints -sdc_files [list $SDC_FILE]

# 5. Create Analysis View
create_analysis_view -name default_view \
    -delay_corner default_delay_corner \
    -constraint_mode default_constraints

# 6. ACTIVATE THE VIEW (Critical Fix for IMPSYT-7327)
set_analysis_view -setup {default_view} -hold {default_view}
