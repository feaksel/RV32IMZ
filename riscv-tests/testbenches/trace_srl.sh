#!/bin/bash
# Enable trace in SRL testbench
sed -i 's|//.*\$display\("[%0t] PC|        \$display("[%0t] PC|' tb_compliance_rv32ui_p_srl.v
vvp tb_compliance_rv32ui_p_srl 2>&1 | head -100
