#!/bin/bash
#===============================================================================
# PDK Setup from Git Archive
# Reassembles and extracts the Sky130 PDK from split archive files
#===============================================================================

set -e

echo "================================================================================"
echo "Sky130 PDK Setup from Archive"
echo "================================================================================"

cd "$(dirname "$0")"

# Check if pdk_archive directory exists
if [ ! -d "pdk_archive" ]; then
    echo "ERROR: pdk_archive directory not found!"
    echo "Make sure you cloned the complete repository."
    exit 1
fi

# Check if all parts exist
if [ ! -f "pdk_archive/pdk_part_aa" ] || [ ! -f "pdk_archive/pdk_part_ab" ] || [ ! -f "pdk_archive/pdk_part_ac" ]; then
    echo "ERROR: Missing archive parts!"
    echo "Expected files: pdk_part_aa, pdk_part_ab, pdk_part_ac"
    exit 1
fi

echo "Step 1: Reassembling PDK archive (197MB)..."
cat pdk_archive/pdk_part_* > pdk_archive/pdk_full.tar.gz

echo "Step 2: Verifying archive integrity..."
if ! gzip -t pdk_archive/pdk_full.tar.gz 2>/dev/null; then
    echo "ERROR: Archive is corrupted!"
    rm -f pdk_archive/pdk_full.tar.gz
    exit 1
fi

echo "Step 3: Extracting PDK (this will create pdk/sky130A/)..."
tar -xzf pdk_archive/pdk_full.tar.gz -C .

echo "Step 4: Cleaning up temporary files..."
rm -f pdk_archive/pdk_full.tar.gz

echo
echo "================================================================================"
echo "PDK Setup Complete!"
echo "================================================================================"
echo
echo "Installed: Sky130 PDK (1.1GB extracted)"
echo "Location: pdk/sky130A"
echo
echo "You can now run the complete flow:"
echo "  ./run_complete_flow.sh"
echo
echo "================================================================================"
