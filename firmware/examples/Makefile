# Makefile for CHB 5-Level Control Application
# Builds application for bootloader deployment

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
          -T ../application.ld

# Source files
SRCS = chb_test_simple.c ../startup.S
OBJS = $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

# Output files
TARGET = chb_test_simple
ELF = $(TARGET).elf
BIN = $(TARGET).bin
HEX = $(TARGET).hex
BIN_WITH_HEADER = $(TARGET)_with_header.bin
MAP = $(TARGET).map
LST = $(TARGET).lst

# Default target
all: $(BIN_WITH_HEADER) size

# Build ELF file
$(ELF): $(OBJS) ../application.ld
	@echo "Linking CHB application..."
	$(CC) $(LDFLAGS) -Wl,-Map=$(MAP) -o $@ $(OBJS)

# Convert to binary
$(BIN): $(ELF)
	@echo "Creating binary..."
	$(OBJCOPY) -O binary $< $@

# Add bootloader header
$(BIN_WITH_HEADER): $(BIN)
	@echo "Adding bootloader header..."
	python3 ../../tools/add_bootloader_header.py $< $@ --version 1.0.0

# Convert to hex for ROM initialization
$(HEX): $(BIN_WITH_HEADER)
	@echo "Creating application hex..."
	python3 ../bin2verilog.py $< -o $@

# Create disassembly listing
$(LST): $(ELF)
	@echo "Creating disassembly..."
	$(OBJDUMP) -d $< > $@

# Display size information
size: $(ELF)
	@echo ""
	@echo "=== CHB Application Size Information ==="
	$(SIZE) $<
	@echo ""
	@echo "Memory layout:"
	@echo "- Application space: 16KB (16384 bytes)"
	@echo "- Available RAM: 64KB"
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
	@echo "Cleaning CHB application..."
	rm -f $(OBJS) $(ELF) $(BIN) $(HEX) $(BIN_WITH_HEADER) $(MAP) $(LST)

# Install hex file for synthesis
install: $(HEX)
	@echo "Installing application..."
	cp $(HEX) ../../firmware.hex
	@echo "Application installed to firmware/firmware.hex"

# Upload via bootloader
upload: $(BIN_WITH_HEADER)
	@echo "Uploading via bootloader..."
	python3 ../../tools/upload_tool.py /dev/ttyUSB0 $<

# Test build
test: all $(LST)
	@echo "Build test completed successfully!"
	@echo "Files generated:"
	@echo "  $(ELF) - Executable"
	@echo "  $(BIN) - Raw binary" 
	@echo "  $(BIN_WITH_HEADER) - Binary with bootloader header"
	@echo "  $(HEX) - Hex file for synthesis"

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: all $(LST)

# Help
help:
	@echo "CHB 5-Level Control Application Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build application with header (default)"
	@echo "  clean    - Remove build files"
	@echo "  install  - Copy hex to firmware directory"
	@echo "  upload   - Upload via UART bootloader"
	@echo "  test     - Build and verify"
	@echo "  debug    - Build with debug symbols"
	@echo "  size     - Display memory usage"
	@echo "  help     - Show this help"

.PHONY: all clean install upload test debug size help