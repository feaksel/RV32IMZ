#!/bin/bash
#===============================================================================
# Script to Add OVERLAP Layer to Technology LEF File
#
# This script creates a MODIFIED copy of the tech LEF with OVERLAP layer.
# The original PDK file is NOT modified - this creates a new file.
#===============================================================================

# Paths
ORIGINAL_TECH_LEF="../sky130_osu_sc_t18/lef/sky130_osu_sc_18T_tech.lef"
MODIFIED_TECH_LEF="sky130_osu_sc_18T_tech_with_overlap.lef"

echo "========================================"
echo "Adding OVERLAP Layer to Tech LEF"
echo "========================================"
echo ""

# Check if original exists
if [ ! -f "$ORIGINAL_TECH_LEF" ]; then
    echo "ERROR: Original tech LEF not found at: $ORIGINAL_TECH_LEF"
    echo "Please adjust the path in this script."
    exit 1
fi

echo "Original tech LEF: $ORIGINAL_TECH_LEF"
echo "Modified tech LEF: $MODIFIED_TECH_LEF"
echo ""

# Copy original to new file
echo "Step 1: Copying original tech LEF..."
cp "$ORIGINAL_TECH_LEF" "$MODIFIED_TECH_LEF"

# Find the line with "END LIBRARY" and add OVERLAP before it
echo "Step 2: Adding OVERLAP layer definition..."

# Create temporary file with OVERLAP layer inserted before END LIBRARY
awk '
/^END LIBRARY/ {
    print ""
    print "# ============================================================================"
    print "# OVERLAP Layer - Required for write_lef_abstract"
    print "# Added automatically - not part of original PDK"
    print "# ============================================================================"
    print ""
    print "LAYER OVERLAP"
    print "  TYPE OVERLAP ;"
    print "END OVERLAP"
    print ""
}
{ print }
' "$MODIFIED_TECH_LEF" > "${MODIFIED_TECH_LEF}.tmp"

# Replace original with modified
mv "${MODIFIED_TECH_LEF}.tmp" "$MODIFIED_TECH_LEF"

echo "✓ OVERLAP layer added successfully!"
echo ""
echo "Modified tech LEF created: $MODIFIED_TECH_LEF"
echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo ""
echo "The setup scripts will automatically use this modified tech LEF."
echo "To use it manually in Innovus:"
echo ""
echo "  read_physical -lef $MODIFIED_TECH_LEF"
echo "  read_physical -lef ../sky130_osu_sc_t18/lef/sky130_osu_sc_18T.lef"
echo ""
echo "Then write_lef_abstract will work without OVERLAP errors!"
echo ""
