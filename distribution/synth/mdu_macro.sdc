# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.18-s082_1 on Wed Dec 24 09:39:55 +03 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design mdu_macro

create_clock -name "clk" -period 10.0 -waveform {0.0 5.0} [get_ports clk]
set_clock_transition 0.1 [get_clocks clk]
set_load -pin_load 0.1 [get_ports busy]
set_load -pin_load 0.1 [get_ports done]
set_load -pin_load 0.1 [get_ports {product[63]}]
set_load -pin_load 0.1 [get_ports {product[62]}]
set_load -pin_load 0.1 [get_ports {product[61]}]
set_load -pin_load 0.1 [get_ports {product[60]}]
set_load -pin_load 0.1 [get_ports {product[59]}]
set_load -pin_load 0.1 [get_ports {product[58]}]
set_load -pin_load 0.1 [get_ports {product[57]}]
set_load -pin_load 0.1 [get_ports {product[56]}]
set_load -pin_load 0.1 [get_ports {product[55]}]
set_load -pin_load 0.1 [get_ports {product[54]}]
set_load -pin_load 0.1 [get_ports {product[53]}]
set_load -pin_load 0.1 [get_ports {product[52]}]
set_load -pin_load 0.1 [get_ports {product[51]}]
set_load -pin_load 0.1 [get_ports {product[50]}]
set_load -pin_load 0.1 [get_ports {product[49]}]
set_load -pin_load 0.1 [get_ports {product[48]}]
set_load -pin_load 0.1 [get_ports {product[47]}]
set_load -pin_load 0.1 [get_ports {product[46]}]
set_load -pin_load 0.1 [get_ports {product[45]}]
set_load -pin_load 0.1 [get_ports {product[44]}]
set_load -pin_load 0.1 [get_ports {product[43]}]
set_load -pin_load 0.1 [get_ports {product[42]}]
set_load -pin_load 0.1 [get_ports {product[41]}]
set_load -pin_load 0.1 [get_ports {product[40]}]
set_load -pin_load 0.1 [get_ports {product[39]}]
set_load -pin_load 0.1 [get_ports {product[38]}]
set_load -pin_load 0.1 [get_ports {product[37]}]
set_load -pin_load 0.1 [get_ports {product[36]}]
set_load -pin_load 0.1 [get_ports {product[35]}]
set_load -pin_load 0.1 [get_ports {product[34]}]
set_load -pin_load 0.1 [get_ports {product[33]}]
set_load -pin_load 0.1 [get_ports {product[32]}]
set_load -pin_load 0.1 [get_ports {product[31]}]
set_load -pin_load 0.1 [get_ports {product[30]}]
set_load -pin_load 0.1 [get_ports {product[29]}]
set_load -pin_load 0.1 [get_ports {product[28]}]
set_load -pin_load 0.1 [get_ports {product[27]}]
set_load -pin_load 0.1 [get_ports {product[26]}]
set_load -pin_load 0.1 [get_ports {product[25]}]
set_load -pin_load 0.1 [get_ports {product[24]}]
set_load -pin_load 0.1 [get_ports {product[23]}]
set_load -pin_load 0.1 [get_ports {product[22]}]
set_load -pin_load 0.1 [get_ports {product[21]}]
set_load -pin_load 0.1 [get_ports {product[20]}]
set_load -pin_load 0.1 [get_ports {product[19]}]
set_load -pin_load 0.1 [get_ports {product[18]}]
set_load -pin_load 0.1 [get_ports {product[17]}]
set_load -pin_load 0.1 [get_ports {product[16]}]
set_load -pin_load 0.1 [get_ports {product[15]}]
set_load -pin_load 0.1 [get_ports {product[14]}]
set_load -pin_load 0.1 [get_ports {product[13]}]
set_load -pin_load 0.1 [get_ports {product[12]}]
set_load -pin_load 0.1 [get_ports {product[11]}]
set_load -pin_load 0.1 [get_ports {product[10]}]
set_load -pin_load 0.1 [get_ports {product[9]}]
set_load -pin_load 0.1 [get_ports {product[8]}]
set_load -pin_load 0.1 [get_ports {product[7]}]
set_load -pin_load 0.1 [get_ports {product[6]}]
set_load -pin_load 0.1 [get_ports {product[5]}]
set_load -pin_load 0.1 [get_ports {product[4]}]
set_load -pin_load 0.1 [get_ports {product[3]}]
set_load -pin_load 0.1 [get_ports {product[2]}]
set_load -pin_load 0.1 [get_ports {product[1]}]
set_load -pin_load 0.1 [get_ports {product[0]}]
set_load -pin_load 0.1 [get_ports {quotient[31]}]
set_load -pin_load 0.1 [get_ports {quotient[30]}]
set_load -pin_load 0.1 [get_ports {quotient[29]}]
set_load -pin_load 0.1 [get_ports {quotient[28]}]
set_load -pin_load 0.1 [get_ports {quotient[27]}]
set_load -pin_load 0.1 [get_ports {quotient[26]}]
set_load -pin_load 0.1 [get_ports {quotient[25]}]
set_load -pin_load 0.1 [get_ports {quotient[24]}]
set_load -pin_load 0.1 [get_ports {quotient[23]}]
set_load -pin_load 0.1 [get_ports {quotient[22]}]
set_load -pin_load 0.1 [get_ports {quotient[21]}]
set_load -pin_load 0.1 [get_ports {quotient[20]}]
set_load -pin_load 0.1 [get_ports {quotient[19]}]
set_load -pin_load 0.1 [get_ports {quotient[18]}]
set_load -pin_load 0.1 [get_ports {quotient[17]}]
set_load -pin_load 0.1 [get_ports {quotient[16]}]
set_load -pin_load 0.1 [get_ports {quotient[15]}]
set_load -pin_load 0.1 [get_ports {quotient[14]}]
set_load -pin_load 0.1 [get_ports {quotient[13]}]
set_load -pin_load 0.1 [get_ports {quotient[12]}]
set_load -pin_load 0.1 [get_ports {quotient[11]}]
set_load -pin_load 0.1 [get_ports {quotient[10]}]
set_load -pin_load 0.1 [get_ports {quotient[9]}]
set_load -pin_load 0.1 [get_ports {quotient[8]}]
set_load -pin_load 0.1 [get_ports {quotient[7]}]
set_load -pin_load 0.1 [get_ports {quotient[6]}]
set_load -pin_load 0.1 [get_ports {quotient[5]}]
set_load -pin_load 0.1 [get_ports {quotient[4]}]
set_load -pin_load 0.1 [get_ports {quotient[3]}]
set_load -pin_load 0.1 [get_ports {quotient[2]}]
set_load -pin_load 0.1 [get_ports {quotient[1]}]
set_load -pin_load 0.1 [get_ports {quotient[0]}]
set_load -pin_load 0.1 [get_ports {remainder[31]}]
set_load -pin_load 0.1 [get_ports {remainder[30]}]
set_load -pin_load 0.1 [get_ports {remainder[29]}]
set_load -pin_load 0.1 [get_ports {remainder[28]}]
set_load -pin_load 0.1 [get_ports {remainder[27]}]
set_load -pin_load 0.1 [get_ports {remainder[26]}]
set_load -pin_load 0.1 [get_ports {remainder[25]}]
set_load -pin_load 0.1 [get_ports {remainder[24]}]
set_load -pin_load 0.1 [get_ports {remainder[23]}]
set_load -pin_load 0.1 [get_ports {remainder[22]}]
set_load -pin_load 0.1 [get_ports {remainder[21]}]
set_load -pin_load 0.1 [get_ports {remainder[20]}]
set_load -pin_load 0.1 [get_ports {remainder[19]}]
set_load -pin_load 0.1 [get_ports {remainder[18]}]
set_load -pin_load 0.1 [get_ports {remainder[17]}]
set_load -pin_load 0.1 [get_ports {remainder[16]}]
set_load -pin_load 0.1 [get_ports {remainder[15]}]
set_load -pin_load 0.1 [get_ports {remainder[14]}]
set_load -pin_load 0.1 [get_ports {remainder[13]}]
set_load -pin_load 0.1 [get_ports {remainder[12]}]
set_load -pin_load 0.1 [get_ports {remainder[11]}]
set_load -pin_load 0.1 [get_ports {remainder[10]}]
set_load -pin_load 0.1 [get_ports {remainder[9]}]
set_load -pin_load 0.1 [get_ports {remainder[8]}]
set_load -pin_load 0.1 [get_ports {remainder[7]}]
set_load -pin_load 0.1 [get_ports {remainder[6]}]
set_load -pin_load 0.1 [get_ports {remainder[5]}]
set_load -pin_load 0.1 [get_ports {remainder[4]}]
set_load -pin_load 0.1 [get_ports {remainder[3]}]
set_load -pin_load 0.1 [get_ports {remainder[2]}]
set_load -pin_load 0.1 [get_ports {remainder[1]}]
set_load -pin_load 0.1 [get_ports {remainder[0]}]
set_false_path -from [get_ports rst_n]
set_multicycle_path -from [list \
  [get_cells {mdu_inst/div_count_reg[0]}]  \
  [get_cells {mdu_inst/div_count_reg[1]}]  \
  [get_cells {mdu_inst/div_count_reg[2]}]  \
  [get_cells {mdu_inst/div_count_reg[3]}]  \
  [get_cells {mdu_inst/div_count_reg[4]}]  \
  [get_cells {mdu_inst/div_count_reg[5]}] ] -to [list \
  [get_cells {mdu_inst/quotient_reg[0]}]  \
  [get_cells {mdu_inst/quotient_reg[1]}]  \
  [get_cells {mdu_inst/quotient_reg[2]}]  \
  [get_cells {mdu_inst/quotient_reg[3]}]  \
  [get_cells {mdu_inst/quotient_reg[4]}]  \
  [get_cells {mdu_inst/quotient_reg[5]}]  \
  [get_cells {mdu_inst/quotient_reg[6]}]  \
  [get_cells {mdu_inst/quotient_reg[7]}]  \
  [get_cells {mdu_inst/quotient_reg[8]}]  \
  [get_cells {mdu_inst/quotient_reg[9]}]  \
  [get_cells {mdu_inst/quotient_reg[10]}]  \
  [get_cells {mdu_inst/quotient_reg[11]}]  \
  [get_cells {mdu_inst/quotient_reg[12]}]  \
  [get_cells {mdu_inst/quotient_reg[13]}]  \
  [get_cells {mdu_inst/quotient_reg[14]}]  \
  [get_cells {mdu_inst/quotient_reg[15]}]  \
  [get_cells {mdu_inst/quotient_reg[16]}]  \
  [get_cells {mdu_inst/quotient_reg[17]}]  \
  [get_cells {mdu_inst/quotient_reg[18]}]  \
  [get_cells {mdu_inst/quotient_reg[19]}]  \
  [get_cells {mdu_inst/quotient_reg[20]}]  \
  [get_cells {mdu_inst/quotient_reg[21]}]  \
  [get_cells {mdu_inst/quotient_reg[22]}]  \
  [get_cells {mdu_inst/quotient_reg[23]}]  \
  [get_cells {mdu_inst/quotient_reg[24]}]  \
  [get_cells {mdu_inst/quotient_reg[25]}]  \
  [get_cells {mdu_inst/quotient_reg[26]}]  \
  [get_cells {mdu_inst/quotient_reg[27]}]  \
  [get_cells {mdu_inst/quotient_reg[28]}]  \
  [get_cells {mdu_inst/quotient_reg[29]}]  \
  [get_cells {mdu_inst/quotient_reg[30]}]  \
  [get_cells {mdu_inst/quotient_reg[31]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[0]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[1]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[2]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[3]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[4]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[5]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[6]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[7]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[8]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[9]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[10]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[11]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[12]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[13]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[14]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[15]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[16]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[17]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[18]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[19]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[20]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[21]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[22]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[23]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[24]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[25]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[26]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[27]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[28]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[29]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[30]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[31]}] ] -setup -end 32
