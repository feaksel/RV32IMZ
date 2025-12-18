#!/bin/bash
#===============================================================================
# PDK Installation Script
# Automatically installs the full Sky130 PDK using volare
#===============================================================================

set -e

echo "================================================================================"
echo "Sky130 PDK Installation for RV32IM Core"
echo "================================================================================"

# Check if volare is installed
if ! command -v volare &> /dev/null; then
    echo "Installing volare PDK manager..."
    pip3 install volare
fi

# Install the exact PDK version used in this project
echo "Installing Sky130 PDK (1.1GB download)..."
echo "This may take several minutes depending on your internet connection..."
volare enable --pdk sky130 c6d73a35f524070e85faff4a6a9eef49553ebc2b

# Create symlink to the installed PDK
echo "Creating PDK symlink..."
cd pdk
if [ -L sky130A ]; then
    rm sky130A
fi
ln -s ~/.volare/sky130A sky130A

echo
echo "================================================================================"
echo "PDK Installation Complete!"
echo "================================================================================"
echo
echo "Installed: Sky130 PDK (1.1GB)"
echo "Location: ~/.volare/sky130A"
echo "Linked to: pdk/sky130A"
echo
echo "You can now run the complete flow:"
echo "  ./run_complete_flow.sh"
echo
echo "================================================================================"
