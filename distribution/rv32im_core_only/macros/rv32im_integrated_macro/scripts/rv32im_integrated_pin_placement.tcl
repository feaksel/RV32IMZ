# Pin Placement for Core Macro
# Assigns physical locations to I/O ports for predictable SoC integration

puts "INFO: Applying pin placement for core_macro..."

#==============================================================================
# Clock and Reset - TOP edge (central location)
#==============================================================================

editPin -pin clk -edge TOP -layer met3 -spreadType center -start {50.0 0.0}
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {60.0 0.0}

#==============================================================================
# Instruction Wishbone Bus - LEFT edge
#==============================================================================

# Address and control signals on LEFT
editPin -pin iwb_adr_o[*] -edge LEFT -layer met2 -spreadType spread
editPin -pin iwb_cyc_o -edge LEFT -layer met3 -spreadType center -start {10.0 0.0}
editPin -pin iwb_stb_o -edge LEFT -layer met3 -spreadType center -start {15.0 0.0}

# Instruction data input on RIGHT (from memory)
editPin -pin iwb_dat_i[*] -edge RIGHT -layer met2 -spreadType spread
editPin -pin iwb_ack_i -edge RIGHT -layer met3 -spreadType center -start {10.0 0.0}

#==============================================================================
# Data Wishbone Bus - BOTTOM edge (bidirectional)
#==============================================================================

# Data outputs (address, write data, control) on BOTTOM
editPin -pin dwb_adr_o[*] -edge BOTTOM -layer met2 -spreadType spread -start {10.0 0.0}
editPin -pin dwb_dat_o[*] -edge BOTTOM -layer met2 -spreadType spread -start {80.0 0.0}
editPin -pin dwb_we_o -edge BOTTOM -layer met3 -spreadType center -start {150.0 0.0}
editPin -pin dwb_sel_o[*] -edge BOTTOM -layer met3 -spreadType spread -start {155.0 0.0}
editPin -pin dwb_cyc_o -edge BOTTOM -layer met3 -spreadType center -start {165.0 0.0}
editPin -pin dwb_stb_o -edge BOTTOM -layer met3 -spreadType center -start {170.0 0.0}

# Data inputs (read data, ack, err) on TOP (from memory/peripherals)
editPin -pin dwb_dat_i[*] -edge TOP -layer met2 -spreadType spread -start {80.0 0.0}
editPin -pin dwb_ack_i -edge TOP -layer met3 -spreadType center -start {150.0 0.0}
editPin -pin dwb_err_i -edge TOP -layer met3 -spreadType center -start {155.0 0.0}

#==============================================================================
# MDU Interface - RIGHT edge (connects to external MDU macro)
#==============================================================================

# Control signals to MDU
editPin -pin mdu_start -edge RIGHT -layer met3 -spreadType center -start {30.0 0.0}
editPin -pin mdu_ack -edge RIGHT -layer met3 -spreadType center -start {35.0 0.0}
editPin -pin mdu_funct3[*] -edge RIGHT -layer met3 -spreadType spread -start {40.0 0.0}

# Operands to MDU
editPin -pin mdu_operand_a[*] -edge RIGHT -layer met2 -spreadType spread -start {50.0 0.0}
editPin -pin mdu_operand_b[*] -edge RIGHT -layer met2 -spreadType spread -start {90.0 0.0}

# Results from MDU (inputs to core)
editPin -pin mdu_busy -edge RIGHT -layer met3 -spreadType center -start {130.0 0.0}
editPin -pin mdu_done -edge RIGHT -layer met3 -spreadType center -start {135.0 0.0}
editPin -pin mdu_product[*] -edge RIGHT -layer met1 -spreadType spread -start {20.0 0.0}
editPin -pin mdu_quotient[*] -edge RIGHT -layer met1 -spreadType spread -start {80.0 0.0}
editPin -pin mdu_remainder[*] -edge RIGHT -layer met1 -spreadType spread -start {110.0 0.0}

#==============================================================================
# Interrupts - TOP edge (from peripherals)
#==============================================================================

editPin -pin interrupts[*] -edge TOP -layer met2 -spreadType spread -start {10.0 0.0}

puts "INFO: Pin placement complete for core_macro"
