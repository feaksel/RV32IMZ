#!/bin/bash
#===============================================================================
# University Setup Script - Complete ASIC Flow for Both Distributions
# Sets up rv32im_core_only and rv32imz_full_soc with multiple PDK options
#===============================================================================

echo "🎓 University ASIC Setup for RV32IM/RV32IMZ Project"
echo "=================================================="
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ONLY_DIR="$PROJECT_ROOT/distribution/rv32im_core_only"
FULL_SOC_DIR="$PROJECT_ROOT/distribution/rv32imz_full_soc"

# Check if distributions exist
if [ ! -d "$CORE_ONLY_DIR" ] || [ ! -d "$FULL_SOC_DIR" ]; then
    echo "❌ Error: Distribution directories not found"
    echo "Expected:"
    echo "  $CORE_ONLY_DIR"
    echo "  $FULL_SOC_DIR"
    exit 1
fi

echo "✅ Found both distributions:"
echo "   📦 Core Only: $CORE_ONLY_DIR"
echo "   🏗️  Full SoC: $FULL_SOC_DIR"
echo ""

echo "Setting up PDK configurations for university use..."
echo ""

# Setup core-only distribution
echo "🔧 Setting up RV32IM Core Only..."
cd "$CORE_ONLY_DIR"
if [ -f "setup_pdk_configs.sh" ]; then
    chmod +x setup_pdk_configs.sh
    echo "Running automated setup for core-only..."
    echo "4" | ./setup_pdk_configs.sh  # Option 4: Setup all
else
    echo "❌ Warning: setup_pdk_configs.sh not found in core-only"
fi
echo ""

# Setup full SoC distribution  
echo "🔧 Setting up RV32IMZ Full SoC..."
cd "$FULL_SOC_DIR"
if [ -f "setup_pdk_configs.sh" ]; then
    chmod +x setup_pdk_configs.sh
    echo "Running automated setup for full SoC..."
    echo "4" | ./setup_pdk_configs.sh  # Option 4: Setup all
else
    echo "❌ Warning: setup_pdk_configs.sh not found in full SoC"
fi
echo ""

# Create university quick-start guide
cat > "$PROJECT_ROOT/UNIVERSITY_QUICK_START.md" << 'EOF'
# University Quick Start Guide

## Available Distributions

### 1. RV32IM Core Only (`rv32im_core_only/`)
- **Purpose**: Single RISC-V core synthesis
- **Size**: Small, fast synthesis
- **Best for**: Core-only projects, quick demos

### 2. RV32IMZ Full SoC (`rv32imz_full_soc/`)  
- **Purpose**: Complete system-on-chip
- **Size**: Larger, includes peripherals and memory
- **Best for**: Full system projects, comprehensive demo

## PDK Configuration Options

Each distribution supports 3 PDK configurations:

| Configuration | Cells | CTS | Synthesis Time | Use Case |
|--------------|-------|-----|----------------|----------|
| **Minimal** | ~20 | ❌ No | 2-5 min | Quick demos |
| **Basic CTS** | ~25 | ⚡ Basic | 3-6 min | **Recommended** |
| **Enhanced** | ~80 | ✅ Full | 10-15 min | High quality |

## Quick Commands

### Switch PDK Configuration
```bash
cd distribution/rv32im_core_only    # or rv32imz_full_soc
./switch_pdk.sh                     # Interactive PDK switcher
```

### Run Synthesis Flow
```bash
# Basic flow (works with any PDK config)
cd distribution/rv32im_core_only/synthesis_cadence
genus -f synthesis.tcl
innovus -f place_route.tcl

# Or use automated script
cd distribution/rv32im_core_only
./run_complete_flow.sh
```

### Test Different PDK Configurations
```bash
# Test minimal PDK (fastest)
./switch_pdk.sh  # Choose option 1
./run_complete_flow.sh

# Test basic CTS PDK (recommended)  
./switch_pdk.sh  # Choose option 2
./run_complete_flow.sh

# Test enhanced PDK (highest quality)
./switch_pdk.sh  # Choose option 3
./run_complete_flow.sh
```

## University Lab Tips

1. **Start with Basic CTS**: Good balance of speed and features
2. **Use Core Only first**: Faster for testing and debugging
3. **Switch to Full SoC**: When ready for complete system demo
4. **Compare Results**: Try different PDK configs to see differences
5. **Backup Work**: Each PDK switch backs up previous config

## Troubleshooting

- **Genus library errors**: Try different methods in synthesis.tcl
- **Innovus crashes**: Use simple MMMC with minimal PDK
- **No GDS output**: Check place_route.tcl error handling
- **Slow synthesis**: Switch to minimal or basic CTS PDK

## File Locations

- **Synthesis Scripts**: `synthesis_cadence/synthesis.tcl`
- **P&R Scripts**: `synthesis_cadence/place_route.tcl`  
- **PDK Configs**: `pdk_configurations/`
- **Output Files**: `synthesis_cadence/outputs/`
- **Reports**: `synthesis_cadence/reports/`
EOF

cd "$PROJECT_ROOT"

echo "🎯 University setup complete!"
echo ""
echo "📚 Quick Start:"
echo "   1. Read: UNIVERSITY_QUICK_START.md"
echo "   2. Choose distribution: rv32im_core_only or rv32imz_full_soc"
echo "   3. Switch PDK: ./switch_pdk.sh"
echo "   4. Run synthesis: ./run_complete_flow.sh"
echo ""
echo "📁 Both distributions are ready with:"
echo "   ✅ Multiple PDK configurations" 
echo "   ✅ Easy switching between configs"
echo "   ✅ Automated synthesis flow"
echo "   ✅ Error handling and fallbacks"
echo ""
echo "🎓 Perfect for university Cadence labs!"

# Copy all configurations to full SoC as well
echo ""
echo "🔄 Synchronizing configurations between distributions..."

# Copy synthesis configs to full SoC
cp "$CORE_ONLY_DIR/synthesis_cadence/config_"*.tcl "$FULL_SOC_DIR/synthesis_cadence/" 2>/dev/null
cp "$CORE_ONLY_DIR/synthesis_cadence/pr_config_"*.tcl "$FULL_SOC_DIR/synthesis_cadence/" 2>/dev/null

echo "✅ Both distributions synchronized and ready!"