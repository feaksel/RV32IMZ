# Pin Placement for Memory Macro
# Assigns physical locations to I/O ports for predictable SoC integration

puts "INFO: Applying pin placement for memory_macro..."

#==============================================================================
# Clock and Reset - TOP edge (central location)
#==============================================================================

editPin -pin clk -edge TOP -layer met3 -spreadType center -start {50.0 0.0}
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {60.0 0.0}

#==============================================================================
# Wishbone Slave Interface - LEFT edge (receives from bus)
#==============================================================================

# Address and control inputs
editPin -pin wb_adr_i[*] -edge LEFT -layer met2 -spreadType spread
editPin -pin wb_dat_i[*] -edge LEFT -layer met2 -spreadType spread -start {80.0 0.0}
editPin -pin wb_we_i -edge LEFT -layer met3 -spreadType center -start {10.0 0.0}
editPin -pin wb_sel_i[*] -edge LEFT -layer met3 -spreadType spread -start {15.0 0.0}
editPin -pin wb_cyc_i -edge LEFT -layer met3 -spreadType center -start {25.0 0.0}
editPin -pin wb_stb_i -edge LEFT -layer met3 -spreadType center -start {30.0 0.0}

# Data and acknowledge outputs - RIGHT edge
editPin -pin wb_dat_o[*] -edge RIGHT -layer met2 -spreadType spread
editPin -pin wb_ack_o -edge RIGHT -layer met3 -spreadType center -start {10.0 0.0}

puts "INFO: Pin placement complete for memory_macro"
