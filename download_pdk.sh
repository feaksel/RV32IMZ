#!/bin/bash

#==============================================================================
# Download Essential SKY130 PDK Files for Homework
# Creates a minimal, self-contained PDK subset (~50MB instead of 2GB)
#==============================================================================

echo "Downloading essential SKY130 PDK files for homework..."

# Create PDK directory structure
mkdir -p pdk/sky130A/{libs.ref/sky130_fd_sc_hd/{lib,lef},libs.tech/{klayout,magic}}

cd pdk/sky130A

# Download timing libraries (essential for synthesis)
echo "Downloading timing libraries..."
curl -L -o libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__tt_025C_1v80.lib"

curl -L -o libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__ff_100C_1v95.lib"

curl -L -o libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__ss_n40C_1v60.lib"

# Download physical libraries (essential for place & route)
echo "Downloading LEF files..."
curl -L -o libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/cells/lef/sky130_fd_sc_hd.lef"

curl -L -o libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd__tech.lef \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/sky130_fd_sc_hd/latest/tech/sky130_fd_sc_hd__tech.lef"

# Download technology files (for GDS2 streaming)
echo "Downloading technology files..."
curl -L -o libs.tech/klayout/sky130A.lyt \
  "https://raw.githubusercontent.com/google/skywater-pdk/main/libraries/klayout/tech/sky130A.lyt"

# Create GDS2 mapping file for streaming
cat > libs.tech/klayout/sky130A.gds.map << 'EOF'
# SKY130 GDS2 Layer Mapping for Academic Use
# Layer mapping for Innovus streamOut command

# Format: layerName layerNumber datatype
# Metal layers
metal1 68 20
metal2 69 20  
metal3 70 20
metal4 71 20
metal5 72 20

# Via layers
via 67 20
via2 71 44
via3 70 44
via4 71 44

# Diffusion and poly
ndiffusion 65 20
pdiffusion 65 44
polysilicon 66 20

# Wells
nwell 64 20
pwell 65 44

# Text and labels
text 83 20
EOF

# Create RC extraction file (simplified for academics)
cat > libs.tech/magic/sky130A.rcx << 'EOF'
# SKY130 RC Extraction Rules (Simplified for Academic Use)
# Metal resistance (ohm/sq)
layer metal1 0.125
layer metal2 0.125  
layer metal3 0.047
layer metal4 0.047
layer metal5 0.029

# Via resistance (ohms)
via via 4.5
via via2 4.5
via via3 4.5  
via via4 4.5

# Capacitance (fF/um^2) - simplified
cap metal1 0.014
cap metal2 0.014
cap metal3 0.009
cap metal4 0.009
cap metal5 0.006
EOF

# Create PDK configuration script
cat > pdk_config.sh << 'EOF'
#!/bin/bash
# SKY130 PDK Configuration for RV32IM Homework
export PDK_ROOT=$PWD/pdk/sky130A
export STD_CELL_LIB=$PDK_ROOT/libs.ref/sky130_fd_sc_hd
export PDK_TECH=$PDK_ROOT/libs.tech
echo "SKY130 PDK configured for homework use"
echo "PDK_ROOT: $PDK_ROOT"
echo "Standard cells: $STD_CELL_LIB"
EOF

chmod +x pdk_config.sh

# Verify downloads
echo ""
echo "Verifying PDK files..."
echo "Timing libraries:"
ls -lh libs.ref/sky130_fd_sc_hd/lib/*.lib
echo ""
echo "LEF files:"
ls -lh libs.ref/sky130_fd_sc_hd/lef/*.lef
echo ""
echo "Technology files:"
ls -lh libs.tech/klayout/*

# Calculate size
PDK_SIZE=$(du -sh . | cut -f1)
echo ""
echo "✓ Essential SKY130 PDK ready!"
echo "Size: $PDK_SIZE (minimal subset)"
echo "Location: $(pwd)"
echo ""
echo "To use: source pdk_config.sh"

cd ../../
echo "✓ PDK download complete - ready for homework package!"