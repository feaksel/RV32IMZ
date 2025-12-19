# Pin Placement for PWM Accelerator Macro
# Assigns physical locations to I/O ports for predictable SoC integration

puts "INFO: Applying pin placement for pwm_accelerator_macro..."

#==============================================================================
# Clock and Reset - TOP edge (central location)
#==============================================================================

editPin -pin clk -edge TOP -layer met3 -spreadType center -start {20.0 0.0}
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {25.0 0.0}

#==============================================================================
# Wishbone Slave Interface - LEFT edge (receives from bus)
#==============================================================================

editPin -pin wb_adr_i[*] -edge LEFT -layer met2 -spreadType spread
editPin -pin wb_dat_i[*] -edge LEFT -layer met2 -spreadType spread -start {30.0 0.0}
editPin -pin wb_we_i -edge LEFT -layer met3 -spreadType center -start {5.0 0.0}
editPin -pin wb_sel_i[*] -edge LEFT -layer met3 -spreadType spread -start {10.0 0.0}
editPin -pin wb_cyc_i -edge LEFT -layer met3 -spreadType center -start {15.0 0.0}
editPin -pin wb_stb_i -edge LEFT -layer met3 -spreadType center -start {18.0 0.0}

editPin -pin wb_dat_o[*] -edge RIGHT -layer met2 -spreadType spread
editPin -pin wb_ack_o -edge RIGHT -layer met3 -spreadType center -start {5.0 0.0}

#==============================================================================
# PWM Outputs - BOTTOM edge (to external pads)
#==============================================================================

editPin -pin pwm_out[0] -edge BOTTOM -layer met3 -spreadType center -start {10.0 0.0}
editPin -pin pwm_out[1] -edge BOTTOM -layer met3 -spreadType center -start {20.0 0.0}
editPin -pin pwm_out[2] -edge BOTTOM -layer met3 -spreadType center -start {30.0 0.0}
editPin -pin pwm_out[3] -edge BOTTOM -layer met3 -spreadType center -start {40.0 0.0}

puts "INFO: Pin placement complete for pwm_accelerator_macro"
