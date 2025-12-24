#===============================================================================
# Generate GDS with SRAM Macro Merged
#===============================================================================

# Restore post-route design
restoreDesign DBS/route.enc DESIGN_NAME

puts ""
puts "==> Generating GDS with SRAM merged..."
puts ""

# Create output directory
exec mkdir -p outputs

# SRAM configuration
set SRAM_NAME "sky130_sram_2kbyte_1rw1r_32x512_8"
set SRAM_GDS_PATH "$env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/gds"
set sram_gds "${SRAM_GDS_PATH}/${SRAM_NAME}.gds"

# Check if SRAM GDS exists
if {[file exists $sram_gds]} {
    puts "Found SRAM GDS: $sram_gds"

    # Find GDS map file
    if {[file exists "streamOut.map"]} {
        set gds_map "streamOut.map"
    } elseif {[file exists "../streamOut.map"]} {
        set gds_map "../streamOut.map"
    } else {
        set gds_map ""
    }

    # Generate GDS with SRAM merged
    if {$gds_map != ""} {
        streamOut outputs/DESIGN_NAME.gds \
            -mapFile $gds_map \
            -merge $sram_gds \
            -stripes 1 \
            -units 1000 \
            -mode ALL
        puts "✓ GDS generated with map file: $gds_map"
    } else {
        streamOut outputs/DESIGN_NAME.gds \
            -merge $sram_gds \
            -stripes 1 \
            -units 1000 \
            -mode ALL
        puts "✓ GDS generated (no map file)"
    }

    puts "✓ SRAM macro merged into GDS"
} else {
    puts "WARNING: SRAM GDS not found at: $sram_gds"
    puts "Generating GDS without SRAM merge..."

    # Generate without SRAM
    if {[file exists "streamOut.map"]} {
        streamOut outputs/DESIGN_NAME.gds \
            -mapFile streamOut.map \
            -mode ALL
    } else {
        streamOut outputs/DESIGN_NAME.gds -mode ALL
    }
}

# Also save netlist
saveNetlist outputs/DESIGN_NAME_netlist.v -excludeLeafCell

puts ""
puts "✓ GDS generated: outputs/DESIGN_NAME.gds"
puts "✓ Netlist saved: outputs/DESIGN_NAME_netlist.v"
puts ""

exit
