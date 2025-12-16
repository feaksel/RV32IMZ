# program_fpga.tcl
# Vivado TCL script for programming Basys3 FPGA with RV32IMZ SoC

# Connect to hardware
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# Get hardware device (should be XC7A35T)
set device [get_hw_devices xc7a35t_0]
if {[llength $device] == 0} {
    puts "ERROR: No Basys3 device found!"
    puts "Check USB connection and power"
    exit 1
}

current_hw_device $device
refresh_hw_device -update_hw_probes false $device

# Program with bitstream
set bitstream_file "vivado_project/rv32imz_soc.runs/impl_1/soc_simple.bit"

if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream file not found: $bitstream_file"
    puts "Run implementation first!"
    exit 1
}

puts "Programming FPGA with $bitstream_file"
set_property PROGRAM.FILE $bitstream_file $device
set_property FULL_PROBES.FILE {} $device
set_property PROBES.FILE {} $device

program_hw_devices $device
refresh_hw_device $device

puts "Programming completed successfully!"
puts ""
puts "Next steps:"
puts "1. Connect USB-UART adapter to Pmod JC"
puts "2. Open terminal: screen /dev/ttyUSB0 115200"
puts "3. Press reset button to see bootloader"
puts "4. Press 'U' within 3 seconds for update mode"

# Close hardware manager
close_hw_manager