set_multicycle_path -from [list \
  [get_cells {mdu_inst/div_count_reg[0]}]  \
  [get_cells {mdu_inst/div_count_reg[1]}]  \
  [get_cells {mdu_inst/div_count_reg[2]}]  \
  [get_cells {mdu_inst/div_count_reg[3]}]  \
  [get_cells {mdu_inst/div_count_reg[4]}]  \
  [get_cells {mdu_inst/div_count_reg[5]}] ] -to [list \
  [get_cells {mdu_inst/quotient_reg[0]}]  \
  [get_cells {mdu_inst/quotient_reg[1]}]  \
  [get_cells {mdu_inst/quotient_reg[2]}]  \
  [get_cells {mdu_inst/quotient_reg[3]}]  \
  [get_cells {mdu_inst/quotient_reg[4]}]  \
  [get_cells {mdu_inst/quotient_reg[5]}]  \
  [get_cells {mdu_inst/quotient_reg[6]}]  \
  [get_cells {mdu_inst/quotient_reg[7]}]  \
  [get_cells {mdu_inst/quotient_reg[8]}]  \
  [get_cells {mdu_inst/quotient_reg[9]}]  \
  [get_cells {mdu_inst/quotient_reg[10]}]  \
  [get_cells {mdu_inst/quotient_reg[11]}]  \
  [get_cells {mdu_inst/quotient_reg[12]}]  \
  [get_cells {mdu_inst/quotient_reg[13]}]  \
  [get_cells {mdu_inst/quotient_reg[14]}]  \
  [get_cells {mdu_inst/quotient_reg[15]}]  \
  [get_cells {mdu_inst/quotient_reg[16]}]  \
  [get_cells {mdu_inst/quotient_reg[17]}]  \
  [get_cells {mdu_inst/quotient_reg[18]}]  \
  [get_cells {mdu_inst/quotient_reg[19]}]  \
  [get_cells {mdu_inst/quotient_reg[20]}]  \
  [get_cells {mdu_inst/quotient_reg[21]}]  \
  [get_cells {mdu_inst/quotient_reg[22]}]  \
  [get_cells {mdu_inst/quotient_reg[23]}]  \
  [get_cells {mdu_inst/quotient_reg[24]}]  \
  [get_cells {mdu_inst/quotient_reg[25]}]  \
  [get_cells {mdu_inst/quotient_reg[26]}]  \
  [get_cells {mdu_inst/quotient_reg[27]}]  \
  [get_cells {mdu_inst/quotient_reg[28]}]  \
  [get_cells {mdu_inst/quotient_reg[29]}]  \
  [get_cells {mdu_inst/quotient_reg[30]}]  \
  [get_cells {mdu_inst/quotient_reg[31]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[0]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[1]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[2]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[3]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[4]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[5]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[6]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[7]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[8]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[9]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[10]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[11]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[12]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[13]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[14]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[15]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[16]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[17]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[18]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[19]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[20]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[21]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[22]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[23]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[24]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[25]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[26]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[27]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[28]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[29]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[30]}]  \
  [get_cells {mdu_inst/quotient_reg_reg[31]}] ] -hold -start 31
