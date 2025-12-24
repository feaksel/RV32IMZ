#===============================================================================
# Generate LEF Abstract for Leaf Macro
#===============================================================================

# Restore post-route design
restoreDesign DBS/route.enc DESIGN_NAME

puts ""
puts "==> Generating LEF abstract..."
puts ""

# Create output directory
exec mkdir -p outputs

# Generate LEF
write_lef_abstract -5.7 outputs/DESIGN_NAME.lef

puts ""
puts "✓ LEF generated: outputs/DESIGN_NAME.lef"
puts ""

exit
