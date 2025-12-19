#!/bin/bash

#===============================================================================
# Complete Macro Package Build Script - PROVEN WORKING VERSION
# Based on your working synthesis.tcl and place_route.tcl templates
# For RV32IM SoC - All 6 Macros + Integrated SoC
#===============================================================================

echo "============================================================="
echo "RV32IM Complete Macro Package Build"
echo "Based on PROVEN working Cadence scripts"
echo "============================================================="
echo ""
echo "Building all 6 macros according to your original specification:"
echo "  1. CPU Core Macro (RV32IM + MDU) - ~11K cells"
echo "  2. Memory Macro (32KB ROM + 64KB RAM) - ~10K cells"
echo "  3. PWM Accelerator Macro - ~3K cells"
echo "  4. ADC Subsystem Macro - ~4K cells"
echo "  5. Protection Macro - ~1K cells"
echo "  6. Communication Macro - ~2K cells"
echo ""

# Set up environment - use relative paths for portability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PDK_ROOT="$(cd "${SCRIPT_DIR}/../../../pdk" && pwd)"
export PACKAGE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build order based on dependencies
BUILD_ORDER=(
    "memory_macro"
    "communication_macro" 
    "protection_macro"
    "adc_subsystem_macro"
    "pwm_accelerator_macro"
    "mdu_macro"
    "core_macro"
    "rv32im_integrated_macro"  # NEW: Hierarchical integration of core+MDU
)

echo "Build order (dependency-driven):"
for i in "${!BUILD_ORDER[@]}"; do
    echo "  $((i+1)). ${BUILD_ORDER[$i]}"
done
echo ""

# Function to build a single macro (synthesis + P&R)
build_macro() {
    local macro_name=$1
    local macro_dir="$PACKAGE_ROOT/macros/$macro_name"
    
    echo "============================================="
    echo "Building $macro_name"
    echo "============================================="
    
    if [ ! -d "$macro_dir" ]; then
        echo "ERROR: Macro directory not found: $macro_dir"
        return 1
    fi
    
    cd "$macro_dir"
    
    # Special handling for rv32im_integrated_macro
    if [ "$macro_name" = "rv32im_integrated_macro" ]; then
        echo "Building integrated macro (requires core_macro and mdu_macro)..."
        if [ -f "./build_integrated_macro.sh" ]; then
            ./build_integrated_macro.sh
            if [ $? -ne 0 ]; then
                echo "ERROR: Integrated macro build failed"
                return 1
            fi
            echo "rv32im_integrated_macro build completed successfully!"
            echo ""
            return 0
        else
            echo "ERROR: build_integrated_macro.sh not found"
            return 1
        fi
    fi
    
    # Run Synthesis (using proven working approach)
    echo "Running synthesis for $macro_name..."
    if [ -f "scripts/${macro_name}_synthesis.tcl" ]; then
        genus -files scripts/${macro_name}_synthesis.tcl -log logs/synthesis.log
        if [ $? -ne 0 ]; then
            echo "ERROR: Synthesis failed for $macro_name"
            return 1
        fi
    elif [ -f "synthesis/${macro_name}_synthesis.tcl" ]; then
        cd synthesis
        genus -files ${macro_name}_synthesis.tcl -log ../logs/synthesis.log
        cd ..
        if [ $? -ne 0 ]; then
            echo "ERROR: Synthesis failed for $macro_name"
            return 1
        fi
    else
        echo "ERROR: No synthesis script found for $macro_name"
        return 1
    fi
    
    # Run Place & Route (using proven working approach)
    echo "Running place & route for $macro_name..."
    if [ -f "scripts/${macro_name}_place_route.tcl" ]; then
        innovus -files scripts/${macro_name}_place_route.tcl -log logs/place_route.log
        if [ $? -ne 0 ]; then
            echo "ERROR: Place & route failed for $macro_name"
            return 1
        fi
    elif [ -f "synthesis/${macro_name}_place_route.tcl" ]; then
        cd synthesis
        innovus -files ${macro_name}_place_route.tcl -log ../logs/place_route.log
        cd ..
        if [ $? -ne 0 ]; then
            echo "ERROR: Place & route failed for $macro_name"
            return 1
        fi
    else
        echo "ERROR: No place & route script found for $macro_name"
        return 1
    fi
    
    echo "$macro_name build completed successfully!"
    echo ""
    
    return 0
}

