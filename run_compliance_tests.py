#!/usr/bin/env python3
"""
RISC-V Compliance Test Runner
Converts official riscv-tests to memory format and runs them on the custom RISC-V core
"""

import os
import sys
import subprocess
import re
from pathlib import Path

# Paths
RISCV_TESTS_DIR = Path("riscv-tests/isa")
COMPLIANCE_DIR = Path("riscv-tests")
TESTBENCH_DIR = COMPLIANCE_DIR / "testbenches"
RTL_DIR = Path("rtl/core")

# Toolchain
OBJCOPY = "/opt/riscv/bin/riscv32-unknown-elf-objcopy"
OBJDUMP = "/opt/riscv/bin/riscv32-unknown-elf-objdump"
IVERILOG = "iverilog"
VVP = "vvp"

def convert_elf_to_hex(elf_file, hex_file):
    """Convert ELF file to hex format suitable for Verilog $readmemh"""
    try:
        # Ensure output directory exists
        hex_file.parent.mkdir(parents=True, exist_ok=True)

        # Convert to binary
        bin_file = hex_file.with_suffix('.bin')
        subprocess.run([
            OBJCOPY,
            "-O", "binary",
            str(elf_file),
            str(bin_file)
        ], check=True, capture_output=True)

        # Convert binary to hex (word-addressed)
        with open(bin_file, 'rb') as f:
            binary_data = f.read()

        with open(hex_file, 'w') as f:
            # Pad to word boundary
            while len(binary_data) % 4 != 0:
                binary_data += b'\x00'

            # Write as 32-bit words (little-endian)
            for i in range(0, len(binary_data), 4):
                word = int.from_bytes(binary_data[i:i+4], byteorder='little')
                f.write(f"{word:08x}\n")

        # Clean up binary file
        bin_file.unlink()
        return True
    except Exception as e:
        print(f"Error converting {elf_file}: {e}")
        return False

def get_test_info(elf_file):
    """Extract test information from ELF file"""
    try:
        # Use nm to get tohost symbol address
        result = subprocess.run(
            [f"{OBJCOPY.replace('objcopy', 'nm')}", str(elf_file)],
            capture_output=True, text=True, check=True
        )

        # Parse nm output to find tohost
        for line in result.stdout.splitlines():
            if 'tohost' in line and not 'write_tohost' in line:
                parts = line.split()
                if len(parts) >= 1:
                    addr = int(parts[0], 16)
                    # Subtract base address (0x80000000) to get offset
                    offset = addr - 0x80000000
                    # Convert to word address
                    word_offset = offset // 4
                    return {'tohost_word_offset': word_offset}

        # Fallback to 0x1000 if not found
        return {'tohost_word_offset': 0x400}
    except:
        return {'tohost_word_offset': 0x400}

