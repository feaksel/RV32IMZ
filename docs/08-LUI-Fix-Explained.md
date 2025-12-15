\*\*LUI Fix — Explanation and Verification

- **File changed**: /02-embedded/riscv/rtl/core/custom_riscv_core.v
- **Problem**: `LUI` (Load Upper Immediate) was implemented by performing an ALU operation using `rs1` as operand A. This means `LUI rd, imm` was effectively computed as `rd = rs1 + imm`, which is incorrect. LUI should write `imm << 12` to `rd` (i.e., rd = immediate << 12), and should not read or add `rs1`.

Root cause and effect:

- The ALU operand selection logic incorrectly used `rs1` for operand A by default: `assign alu_operand_a = (opcode == OPCODE_AUIPC) ? pc : rs1_data;`.
- This caused LUI to add the destination register's previous contents (via rs1) to the immediate. Because many test programs (including `rv32um` tests) rely on deterministically setting registers using LUI/AUIPC sequences, the wrong operand resulted in incorrect constants, which then made later instructions (e.g., multiply tests, memory store loads) compute wrong results and fail assertions.

What I changed:

- In `custom_riscv_core.v`, I updated the ALU operand A logic so that LUI uses zero, AUIPC uses PC, and otherwise operand A is `rs1_data`:

  assign alu_operand_a = (opcode == `OPCODE_AUIPC) ? pc : (opcode == `OPCODE_LUI) ? 32'h0 : rs1_data;

Why this fixes it:

- For LUI (U-type instruction), the decoded `immediate` field already contains the immediate shifted into the upper 20 bits (imm[31:12] << 12). The ALU should just add `imm` to zero to produce `imm << 12`. By forcing `operand A` to 0 for LUI, `rd` gets exactly the intended immediate value.

Verification steps performed:

- Re-ran the `rv32um` compliance subset; previously failing M tests (`mulh`, `mulhsu`, `mulhu`) now pass.
- Full rv32ui + rv32um results after the change: 47 passed, 3 failed (pass rate 94.0%). Previously the suite reported 34 passed, 16 failed (68.0%). The change resolved many failures and specifically resolved the `mulh` family failures.

Notes and implications:

- The patch is small and surgical, no changes to public APIs or external interfaces were made.
- The change doesn't affect AUIPC semantics (which still uses PC as operand A) and leaves other instruction behaviors intact.
- The `LUI` change is minimal but critical; it prevents incorrect constants from propagating into other instructions that depend on them.

Next steps suggested:

- Investigate remaining failing tests (rv32ui `fence.i`, `ma_data`, and a timeout `ld_st`). Those failures appear to be related to memory/fence semantics and potentially to data memory writes and SEL handling.
- Add unit tests for LUI/AUIPC in the testbench to avoid regressions in future changes.

Contact: For questions, refer to the changed code in [rtl/core/custom_riscv_core.v](02-embedded/riscv/rtl/core/custom_riscv_core.v#L72-L75).
