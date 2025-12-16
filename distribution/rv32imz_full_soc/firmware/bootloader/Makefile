# Makefile for RV32IMZ Bootloader
# Compiles bootloader for 5-Level CHB Inverter SoC

# Toolchain
PREFIX = riscv32-unknown-elf-
CC = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump
SIZE = $(PREFIX)size

# Target architecture
ARCH = -march=rv32im_zicsr -mabi=ilp32

# Compiler flags
CFLAGS = $(ARCH) \
         -O2 \
         -Wall -Wextra \
         -ffreestanding \
         -nostartfiles \
         -nostdlib \
         -fno-builtin \
         -fdata-sections \
         -ffunction-sections

# Linker flags
LDFLAGS = $(ARCH) \
          -nostartfiles \
          -nostdlib \
          -Wl,--gc-sections \
          -Wl,--print-memory-usage \
          -T bootloader.ld

# Source files
SRCS = boot_start.S bootloader.c
OBJS = $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

# Output files
TARGET = bootloader
ELF = $(TARGET).elf
BIN = $(TARGET).bin
HEX = $(TARGET).hex
MAP = $(TARGET).map
LST = $(TARGET).lst

# Default target
all: $(HEX) size

# Build ELF file
$(ELF): $(OBJS) bootloader.ld
	@echo "Linking bootloader..."
	$(CC) $(LDFLAGS) -Wl,-Map=$(MAP) -o $@ $(OBJS)

# Convert to binary
$(BIN): $(ELF)
	@echo "Creating binary..."
	$(OBJCOPY) -O binary $< $@

# Convert to hex (for Verilog $readmemh)
$(HEX): $(BIN)
	@echo "Creating hex file..."
	@python3 ../bin2verilog.py $< -o $@

# Create disassembly listing
$(LST): $(ELF)
	@echo "Creating disassembly..."
	$(OBJDUMP) -d $< > $@

# Display size information
size: $(ELF)
	@echo ""
	@echo "=== Bootloader Size Information ==="
	$(SIZE) $<
	@echo ""
	@echo "Memory usage:"
	@echo "- Bootloader space: 16KB (16384 bytes)"
	@echo "- Application space: 16KB (16384 bytes)"
	@echo ""

# Compile C files
%.o: %.c
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# Compile assembly files
%.o: %.S
	@echo "Assembling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# Clean build files
clean:
	@echo "Cleaning bootloader..."
	rm -f $(OBJS) $(ELF) $(BIN) $(HEX) $(MAP) $(LST)

# Install hex file to firmware directory
install: $(HEX)
	@echo "Installing bootloader..."
	cp $(HEX) ../bootloader.hex
	@echo "Bootloader installed to firmware/bootloader.hex"

# Debug build with symbols
debug: CFLAGS += -g -DDEBUG
debug: all $(LST)

# Help
help:
	@echo "RV32IMZ Bootloader Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build bootloader hex file (default)"
	@echo "  clean    - Remove build files"
	@echo "  install  - Copy hex file to firmware directory"
	@echo "  debug    - Build with debug symbols"
	@echo "  size     - Display memory usage"
	@echo "  help     - Show this help"
	@echo ""
	@echo "Files generated:"
	@echo "  $(ELF)  - ELF executable"
	@echo "  $(BIN)  - Raw binary"
	@echo "  $(HEX)  - Verilog hex file"
	@echo "  $(MAP)  - Linker map"
	@echo "  $(LST)  - Disassembly listing"

# Phony targets
.PHONY: all clean install debug size help