def create_testbench(test_name, hex_file, test_info):
    """Create Verilog testbench for compliance test"""

    # tohost is at fixed word offset
    tohost_offset = test_info['tohost_word_offset']

    # Sanitize test name for Verilog (replace hyphens with underscores)
    verilog_name = test_name.replace('-', '_')

    testbench = f'''`timescale 1ns/1ps
`include "riscv_defines.vh"

module tb_compliance_{verilog_name};
    reg clk = 0;
    reg rst_n;
    always #5 clk = ~clk;

    wire [31:0] iwb_adr_o, dwb_adr_o, dwb_dat_o;
    wire [31:0] iwb_dat_i, dwb_dat_i;
    wire iwb_cyc_o, iwb_stb_o, dwb_we_o, dwb_cyc_o, dwb_stb_o;
    wire [3:0] dwb_sel_o;
    wire dwb_err_i = 0;
    reg [31:0] interrupts = 0;

    // UNIFIED MEMORY - Single array for both instruction and data access
    // This enables self-modifying code and FENCE.I support
    reg [31:0] mem [0:8191];  // 32KB unified memory
    reg imem_ack, dmem_ack;
    reg [31:0] imem_data, dmem_data;

    assign iwb_dat_i = imem_data;
    assign dwb_dat_i = dmem_data;

    custom_riscv_core dut (
        .clk(clk), .rst_n(rst_n),
        .iwb_adr_o(iwb_adr_o), .iwb_dat_i(iwb_dat_i),
        .iwb_cyc_o(iwb_cyc_o), .iwb_stb_o(iwb_stb_o), .iwb_ack_i(imem_ack),
        .dwb_adr_o(dwb_adr_o), .dwb_dat_o(dwb_dat_o), .dwb_dat_i(dwb_dat_i),
        .dwb_we_o(dwb_we_o), .dwb_sel_o(dwb_sel_o),
        .dwb_cyc_o(dwb_cyc_o), .dwb_stb_o(dwb_stb_o), .dwb_ack_i(dmem_ack),
        .dwb_err_i(dwb_err_i), .interrupts(interrupts)
    );

    // Instruction fetch from unified memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ack <= 0;
            imem_data <= 32'h00000013;
        end else begin
            if (iwb_stb_o && iwb_cyc_o && !imem_ack) begin
                imem_data <= mem[iwb_adr_o[14:2]];  // Read from unified memory
                imem_ack <= 1;
            end else begin
                imem_ack <= 0;
            end
        end
    end

    // Data read - combinational (Wishbone requires data valid same cycle as ACK)
    always @(*) begin
        if (dwb_stb_o && dwb_cyc_o) begin
            dmem_data = mem[dwb_adr_o[14:2]];  // Read from unified memory
        end else begin
            dmem_data = 32'h0;
        end
    end

    // Data write and tohost monitoring
    reg [31:0] tohost = 0;
    reg [31:0] newv;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ack <= 0;
            tohost <= 0;
        end else begin
            if (dwb_stb_o && dwb_cyc_o && !dmem_ack) begin
                if (dwb_we_o) begin
                    // Masked write: apply dwb_sel_o to update only selected bytes
                    newv = mem[dwb_adr_o[14:2]];
                    if (dwb_sel_o[0]) newv[7:0]   = dwb_dat_o[7:0];
                    if (dwb_sel_o[1]) newv[15:8]  = dwb_dat_o[15:8];
                    if (dwb_sel_o[2]) newv[23:16] = dwb_dat_o[23:16];
                    if (dwb_sel_o[3]) newv[31:24] = dwb_dat_o[31:24];
                    mem[dwb_adr_o[14:2]] <= newv;  // Write to unified memory
                    // Monitor tohost writes
                    if (dwb_adr_o[14:2] == {tohost_offset}) begin
                        tohost <= dwb_dat_o;
                        if (dwb_dat_o != 0) begin
                            if (dwb_dat_o == 1) begin
                                $display("\\n*** TEST PASSED ***");
                                $finish;
                            end else begin
                                $display("\\n*** TEST FAILED *** (code: %0d)", dwb_dat_o >> 1);
                                $finish;
                            end
                        end
                    end
                end
                dmem_ack <= 1;
            end else begin
                dmem_ack <= 0;
            end
        end
    end

    integer i;
    initial begin
        rst_n = 0;
        interrupts = 32'h0;

        // Initialize unified memory
        for (i = 0; i < 8192; i = i + 1) begin
            mem[i] = 32'h00000013;  // NOP
        end

        // Load test program into unified memory
        // (RISC-V tests use unified memory with code and data in same binary)
        $readmemh("{hex_file.name}", mem);

        #20 rst_n = 1;

        // Timeout after 100000 cycles
        #1000000;
        $display("\\n*** TEST TIMEOUT ***");
        $finish;
    end

    // Trace execution for debugging
    always @(posedge clk) begin
        if (rst_n && dut.state == dut.STATE_MEM && dwb_cyc_o && !dwb_we_o) begin
            $display("[LOAD] PC=0x%08x addr=0x%08x funct3=%b data=0x%08x",
                     dut.pc, dwb_adr_o, dut.funct3, dwb_dat_i);
        end
        if (rst_n && dut.state == dut.STATE_WRITEBACK && dut.rd_wen && dut.mem_read) begin
            $display("[WB_LOAD] PC=0x%08x x%0d <= 0x%08x (mem_data_reg=0x%08x, addr_offset=%b)",
                     dut.pc, dut.rd_addr, dut.rd_data, dut.mem_data_reg, dut.alu_result_reg[1:0]);
        end
        if (rst_n && dut.state == dut.STATE_TRAP) begin
            $display("[TRAP] PC=0x%08x, cause=0x%08x, val=0x%08x",
                     dut.trap_pc, dut.trap_cause, dut.trap_val);
        end
    end
endmodule
'''

    tb_file = TESTBENCH_DIR / f"tb_compliance_{verilog_name}.v"
    with open(tb_file, 'w') as f:
        f.write(testbench)

    return tb_file

