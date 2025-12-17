#===============================================================================
# Multi-Mode Multi-Corner Analysis Configuration
# For RV32IM Core with Sky130 PDK
# Research-Based MMMC Setup (avoids read_libs conflicts)
#===============================================================================

set TECH_LIB_PATH "../pdk/sky130A/libs.ref"
set SRAM_LIB_PATH "$TECH_LIB_PATH/sky130_sram_macros"

# ============================================================================
# AUTOMATIC PDK-AWARE MMMC SETUP
# ============================================================================

proc setup_mmmc_for_pdk {lib_path} {
    puts "🔧 Setting up MMMC for current PDK configuration..."
    
    # Discover available libraries
    set available_libs [glob -nocomplain "${lib_path}/sky130_fd_sc_hd/lib/*.lib"]
    set num_libs [llength $available_libs]
    
    puts "📚 Found $num_libs library files"
    foreach lib $available_libs {
        puts "  - [file tail $lib] ([expr [file size $lib]/1024]KB)"
    }
    
    if {$num_libs == 0} {
        error "❌ No liberty files found in $lib_path"
    }
    
    # Categorize libraries by operating conditions
    set tt_lib ""
    set ss_lib ""  
    set ff_lib ""
    
    foreach lib $available_libs {
        set filename [file tail $lib]
        if {[string match "*tt_025C_1v80*" $filename]} {
            set tt_lib $lib
        } elseif {[string match "*ss_*" $filename]} {
            set ss_lib $lib
        } elseif {[string match "*ff_*" $filename]} {
            set ff_lib $lib
        }
    }
    
    # Determine MMMC strategy based on available libraries
    if {$tt_lib != "" && $ss_lib != "" && $ff_lib != ""} {
        puts "🚀 Multi-corner MMMC (Enhanced PDK)"
        setup_multicorner_mmmc $tt_lib $ss_lib $ff_lib
    } elseif {$tt_lib != "" && $ss_lib != ""} {
        puts "⚡ Dual-corner MMMC (Basic CTS PDK)"
        setup_dualcorner_mmmc $tt_lib $ss_lib
    } else {
        puts "📦 Single-corner MMMC (Minimal PDK)"
        set single_lib [expr {$tt_lib != "" ? $tt_lib : [lindex $available_libs 0]}]
        setup_singlecorner_mmmc $single_lib
    }
}

proc setup_multicorner_mmmc {tt_lib ss_lib ff_lib} {
    puts "Setting up 3-corner MMMC..."
    
    # Library sets
    create_library_set -name TT_LIB -timing [list $tt_lib]
    create_library_set -name SS_LIB -timing [list $ss_lib] 
    create_library_set -name FF_LIB -timing [list $ff_lib]
    
    # Delay corners
    create_delay_corner -name TT_CORNER -library_set TT_LIB
    create_delay_corner -name SS_CORNER -library_set SS_LIB
    create_delay_corner -name FF_CORNER -library_set FF_LIB
    
    # Constraint mode
    if {[file exists "../constraints/basic_timing.sdc"]} {
        create_constraint_mode -name FUNC_MODE -sdc_files [list ../constraints/basic_timing.sdc]
    } else {
        create_constraint_mode -name FUNC_MODE
        puts "⚠️  Warning: No SDC file found, using default constraints"
    }
    
    # Analysis views
    create_analysis_view -name TT_VIEW -constraint_mode FUNC_MODE -delay_corner TT_CORNER
    create_analysis_view -name SS_VIEW -constraint_mode FUNC_MODE -delay_corner SS_CORNER
    create_analysis_view -name FF_VIEW -constraint_mode FUNC_MODE -delay_corner FF_CORNER
    
    # Setup: SS (worst setup), Hold: FF (worst hold)
    set_analysis_view -setup {SS_VIEW} -hold {FF_VIEW}
    puts "✅ 3-corner MMMC setup complete"
}

proc setup_dualcorner_mmmc {tt_lib ss_lib} {
    puts "Setting up 2-corner MMMC..."
    
    # Library sets
    create_library_set -name TT_LIB -timing [list $tt_lib]
    create_library_set -name SS_LIB -timing [list $ss_lib]
    
    # Delay corners
    create_delay_corner -name TT_CORNER -library_set TT_LIB
    create_delay_corner -name SS_CORNER -library_set SS_LIB
    
    # Constraint mode
    if {[file exists "../constraints/basic_timing.sdc"]} {
        create_constraint_mode -name FUNC_MODE -sdc_files [list ../constraints/basic_timing.sdc]
    } else {
        create_constraint_mode -name FUNC_MODE
    }
    
    # Analysis views
    create_analysis_view -name TT_VIEW -constraint_mode FUNC_MODE -delay_corner TT_CORNER
    create_analysis_view -name SS_VIEW -constraint_mode FUNC_MODE -delay_corner SS_CORNER
    
    # Setup: SS (worst), Hold: TT (typical)
    set_analysis_view -setup {SS_VIEW} -hold {TT_VIEW}
    puts "✅ 2-corner MMMC setup complete"
}

proc setup_singlecorner_mmmc {lib_file} {
    puts "Setting up 1-corner MMMC..."
    
    # Single library set
    create_library_set -name SINGLE_LIB -timing [list $lib_file]
    
    # Single delay corner
    create_delay_corner -name SINGLE_CORNER -library_set SINGLE_LIB
    
    # Constraint mode
    if {[file exists "../constraints/basic_timing.sdc"]} {
        create_constraint_mode -name FUNC_MODE -sdc_files [list ../constraints/basic_timing.sdc]
    } else {
        create_constraint_mode -name FUNC_MODE
    }
    
    # Single analysis view
    create_analysis_view -name SINGLE_VIEW -constraint_mode FUNC_MODE -delay_corner SINGLE_CORNER
    
    # Use same for both setup and hold
    set_analysis_view -setup {SINGLE_VIEW} -hold {SINGLE_VIEW}
    puts "✅ 1-corner MMMC setup complete"
}

# Execute the PDK-aware MMMC setup
if {[catch {setup_mmmc_for_pdk $TECH_LIB_PATH} err]} {
    puts "❌ MMMC setup failed: $err"
    puts "🆘 Falling back to simple single-corner setup..."
    
    # Emergency fallback
    create_library_set -name FALLBACK_LIB -timing [list $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib]
    create_delay_corner -name FALLBACK_CORNER -library_set FALLBACK_LIB
    create_constraint_mode -name FUNC_MODE
    create_analysis_view -name FALLBACK_VIEW -constraint_mode FUNC_MODE -delay_corner FALLBACK_CORNER
    set_analysis_view -setup {FALLBACK_VIEW} -hold {FALLBACK_VIEW}
    puts "✅ Fallback MMMC setup complete"
}

puts "MMMC setup complete:"
puts "  Setup analysis: SS_VIEW, TT_VIEW"
puts "  Hold analysis:  FF_VIEW, TT_VIEW"
