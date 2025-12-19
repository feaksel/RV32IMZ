# Pin Placement for MDU Macro
# Assigns physical locations to I/O ports for predictable integration with core

puts "INFO: Applying pin placement for mdu_macro..."

#==============================================================================
# Clock and Reset - TOP edge (central location)
#==============================================================================

editPin -pin clk -edge TOP -layer met3 -spreadType center -start {20.0 0.0}
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {25.0 0.0}

#==============================================================================
# Control Interface - LEFT edge (from core)
#==============================================================================

editPin -pin start -edge LEFT -layer met3 -spreadType center -start {10.0 0.0}
editPin -pin ack -edge LEFT -layer met3 -spreadType center -start {15.0 0.0}
editPin -pin funct3[*] -edge LEFT -layer met3 -spreadType spread -start {20.0 0.0}

#==============================================================================
# Data Inputs - BOTTOM edge
#==============================================================================

editPin -pin rs1[*] -edge BOTTOM -layer met2 -spreadType spread -start {10.0 0.0}
editPin -pin rs2[*] -edge BOTTOM -layer met2 -spreadType spread -start {80.0 0.0}

#==============================================================================
# Data Output - RIGHT edge
#==============================================================================

editPin -pin product[*] -edge RIGHT -layer met2 -spreadType spread

#==============================================================================
# Power and Ground - Ring structure (handled by P&R)
#==============================================================================

puts "INFO: Pin placement for mdu_macro complete"
puts "INFO: Power/ground will be handled by ring and stripe creation in P&R"