set_multicycle_path -from [list \
  [get_cells {mdu_inst/mul_count_reg[0]}]  \
  [get_cells {mdu_inst/mul_count_reg[1]}]  \
  [get_cells {mdu_inst/mul_count_reg[2]}]  \
  [get_cells {mdu_inst/mul_count_reg[3]}]  \
  [get_cells {mdu_inst/mul_count_reg[4]}]  \
  [get_cells {mdu_inst/mul_count_reg[5]}] ] -to [list \
  [get_cells {mdu_inst/acc_reg[0]}]  \
  [get_cells {mdu_inst/acc_reg[1]}]  \
  [get_cells {mdu_inst/acc_reg[2]}]  \
  [get_cells {mdu_inst/acc_reg[3]}]  \
  [get_cells {mdu_inst/acc_reg[4]}]  \
  [get_cells {mdu_inst/acc_reg[5]}]  \
  [get_cells {mdu_inst/acc_reg[6]}]  \
  [get_cells {mdu_inst/acc_reg[7]}]  \
  [get_cells {mdu_inst/acc_reg[8]}]  \
  [get_cells {mdu_inst/acc_reg[9]}]  \
  [get_cells {mdu_inst/acc_reg[10]}]  \
  [get_cells {mdu_inst/acc_reg[11]}]  \
  [get_cells {mdu_inst/acc_reg[12]}]  \
  [get_cells {mdu_inst/acc_reg[13]}]  \
  [get_cells {mdu_inst/acc_reg[14]}]  \
  [get_cells {mdu_inst/acc_reg[15]}]  \
  [get_cells {mdu_inst/acc_reg[16]}]  \
  [get_cells {mdu_inst/acc_reg[17]}]  \
  [get_cells {mdu_inst/acc_reg[18]}]  \
  [get_cells {mdu_inst/acc_reg[19]}]  \
  [get_cells {mdu_inst/acc_reg[20]}]  \
  [get_cells {mdu_inst/acc_reg[21]}]  \
  [get_cells {mdu_inst/acc_reg[22]}]  \
  [get_cells {mdu_inst/acc_reg[23]}]  \
  [get_cells {mdu_inst/acc_reg[24]}]  \
  [get_cells {mdu_inst/acc_reg[25]}]  \
  [get_cells {mdu_inst/acc_reg[26]}]  \
  [get_cells {mdu_inst/acc_reg[27]}]  \
  [get_cells {mdu_inst/acc_reg[28]}]  \
  [get_cells {mdu_inst/acc_reg[29]}]  \
  [get_cells {mdu_inst/acc_reg[30]}]  \
  [get_cells {mdu_inst/acc_reg[31]}]  \
  [get_cells {mdu_inst/acc_reg[32]}]  \
  [get_cells {mdu_inst/acc_reg[33]}]  \
  [get_cells {mdu_inst/acc_reg[34]}]  \
  [get_cells {mdu_inst/acc_reg[35]}]  \
  [get_cells {mdu_inst/acc_reg[36]}]  \
  [get_cells {mdu_inst/acc_reg[37]}]  \
  [get_cells {mdu_inst/acc_reg[38]}]  \
  [get_cells {mdu_inst/acc_reg[39]}]  \
  [get_cells {mdu_inst/acc_reg[40]}]  \
  [get_cells {mdu_inst/acc_reg[41]}]  \
  [get_cells {mdu_inst/acc_reg[42]}]  \
  [get_cells {mdu_inst/acc_reg[43]}]  \
  [get_cells {mdu_inst/acc_reg[44]}]  \
  [get_cells {mdu_inst/acc_reg[45]}]  \
  [get_cells {mdu_inst/acc_reg[46]}]  \
  [get_cells {mdu_inst/acc_reg[47]}]  \
  [get_cells {mdu_inst/acc_reg[48]}]  \
  [get_cells {mdu_inst/acc_reg[49]}]  \
  [get_cells {mdu_inst/acc_reg[50]}]  \
  [get_cells {mdu_inst/acc_reg[51]}]  \
  [get_cells {mdu_inst/acc_reg[52]}]  \
  [get_cells {mdu_inst/acc_reg[53]}]  \
  [get_cells {mdu_inst/acc_reg[54]}]  \
  [get_cells {mdu_inst/acc_reg[55]}]  \
  [get_cells {mdu_inst/acc_reg[56]}]  \
  [get_cells {mdu_inst/acc_reg[57]}]  \
  [get_cells {mdu_inst/acc_reg[58]}]  \
  [get_cells {mdu_inst/acc_reg[59]}]  \
  [get_cells {mdu_inst/acc_reg[60]}]  \
  [get_cells {mdu_inst/acc_reg[61]}]  \
  [get_cells {mdu_inst/acc_reg[62]}]  \
  [get_cells {mdu_inst/acc_reg[63]}] ] -setup -end 32
