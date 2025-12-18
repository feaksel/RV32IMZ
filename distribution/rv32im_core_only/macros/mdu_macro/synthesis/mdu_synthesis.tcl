# Genus TCL Script for MDU Macro Synthesis
# Based on the main core synthesis flow
# Optimized for SKY130 technology

puts "=========================================="
puts "Starting MDU Macro Synthesis"
puts "=========================================="

# Set design name
set DESIGN_NAME "mdu_macro"
set RTL_DIR "rtl"
set CONSTRAINT_DIR "constraints"
set OUTPUT_DIR "outputs"
set REPORT_DIR "reports"

# Library setup (assuming SKY130 is available)
# Load SKY130 standard cell libraries
set_db init_lib_search_path {../../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib}
set_db library sky130_fd_sc_hd__tt_025C_1v80.lib

# Set HDL search path
set_db init_hdl_search_path {${RTL_DIR}}

# Read RTL files
puts "Reading RTL files..."
read_hdl -verilog {
    riscv_defines.vh
    mdu.v
    mdu_macro.v
}

# Elaborate design
puts "Elaborating design..."
elaborate ${DESIGN_NAME}

# Check design
check_design

# Read constraints
puts "Reading constraints..."
read_sdc ${CONSTRAINT_DIR}/${DESIGN_NAME}.sdc

# Synthesize design
puts "Starting synthesis..."
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

# Run synthesis
syn_generic
syn_map
syn_opt

# Generate reports
puts "Generating reports..."
report_qor > ${REPORT_DIR}/qor.rpt
report_area > ${REPORT_DIR}/area.rpt
report_timing > ${REPORT_DIR}/timing.rpt
report_power > ${REPORT_DIR}/power.rpt
report_gates > ${REPORT_DIR}/gates.rpt

# Write outputs
puts "Writing outputs..."
write_hdl > ${OUTPUT_DIR}/${DESIGN_NAME}_netlist.v
write_sdc > ${OUTPUT_DIR}/${DESIGN_NAME}_constraints.sdc

# Write for P&R
write_design -innovus > ${OUTPUT_DIR}/${DESIGN_NAME}.g

puts "=========================================="
puts "MDU Macro synthesis completed successfully!"
puts "Check reports in ${REPORT_DIR}/"
puts "=========================================="