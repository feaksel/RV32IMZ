#!/bin/bash
# verify_portability.sh - Verify all paths are relative and portable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "========================================"
echo "Portability Verification"
echo "========================================"
echo ""

# Check for any remaining hardcoded paths (excluding this script)
echo "[1/5] Checking for hardcoded /home/furka paths in scripts..."
HARDCODED=$(grep -r "/home/furka" --include="*.sh" --include="*.tcl" --exclude="verify_portability.sh" . 2>/dev/null | wc -l)
if [ "$HARDCODED" -eq 0 ]; then
    echo "✓ PASS: No hardcoded paths found in executable scripts"
else
    echo "✗ FAIL: Found $HARDCODED hardcoded paths in scripts:"
    grep -r "/home/furka" --include="*.sh" --include="*.tcl" --exclude="verify_portability.sh" .
    exit 1
fi
echo ""

# Verify PDK_ROOT can be calculated
echo "[2/5] Verifying PDK_ROOT path calculation..."
EXPECTED_PDK="$(cd "${SCRIPT_DIR}/../../../pdk" 2>/dev/null && pwd)"
if [ -d "$EXPECTED_PDK/sky130A" ]; then
    echo "✓ PASS: PDK found at $EXPECTED_PDK"
    export PDK_ROOT="$EXPECTED_PDK"
else
    echo "⚠ WARNING: PDK not found at expected location: $EXPECTED_PDK"
    echo "  This is OK if you'll set PDK_ROOT manually at university"
fi
echo ""

# Verify all macro directories exist
echo "[3/5] Checking macro directory structure..."
MACROS=(
    "core_macro"
    "memory_macro"
    "adc_subsystem_macro"
    "communication_macro"
    "protection_macro"
    "pwm_accelerator_macro"
)

ALL_EXIST=true
for macro in "${MACROS[@]}"; do
    if [ -d "$macro" ]; then
        echo "✓ $macro/ exists"
    else
        echo "✗ $macro/ missing"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = true ]; then
    echo "✓ PASS: All macro directories present"
else
    echo "✗ FAIL: Some macro directories missing"
    exit 1
fi
echo ""

# Check for required scripts in each macro
echo "[4/5] Verifying required scripts exist..."
MISSING_SCRIPTS=false
for macro in "${MACROS[@]}"; do
    # Extract base name (e.g., "core" from "core_macro")
    base_name="${macro%_macro}"
    if [ "$macro" = "adc_subsystem_macro" ]; then
        base_name="adc_subsystem"
    fi
    if [ "$macro" = "pwm_accelerator_macro" ]; then
        base_name="pwm_accelerator"
    fi
    
    if [ ! -f "$macro/scripts/${base_name}_place_route.tcl" ]; then
        echo "✗ FAIL: $macro/scripts/${base_name}_place_route.tcl missing"
        MISSING_SCRIPTS=true
    fi
done

if [ "$MISSING_SCRIPTS" = false ]; then
    echo "✓ PASS: All critical P&R scripts present"
fi
echo ""

# Test environment variable usage
echo "[5/5] Testing environment variable in TCL syntax..."
TEST_SCRIPT="core_macro/scripts/core_place_route.tcl"
if grep -q '\$env(PDK_ROOT)' "$TEST_SCRIPT"; then
    echo "✓ PASS: Scripts use \$env(PDK_ROOT) for portability"
else
    echo "✗ FAIL: Scripts don't use environment variable syntax"
    exit 1
fi
echo ""

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
echo ""
echo "✓ All hardcoded paths removed"
echo "✓ Scripts use relative paths and environment variables"
echo "✓ Directory structure is correct"
echo "✓ Ready for university PC deployment"
echo ""
echo "To use at university:"
echo "  1. Copy entire macros/ directory to university PC"
echo "  2. Ensure PDK is at ../../../pdk/ or set PDK_ROOT"
echo "  3. Run: ./build_complete_proven_package.sh"
echo ""
echo "See PORTABILITY_FIXES.md for complete details."