set_multicycle_path -from [list \
  [get_cells {mdu_inst/mul_count_reg[0]}]  \
  [get_cells {mdu_inst/mul_count_reg[1]}]  \
  [get_cells {mdu_inst/mul_count_reg[2]}]  \
  [get_cells {mdu_inst/mul_count_reg[3]}]  \
  [get_cells {mdu_inst/mul_count_reg[4]}]  \
  [get_cells {mdu_inst/mul_count_reg[5]}] ] -to [list \
  [get_cells {mdu_inst/acc_reg[0]}]  \
  [get_cells {mdu_inst/acc_reg[1]}]  \
  [get_cells {mdu_inst/acc_reg[2]}]  \
  [get_cells {mdu_inst/acc_reg[3]}]  \
  [get_cells {mdu_inst/acc_reg[4]}]  \
  [get_cells {mdu_inst/acc_reg[5]}]  \
  [get_cells {mdu_inst/acc_reg[6]}]  \
  [get_cells {mdu_inst/acc_reg[7]}]  \
  [get_cells {mdu_inst/acc_reg[8]}]  \
  [get_cells {mdu_inst/acc_reg[9]}]  \
  [get_cells {mdu_inst/acc_reg[10]}]  \
  [get_cells {mdu_inst/acc_reg[11]}]  \
  [get_cells {mdu_inst/acc_reg[12]}]  \
  [get_cells {mdu_inst/acc_reg[13]}]  \
  [get_cells {mdu_inst/acc_reg[14]}]  \
  [get_cells {mdu_inst/acc_reg[15]}]  \
  [get_cells {mdu_inst/acc_reg[16]}]  \
  [get_cells {mdu_inst/acc_reg[17]}]  \
  [get_cells {mdu_inst/acc_reg[18]}]  \
  [get_cells {mdu_inst/acc_reg[19]}]  \
  [get_cells {mdu_inst/acc_reg[20]}]  \
  [get_cells {mdu_inst/acc_reg[21]}]  \
  [get_cells {mdu_inst/acc_reg[22]}]  \
  [get_cells {mdu_inst/acc_reg[23]}]  \
  [get_cells {mdu_inst/acc_reg[24]}]  \
  [get_cells {mdu_inst/acc_reg[25]}]  \
  [get_cells {mdu_inst/acc_reg[26]}]  \
  [get_cells {mdu_inst/acc_reg[27]}]  \
  [get_cells {mdu_inst/acc_reg[28]}]  \
  [get_cells {mdu_inst/acc_reg[29]}]  \
  [get_cells {mdu_inst/acc_reg[30]}]  \
  [get_cells {mdu_inst/acc_reg[31]}]  \
  [get_cells {mdu_inst/acc_reg[32]}]  \
  [get_cells {mdu_inst/acc_reg[33]}]  \
  [get_cells {mdu_inst/acc_reg[34]}]  \
  [get_cells {mdu_inst/acc_reg[35]}]  \
  [get_cells {mdu_inst/acc_reg[36]}]  \
  [get_cells {mdu_inst/acc_reg[37]}]  \
  [get_cells {mdu_inst/acc_reg[38]}]  \
  [get_cells {mdu_inst/acc_reg[39]}]  \
  [get_cells {mdu_inst/acc_reg[40]}]  \
  [get_cells {mdu_inst/acc_reg[41]}]  \
  [get_cells {mdu_inst/acc_reg[42]}]  \
  [get_cells {mdu_inst/acc_reg[43]}]  \
  [get_cells {mdu_inst/acc_reg[44]}]  \
  [get_cells {mdu_inst/acc_reg[45]}]  \
  [get_cells {mdu_inst/acc_reg[46]}]  \
  [get_cells {mdu_inst/acc_reg[47]}]  \
  [get_cells {mdu_inst/acc_reg[48]}]  \
  [get_cells {mdu_inst/acc_reg[49]}]  \
  [get_cells {mdu_inst/acc_reg[50]}]  \
  [get_cells {mdu_inst/acc_reg[51]}]  \
  [get_cells {mdu_inst/acc_reg[52]}]  \
  [get_cells {mdu_inst/acc_reg[53]}]  \
  [get_cells {mdu_inst/acc_reg[54]}]  \
  [get_cells {mdu_inst/acc_reg[55]}]  \
  [get_cells {mdu_inst/acc_reg[56]}]  \
  [get_cells {mdu_inst/acc_reg[57]}]  \
  [get_cells {mdu_inst/acc_reg[58]}]  \
  [get_cells {mdu_inst/acc_reg[59]}]  \
  [get_cells {mdu_inst/acc_reg[60]}]  \
  [get_cells {mdu_inst/acc_reg[61]}]  \
  [get_cells {mdu_inst/acc_reg[62]}]  \
  [get_cells {mdu_inst/acc_reg[63]}] ] -hold -start 31
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports start]
set_input_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports ack]
set_input_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {funct3[2]}]
set_input_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {funct3[1]}]
set_input_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {funct3[0]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports busy]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports done]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[63]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[62]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[61]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[60]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[59]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[58]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[57]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[56]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[55]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[54]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[53]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[52]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[51]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[50]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[49]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[48]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[47]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[46]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[45]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[44]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[43]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[42]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[41]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[40]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[39]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[38]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[37]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[36]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[35]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[34]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[33]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[32]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[31]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[30]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[29]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[28]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[27]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[26]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[25]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[24]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[23]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[22]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[21]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[20]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[19]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[18]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[17]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[16]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[15]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[14]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[13]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[12]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[11]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[10]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[9]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[8]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[7]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[6]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[5]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[4]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[3]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[2]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[1]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {product[0]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[31]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[30]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[29]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[28]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[27]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[26]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[25]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[24]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[23]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[22]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[21]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[20]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[19]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[18]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[17]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[16]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[15]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[14]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[13]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[12]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[11]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[10]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[9]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[8]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[7]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[6]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[5]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[4]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[3]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[2]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[1]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {quotient[0]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[31]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[30]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[29]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[28]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[27]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[26]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[25]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[24]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[23]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[22]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[21]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[20]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[19]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[18]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[17]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[16]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[15]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[14]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[13]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[12]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[11]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[10]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[9]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[8]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[7]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[6]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[5]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[4]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[3]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[2]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[1]}]
set_output_delay -clock [get_clocks clk] -add_delay 1.0 [get_ports {remainder[0]}]
set_wire_load_mode "enclosed"
set_clock_uncertainty -setup 0.5 [get_clocks clk]
set_clock_uncertainty -hold 0.5 [get_clocks clk]
## List of unsupported SDC commands ##
set_max_area 50000.0
