#!/bin/bash
# Master build script for RV32IM SoC - Builds everything in correct order
# Output: Individual macros + rv32im_integrated_macro + full SoC package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export PDK_ROOT="$(cd "../../../pdk" && pwd)"
export PACKAGE_ROOT="$(cd ".." && pwd)"

echo "========================================"
echo "RV32IM SoC Complete Build Flow"
echo "========================================"
echo "PDK: $PDK_ROOT"
echo "Package: $PACKAGE_ROOT"
echo ""

# Build order (dependency-driven)
PERIPHERAL_MACROS=(
    "memory_macro"
    "communication_macro" 
    "protection_macro"
    "adc_subsystem_macro"
    "pwm_accelerator_macro"
)

CPU_MACROS=(
    "core_macro"
    "mdu_macro"
)

INTEGRATED_MACRO="rv32im_integrated_macro"

# Function to build a single macro
build_macro() {
    local macro_name=$1
    local macro_dir="$SCRIPT_DIR/$macro_name"
    
    echo ""
    echo "=========================================="
    echo "Building: $macro_name"
    echo "=========================================="
    
    if [ ! -d "$macro_dir" ]; then
        echo "ERROR: Directory not found: $macro_dir"
        return 1
    fi
    
    cd "$macro_dir"
    
    # Run synthesis
    echo "[1/2] Running synthesis..."
    if ! genus -batch -files scripts/${macro_name%_macro}_synthesis.tcl > logs/${macro_name}_synthesis.log 2>&1; then
        echo "ERROR: Synthesis failed for $macro_name"
        return 1
    fi
    
    # Run place & route
    echo "[2/2] Running place & route..."
    if ! innovus -batch -files scripts/${macro_name%_macro}_place_route.tcl > logs/${macro_name}_pr.log 2>&1; then
        echo "ERROR: Place & Route failed for $macro_name"
        return 1
    fi
    
    echo "✅ $macro_name complete"
    cd "$SCRIPT_DIR"
    return 0
}

# Build integrated macro (hierarchical)
build_integrated_macro() {
    echo ""
    echo "=========================================="
    echo "Building: rv32im_integrated_macro"
    echo "=========================================="
    
    cd "$SCRIPT_DIR/rv32im_integrated_macro"
    
    # Check prerequisites
    if [ ! -f "../core_macro/outputs/core_macro_syn.v" ]; then
        echo "ERROR: core_macro must be built first"
        return 1
    fi
    
    if [ ! -f "../mdu_macro/outputs/mdu_macro_syn.v" ]; then
        echo "ERROR: mdu_macro must be built first"
        return 1
    fi
    
    echo "[1/2] Running hierarchical synthesis..."
    if ! genus -batch -files scripts/rv32im_integrated_synthesis.tcl > logs/integrated_synthesis.log 2>&1; then
        echo "ERROR: Integrated synthesis failed"
        return 1
    fi
    
    echo "[2/2] Running hierarchical place & route..."
    if ! innovus -batch -files scripts/rv32im_integrated_place_route.tcl > logs/integrated_pr.log 2>&1; then
        echo "ERROR: Integrated P&R failed"
        return 1
    fi
    
    echo "✅ rv32im_integrated_macro complete"
    cd "$SCRIPT_DIR"
    return 0
}

# Build final SoC package
build_soc_package() {
    echo ""
    echo "=========================================="
    echo "Building: Final SoC Package"
    echo "=========================================="
    
    cd "$SCRIPT_DIR"
    
    # Check all prerequisites exist
    local missing=0
    for macro in "${PERIPHERAL_MACROS[@]}"; do
        if [ ! -f "$macro/outputs/${macro}.gds" ]; then
            echo "ERROR: Missing $macro/outputs/${macro}.gds"
            missing=1
        fi
    done
    
    if [ ! -f "rv32im_integrated_macro/outputs/rv32im_integrated_macro.gds" ]; then
        echo "ERROR: Missing rv32im_integrated_macro.gds"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        echo "ERROR: Cannot build SoC - missing prerequisite macros"
        return 1
    fi
    
    # Create outputs directory
    mkdir -p soc_integration/outputs soc_integration/logs
    
    echo "[1/2] Running SoC integration synthesis..."
    cd soc_integration
    if ! genus -batch -files scripts/soc_integration_synthesis.tcl > logs/soc_synthesis.log 2>&1; then
        echo "ERROR: SoC synthesis failed"
        return 1
    fi
    
    echo "[2/2] Running SoC place & route..."
    if ! innovus -batch -files scripts/soc_integration_place_route.tcl > logs/soc_pr.log 2>&1; then
        echo "ERROR: SoC P&R failed"
        return 1
    fi
    
    echo "✅ SoC package complete"
    cd "$SCRIPT_DIR"
    return 0
}

# Main build flow
echo "Build Plan:"
echo "  Step 1: Build 5 peripheral macros"
echo "  Step 2: Build core + MDU macros"
echo "  Step 3: Build rv32im_integrated_macro (core+MDU)"
echo "  Step 4: Build final SoC package (integrated+peripherals)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

START_TIME=$(date +%s)

# Step 1: Build peripheral macros
echo ""
echo "=========================================="
echo "STEP 1/4: Building Peripheral Macros"
echo "=========================================="
for macro in "${PERIPHERAL_MACROS[@]}"; do
    if ! build_macro "$macro"; then
        echo "❌ Build failed at: $macro"
        exit 1
    fi
done

# Step 2: Build CPU macros (core and MDU separately)
echo ""
echo "=========================================="
echo "STEP 2/4: Building CPU Macros (Core + MDU)"
echo "=========================================="
for macro in "${CPU_MACROS[@]}"; do
    if ! build_macro "$macro"; then
        echo "❌ Build failed at: $macro"
        exit 1
    fi
done

# Step 3: Build integrated macro
echo ""
echo "=========================================="
echo "STEP 3/4: Building Integrated RV32IM IP"
echo "=========================================="
if ! build_integrated_macro; then
    echo "❌ Integrated macro build failed"
    exit 1
fi

# Step 4: Build final SoC
echo ""
echo "=========================================="
echo "STEP 4/4: Building Final SoC Package"
echo "=========================================="
if ! build_soc_package; then
    echo "❌ SoC package build failed"
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))

echo ""
echo "=========================================="
echo "✅ BUILD COMPLETE!"
echo "=========================================="
echo "Time elapsed: ${HOURS}h ${MINUTES}m"
echo ""
echo "Output Files:"
echo ""
echo "Individual Peripheral Macros:"
for macro in "${PERIPHERAL_MACROS[@]}"; do
    echo "  • $macro/outputs/${macro}.gds"
    echo "    - Reports: $macro/outputs/*.rpt"
done
echo ""
echo "CPU Macros:"
for macro in "${CPU_MACROS[@]}"; do
    echo "  • $macro/outputs/${macro}.gds"
    echo "    - Reports: $macro/outputs/*.rpt"
done
echo ""
echo "Integrated RV32IM IP:"
echo "  • rv32im_integrated_macro/outputs/rv32im_integrated_macro.gds"
echo "    - Reports: rv32im_integrated_macro/outputs/*.rpt"
echo ""
echo "Final SoC Package:"
echo "  • soc_integration/outputs/rv32im_soc_complete.gds"
echo "    - Reports: soc_integration/outputs/*.rpt"
echo ""
echo "Ready for tapeout!"