# Create output directories
echo "Setting up build environment..."
for macro in "${BUILD_ORDER[@]}"; do
    macro_dir="$PACKAGE_ROOT/macros/$macro"
    mkdir -p "$macro_dir/logs"
    mkdir -p "$macro_dir/outputs"
    mkdir -p "$macro_dir/reports"
done

# Build each macro in dependency order
echo "Starting macro builds..."
echo ""

failed_builds=()
successful_builds=()

for macro in "${BUILD_ORDER[@]}"; do
    if build_macro "$macro"; then
        successful_builds+=("$macro")
    else
        failed_builds+=("$macro")
        echo "WARNING: Continuing with remaining macros despite $macro failure..."
    fi
done

# Build summary
echo "============================================="
echo "BUILD SUMMARY"
echo "============================================="
echo ""

if [ ${#successful_builds[@]} -gt 0 ]; then
    echo "✅ SUCCESSFUL BUILDS (${#successful_builds[@]}):"
    for macro in "${successful_builds[@]}"; do
        echo "   - $macro"
    done
    echo ""
fi

if [ ${#failed_builds[@]} -gt 0 ]; then
    echo "❌ FAILED BUILDS (${#failed_builds[@]}):"
    for macro in "${failed_builds[@]}"; do
        echo "   - $macro"
    done
    echo ""
fi

# Generate package summary
echo "PACKAGE STRUCTURE:"
echo ""
for macro in "${BUILD_ORDER[@]}"; do
    macro_dir="$PACKAGE_ROOT/macros/$macro"
    if [ -d "$macro_dir/outputs" ] && [ "$(ls -A $macro_dir/outputs)" ]; then
        echo "📁 $macro:"
        if [ -f "$macro_dir/outputs/${macro}.gds" ]; then
            echo "   ✅ GDS Layout: outputs/${macro}.gds"
        fi
        if [ -f "$macro_dir/outputs/${macro}.lef" ]; then
            echo "   ✅ LEF Abstract: outputs/${macro}.lef"
        fi
        if [ -f "$macro_dir/outputs/${macro}_netlist.v" ]; then
            echo "   ✅ Netlist: outputs/${macro}_netlist.v"
        fi
        echo ""
    else
        echo "📁 $macro: ❌ No outputs generated"
        echo ""
    fi
done

# Package verification
total_macros=${#BUILD_ORDER[@]}
if [ ${#successful_builds[@]} -eq $total_macros ]; then
    echo "🎉 COMPLETE SUCCESS: All $total_macros macros built successfully!"
    echo ""
    echo "Your complete macro package is ready for:"
    echo "  - Individual macro reuse"
    echo "  - Hierarchical SoC integration"
    echo "  - Academic coursework"
    echo "  - Further development"
    echo ""
    echo "Next steps:"
    echo "  1. Verify timing/area in reports/"
    echo "  2. Use LEF files for top-level integration"
    echo "  3. Integrate into your main SoC design"
elif [ ${#successful_builds[@]} -gt 0 ]; then
    echo "⚠️  PARTIAL SUCCESS: ${#successful_builds[@]}/$total_macros macros completed"
    echo ""
    echo "You can proceed with successful macros."
    echo "Check failed macro logs for debugging."
else
    echo "💥 BUILD FAILED: No macros completed successfully"
    echo ""
    echo "Please check:"
    echo "  - PDK installation at $PDK_ROOT"
    echo "  - Tool availability (genus, innovus)"
    echo "  - RTL file presence"
    echo "  - Script paths and permissions"
fi

echo ""
echo "============================================="
echo "Macro Package Build Complete"
echo "============================================="

# Return appropriate exit code
if [ ${#failed_builds[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi