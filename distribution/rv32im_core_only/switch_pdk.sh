#!/bin/bash
#===============================================================================
# Simple PDK Switcher for University Use
# Works in both rv32im_core_only and rv32imz_full_soc directories
#===============================================================================

echo "🔄 PDK Configuration Switcher"
echo "============================="

# Detect current directory type
if [[ "$PWD" == *"rv32im_core_only"* ]]; then
    DISTRIBUTION="RV32IM Core Only"
elif [[ "$PWD" == *"rv32imz_full_soc"* ]]; then  
    DISTRIBUTION="RV32IMZ Full SoC"
else
    echo "❌ Run this script from rv32im_core_only or rv32imz_full_soc directory"
    exit 1
fi

echo "Distribution: $DISTRIBUTION"
echo ""

# Check if configurations exist
CONFIGS_DIR="pdk_configurations"
if [ ! -d "$CONFIGS_DIR" ]; then
    echo "❌ No PDK configurations found"
    echo "Run: ./setup_pdk_configs.sh first"
    exit 1
fi

# Show available configurations
echo "Available PDK configurations:"
configs=($(ls -1 "$CONFIGS_DIR"))
for i in "${!configs[@]}"; do
    config=${configs[$i]}
    case $config in
        "minimal")
            echo "$((i+1)). 📦 MINIMAL - Fast academic demo (~10MB)"
            ;;
        "basic_cts") 
            echo "$((i+1)). ⚡ BASIC CTS - Recommended balance (~20MB)"
            ;;
        "enhanced")
            echo "$((i+1)). 🚀 ENHANCED - Best quality (~100MB)"
            ;;
        *)
            echo "$((i+1)). 📁 $config"
            ;;
    esac
done

echo ""
read -p "Choose configuration (1-${#configs[@]}): " choice

# Validate choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#configs[@]} ]; then
    echo "❌ Invalid choice"
    exit 1
fi

selected_config=${configs[$((choice-1))]}
echo ""
echo "🔄 Switching to: $selected_config"

# Remove current PDK (no backup needed - configs are preserved)
if [ -d "pdk" ]; then
    rm -rf pdk
    echo "🗑️  Removed current PDK"
fi

# Copy selected configuration
if [ -d "$CONFIGS_DIR/$selected_config/pdk" ]; then
    cp -r "$CONFIGS_DIR/$selected_config/pdk" .
    echo "✅ Switched to $selected_config PDK configuration"
    
    # Show what this config includes
    case $selected_config in
        "minimal")
            echo "📦 Active: Minimal PDK"
            echo "   - Fast synthesis (2-5 min)"
            echo "   - No CTS (clock as regular net)" 
            echo "   - Perfect for quick demos"
            ;;
        "basic_cts")
            echo "⚡ Active: Basic CTS PDK" 
            echo "   - Moderate synthesis (3-6 min)"
            echo "   - Basic CTS capability"
            echo "   - Recommended for most work"
            ;;
        "enhanced")
            echo "🚀 Active: Enhanced PDK"
            echo "   - Slower synthesis (10-15 min)"
            echo "   - Full CTS and optimization"
            echo "   - Best quality results"
            ;;
    esac
    
    echo ""
    echo "🎯 Ready to run synthesis!"
    echo "   ./run_complete_flow.sh"
    
else
    echo "❌ Configuration $selected_config not properly set up"
    echo "Try running: ./setup_pdk_configs.sh"
    exit 1
fi