def run_test(test_name, tb_file):
    """Compile and run test"""
    try:
        # Compile
        verilog_name = test_name.replace('-', '_')
        sim_file = TESTBENCH_DIR / f"tb_compliance_{verilog_name}"
        compile_cmd = [
            IVERILOG,
            "-g2012",
            "-DSIMULATION",
            f"-I{RTL_DIR}",
            "-o", str(sim_file),
            str(tb_file),
            *[str(f) for f in RTL_DIR.glob("*.v")]
        ]

        result = subprocess.run(compile_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  Compilation failed:")
            print(result.stderr)
            return False

        # Run simulation (set cwd to testbench dir so $readmemh can find hex files)
        result = subprocess.run([VVP, str(sim_file.name)], capture_output=True, text=True, timeout=10, cwd=TESTBENCH_DIR)

        # Check result
        if "TEST PASSED" in result.stdout:
            return True
        elif "TEST FAILED" in result.stdout:
            # Extract failure code
            match = re.search(r'code: (\d+)', result.stdout)
            if match:
                print(f"  Failed with code: {match.group(1)}")
            # Print simulator output to help debugging
            print("--- Simulator stdout ---")
            print(result.stdout)
            print("--- End simulator stdout ---")
            return False
        elif "TEST TIMEOUT" in result.stdout:
            print(f"  Timeout")
            return False
        else:
            print(f"  Unknown result")
            print(result.stdout[-200:] if len(result.stdout) > 200 else result.stdout)
            return False

    except subprocess.TimeoutExpired:
        print(f"  Simulation timeout")
        return False
    except Exception as e:
        print(f"  Error running test: {e}")
        return False

def main():
    """Main test runner"""

    # Test patterns to run (can be overridden with --pattern <pattern>)
    if len(sys.argv) >= 3 and sys.argv[1] == "--pattern":
        test_patterns = [sys.argv[2]]
    else:
        test_patterns = [
            "rv32ui-p-*",  # RV32I base integer tests
            "rv32um-p-*",  # RV32M multiply/divide tests
        ]

    # Find all test files
    test_files = []
    for pattern in test_patterns:
        test_files.extend(RISCV_TESTS_DIR.glob(pattern))

    # Filter out .dump files and keep only executables
    test_files = [f for f in test_files if f.suffix != '.dump' and not f.name.endswith('.dump')]
    test_files.sort()

    print(f"Found {len(test_files)} compliance tests")
    print("=" * 60)

    passed = 0
    failed = 0

    for test_file in test_files:
        test_name = test_file.name
        print(f"\\nRunning {test_name}...")

        # Convert to hex
        hex_file = TESTBENCH_DIR / f"{test_name}.hex"
        if not convert_elf_to_hex(test_file, hex_file):
            print(f"  Conversion failed")
            failed += 1
            continue

        # Get test info
        test_info = get_test_info(test_file)
        if not test_info:
            print(f"  Could not extract test info")
            failed += 1
            continue

        # Create testbench
        tb_file = create_testbench(test_name, hex_file, test_info)

        # Run test
        if run_test(test_name, tb_file):
            print(f"  ✓ PASSED")
            passed += 1
        else:
            print(f"  ✗ FAILED")
            failed += 1

    print("\\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed, {passed + failed} total")
    print(f"Pass rate: {100 * passed / (passed + failed):.1f}%")

    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
