#===============================================================================
# Cadence Genus Synthesis Script
# For: Custom RISC-V Core (RV32IM)
# Target: School technology library
#===============================================================================

# Paths relative to synthesis/cadence/ directory
set TECH_LIB_PATH "../pdk/sky130A/libs.ref"
set RTL_PATH "../rtl"
set SRAM_LIB_PATH "$TECH_LIB_PATH/sky130_sram_macros"

#===============================================================================
# Setup
#===============================================================================

# Set search paths
set_db init_lib_search_path $TECH_LIB_PATH
set_db init_hdl_search_path $RTL_PATH

# ============================================================================
# LIBRARY READING - BULLETPROOF CADENCE GENUS LIBRARY LOADING
# Based on research of Cadence best practices and academic PDK limitations
# ============================================================================

puts "==> Setting up library loading..."

# Environment and debug setup
set_db information_level 7
set_db hdl_max_loop_limit 10000
set_db library_setup_isj_for_simple_flops true

# Detect PDK configuration automatically
proc detect_pdk_configuration {} {
    # Check which config files exist and their sizes
    set configs [glob -nocomplain config_*.tcl]
    set active_pdk "minimal"  # default
    
    if {[file exists "../pdk/sky130A"]} {
        # Check library file sizes to determine PDK type
        set lib_files [glob -nocomplain "../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/*.lib"]
        if {[llength $lib_files] > 0} {
            set lib_size [file size [lindex $lib_files 0]]
            if {$lib_size > 15000} {
                set active_pdk "enhanced"
            } elseif {$lib_size > 10000} {
                set active_pdk "basic_cts"  
            }
        }
    }
    return $active_pdk
}

set pdk_config [detect_pdk_configuration]
puts "==> Auto-detected PDK: $pdk_config"

# Robust library loading with multiple fallback methods
proc load_libraries_safe {pdk_type} {
    global TECH_LIB_PATH SRAM_LIB_PATH
    
    # Define library files based on PDK type
    set lib_path "$TECH_LIB_PATH/sky130_fd_sc_hd/lib"
    set primary_libs {}
    set fallback_libs {}
    
    # Check what's actually available
    set available_libs [glob -nocomplain "${lib_path}/*.lib"]
    puts "==> Available libraries: [llength $available_libs] files"
    
    foreach lib $available_libs {
        puts "  - [file tail $lib] ([expr [file size $lib]/1024]KB)"
    }
    
    if {[llength $available_libs] == 0} {
        puts "ERROR: ERROR: No liberty files found in $lib_path"
        return -1
    }
    
    # Build library list based on PDK configuration
    switch $pdk_type {
        "enhanced" {
            # Try multi-corner for enhanced PDK
            set typical_lib [lsearch -inline $available_libs "*tt_025C_1v80.lib"]
            set slow_lib [lsearch -inline $available_libs "*ss_100C_1v60.lib"] 
            set fast_lib [lsearch -inline $available_libs "*ff_n40C_1v95.lib"]
            
            if {$typical_lib != "" && $slow_lib != "" && $fast_lib != ""} {
                set primary_libs [list $typical_lib $slow_lib $fast_lib]
            } else {
                set primary_libs $available_libs
            }
            set fallback_libs [lindex $available_libs 0]
        }
        "basic_cts" {
            # Try dual-corner for CTS
            set typical_lib [lsearch -inline $available_libs "*tt_025C_1v80.lib"]
            set slow_lib [lsearch -inline $available_libs "*ss_100C_1v60.lib"]
            
            if {$typical_lib != "" && $slow_lib != ""} {
                set primary_libs [list $typical_lib $slow_lib]
            } else {
                set primary_libs $available_libs
            }
            set fallback_libs [lindex $available_libs 0]
        }
        default {
            # Minimal: single corner
            set primary_libs [lindex $available_libs 0]
            set fallback_libs $primary_libs
        }
    }
    
    puts "==> Attempting to load: [llength $primary_libs] libraries"
    
    # METHOD 1: Modern read_libs (RECOMMENDED)
    if {[catch {
        puts "==> Method 1: Modern read_libs approach"
        read_libs -liberty $primary_libs
        puts "SUCCESS: SUCCESS: read_libs method worked"
        return 0
    } err]} {
        puts "WARNING:  Method 1 failed: $err"
    }
    
    # METHOD 2: Sequential library loading
    if {[catch {
        puts "==> Method 2: Sequential loading"
        reset_db -library
        set first_lib true
        foreach lib $primary_libs {
            if {$first_lib} {
                read_libs -liberty $lib
                set first_lib false
            } else {
                read_libs -liberty $lib -add
            }
        }
        puts "SUCCESS: SUCCESS: Sequential method worked"
        return 0
    } err]} {
        puts "WARNING:  Method 2 failed: $err"
    }
    
    # METHOD 3: Database attribute setting  
    if {[catch {
        puts "==> Method 3: Database attribute method"
        reset_db -library
        set_db library $primary_libs
        puts "SUCCESS: SUCCESS: Database attribute method worked"
        return 0
    } err]} {
        puts "WARNING:  Method 3 failed: $err"
    }
    
    # METHOD 4: Legacy read_lib approach
    if {[catch {
        puts "==> Method 4: Legacy read_lib approach"
        reset_db -library
        foreach lib $primary_libs {
            read_lib -liberty $lib
        }
        puts "SUCCESS: SUCCESS: Legacy method worked"
        return 0
    } err]} {
        puts "WARNING:  Method 4 failed: $err"
    }
    
    # FALLBACK: Single library minimal mode
    if {[catch {
        puts "CRITICAL: FALLBACK: Single library mode"
        reset_db -library
        read_libs -liberty $fallback_libs
        puts "SUCCESS: FALLBACK SUCCESS: Using minimal library set"
        return 1
    } err]} {
        puts "ERROR: CRITICAL: All library loading methods failed: $err"
        return -1
    }
}

# Attempt library loading
set lib_result [load_libraries_safe $pdk_config]
if {$lib_result == -1} {
    puts "FATAL: FATAL: Cannot load any libraries"
    exit 1
} elseif {$lib_result == 1} {
    puts "WARNING:  WARNING: Using fallback single-library mode"
    set pdk_config "minimal"  # force minimal mode
}

# Configure synthesis based on successful library loading
switch $pdk_config {
    "enhanced" {
        puts "==> Enhanced PDK mode: Multi-corner optimization enabled"
        set_db library_setup_apply_slow_timing_libs_to_optimize true
        set_db library_setup_apply_fast_timing_libs_to_optimize true
        set_db syn_generic_effort high
        set_db syn_map_effort high
        set_db syn_opt_effort high
    }
    "basic_cts" {
        puts "==> Basic CTS PDK mode: Dual-corner with CTS support"  
        set_db syn_generic_effort medium
        set_db syn_map_effort high
        set_db syn_opt_effort medium
    }
    default {
        puts "==> Minimal PDK mode: Single-corner fast synthesis"
        set_db syn_generic_effort low
        set_db syn_map_effort medium
        set_db syn_opt_effort low
    }
}

# Validate library loading
if {[catch {get_db [get_libs] .name} lib_list]} {
    puts "ERROR: ERROR: No libraries loaded successfully"
    exit 1
} else {
    puts "SUCCESS: Library validation passed"
    foreach lib $lib_list {
        puts "  ==> Loaded: $lib"
    }
}



#===============================================================================
# Read RTL
#===============================================================================

puts "Reading RTL files..."

# Read SRAM macro models first
read_hdl -v2001 $SRAM_LIB_PATH/sky130_sram_2kbyte_1rw1r_32x512_8.v

# Read complete core design (core only)
read_hdl -v2001 {
    ../rtl/riscv_defines.vh
    ../rtl/alu.v
    ../rtl/regfile.v  
    ../rtl/decoder.v
    ../rtl/mdu.v
    ../rtl/csr_unit.v
    ../rtl/exception_unit.v
    ../rtl/interrupt_controller.v
    ../rtl/custom_riscv_core.v
}

# Or read the top level which includes others
# read_hdl -sv custom_core_wrapper.v

#===============================================================================
# Elaborate Design
#===============================================================================

puts "Elaborating design..."
elaborate custom_riscv_core

# Check design
check_design -unresolved

#===============================================================================
# Constraints
#===============================================================================

puts "Applying constraints..."

# Read timing constraints from the constraint file
read_sdc ../constraints/basic_timing.sdc

#===============================================================================
# Synthesis Settings
#===============================================================================

puts "Setting synthesis options..."

# Effort levels (high for best results)
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high





#===============================================================================
# Synthesize
#===============================================================================

puts "Running generic synthesis..."
syn_generic

puts "Running mapping..."
syn_map

puts "Running optimization..."
syn_opt

#===============================================================================
# Reports
#===============================================================================

puts "Generating reports..."

# Create reports directory
exec mkdir -p reports

# Area report
report_area > reports/area.rpt
report_gates > reports/gates.rpt

# Timing report
report_timing -nworst 10 > reports/timing.rpt
report_timing -nworst 10 -path_type full > reports/timing_full.rpt

# Power report
report_power > reports/power.rpt

# QoR summary
report_qor > reports/qor.rpt

# Design hierarchy
report_hierarchy > reports/hierarchy.rpt

# Clock report
report_clocks > reports/clock.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "Writing outputs..."

# Create outputs directory
exec mkdir -p outputs

# Write gate-level netlist
write_hdl > outputs/core_netlist.v

# Write SDC constraints for P&R
write_sdc > outputs/core_constraints.sdc

# Write design database for Innovus
write_design -innovus -base_name outputs/core_design

# Write SDF (for timing simulation)
# write_sdf > outputs/timing.sdf

#===============================================================================
# Summary
#===============================================================================

puts "\n========================================="
puts "Synthesis Complete!"
puts "========================================="
puts ""
puts "Check the following:"
puts "  reports/area.rpt     - Area breakdown"
puts "  reports/timing.rpt   - Timing analysis"
puts "  reports/power.rpt    - Power analysis"
puts "  reports/qor.rpt      - Quality summary"
puts ""
puts "Output files:"
puts "  outputs/netlist.v    - Gate-level netlist"
puts "  outputs/constraints.sdc - Timing constraints"
puts "  outputs/design/      - Design database for Innovus"
puts ""

# Print summary statistics
#report_summary

puts "\nIf timing doesn't meet:"
puts "  1. Check critical path in reports/timing.rpt"
puts "  2. Try reducing clock frequency in this script"
puts "  3. Check for combinational loops"
puts "  4. Consider pipelining critical paths"
puts ""
puts "Next step: Place & Route with Innovus"
puts "  Run: innovus -init place_route.tcl"
puts "========================================="

    
