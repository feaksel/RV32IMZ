#!/bin/bash
# SKY130 PDK Configuration for RV32IM Homework
export PDK_ROOT=$PWD/pdk/sky130A
export STD_CELL_LIB=$PDK_ROOT/libs.ref/sky130_fd_sc_hd
export PDK_TECH=$PDK_ROOT/libs.tech
echo "SKY130 PDK configured for homework use"
echo "PDK_ROOT: $PDK_ROOT"
echo "Standard cells: $STD_CELL_LIB"