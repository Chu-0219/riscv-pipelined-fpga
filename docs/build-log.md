# Build log

Day-by-day record of building the RV32I core: what got written, what broke, and how each bug was found. Moved out of `README.md` on 2026-08-15 so the README can stay a 30-second overview.

Newest entry at the bottom.

---

## Day 0 · 2026-07-09 — repository setup

- Initialized this Git repository.
- Created the project README.
- Set up the remote GitHub repository.

---

## Day 1 · 2026-07-10 — toolchain bring-up on Basys 3

- Board arrived; completed toolchain bring-up on Basys 3.
- Hit and resolved several environment issues along the way: AMD account profile incomplete (blocked device-file download), 7 Series device support not installed (the board silently disappeared from the New Project wizard), constraint file not actually added to the project (DRC failed with all 32 ports unconstrained).
- `rtl/led_passthrough.v`: minimal combinational design (`assign led = sw`) used purely to validate the toolchain.
- `constraints/basys3_led_test.xdc`: full switch/LED pin mapping for Basys 3 rev B/C.
- Verified on hardware: synthesis → implementation → bitstream → JTAG program; toggling SW0–15 correctly drives LD0–15.

Toolchain confirmed working end-to-end.

---

## Combinational logic & testbench fundamentals

- `rtl/mux2to1.v`: 2-to-1 multiplexer using a ternary `assign`.
- `rtl/adder4bit.v`: 4-bit adder using concatenation (`{cout, sum} = a + b + cin`) to capture the carry-out alongside the sum in one line.
- `rtl/priority_encoder.v`: priority encoder using `casez` with wildcard matching; includes a `default` branch to avoid unintended latch inference.
- Hit and resolved several Verilog syntax issues along the way: missing semicolon after a port list (caused cascading syntax errors on later lines), missing colons in `casez` branches, wrong radix specifier (`'d` used where `'b` was intended), and mismatched signal names between a declaration and an instantiation — Verilog's implicit wire declaration silently created a new signal instead of raising a compile error, which was the most instructive bug of the batch.
- Learned testbench fundamentals: `initial` blocks, `$display` for printing signal values, and DUT instantiation via named port connections (`.port(signal)`).
- `tb/practice/adder4bit_tb.v`: first self-checking testbench. Rather than printing values for manual inspection, it computes the expected sum internally and asserts PASS/FAIL via `if-else` — the self-checking pattern this project treats as a baseline habit going forward.
- Compiled and simulated with Icarus Verilog (`iverilog` + `vvp`); confirmed PASS on the first test case.

---

## Sequential logic exercises

Practice modules covering flip-flop based design before moving to the core proper: a parameterised adder (`adder_n`), a synchronous RAM (`sync_ram`, initialised from `ram_init.hex`), a switch debouncer (`debounce`), and a Moore-machine sequence detector (`seq_detect_moore`). Each has a testbench under `tb/practice/`.

Two mistakes from this batch worth recording, because both produce *plausible-looking* waveforms rather than obvious failures:

**Blocking (`=`) vs non-blocking (`<=`) assignment.** Using `=` inside an `always @(posedge clk)` block makes the assignment take effect immediately, so a later statement in the same block reads the *new* value instead of the value the flip-flop held at the clock edge. In a two-stage shift register this collapses both stages into one — and whether it happens to look right in simulation depends on the order the statements are written in. The rule adopted from here on: sequential `always` blocks use `<=` exclusively, combinational `always` blocks use `=` exclusively, and the two never mix inside one block.

**Synchronous vs asynchronous reset, and the sensitivity list.** An asynchronous reset must appear in the sensitivity list (`always @(posedge clk or negedge rst_n)`); writing the reset check inside a clock-only sensitivity list gives a *synchronous* reset, which does nothing until the next rising clock edge. The bug is easy to miss because in a testbench the clock is usually already running when reset is asserted, so the design does eventually reset — just one cycle later than intended, which only becomes visible when something else depends on that first cycle.

---

## Core modules

- `rtl/alu.v`: RV32I ALU. Started as an 8-bit version while learning, later widened to 32 bits.
- `rtl/regfile.v`: 32×32 register file. `x0` is hardwired to zero, two asynchronous read ports and one synchronous write port.
- `rtl/alu_regfile_top.v`: first multi-module integration — register file feeding the ALU, result written back.

---

## Day 6 · 2026-08-14 — ImmGen, 32-bit ALU, decoder

Three modules committed, all passing self-checking testbenches: `imm_gen.v` (26/26), `alu.v` widened to 32 bits with SRA / SLTU / LUI added (36/36), and `decoder.v` (26/26).

`imm_gen.v` covers all five RV32I immediate formats (I / S / B / U / J), each sign-extended to 32 bits. B-type and J-type have their bits scattered across the instruction word and a hardwired zero in the LSB, so those two carry most of the risk and most of the test cases.

`decoder.v` is two-level: the main decoder maps `opcode` to control signals, and the ALU decoder maps `funct3` / `funct7` — plus the ALUOp hint from the main decoder — to the ALU control code. Two levels rather than one flat table, so that adding an instruction touches one small table instead of the whole decode logic.

### Bug of the day — the test vector itself was wrong

While hand-encoding `beq x1, x2, -8`, the `imm[4:1]` field was written as `1000`; the correct value is `1100`. The cause was skipping the bit-by-bit labelling step and simply taking the last four characters of the binary representation of -8 — those four bits are `imm[3:0]`, not `imm[4:1]`. The whole field was off by one position.

Worth recording because of what it says about self-checking testbenches generally: a self-checking testbench only proves that the DUT agrees with the expected value written in the testbench. It cannot prove the expected value is right. For instruction encodings, where the expected value is hand-derived, the derivation needs its own check — labelling every bit position explicitly before writing the vector, rather than pattern-matching on a bit string.

---

## Day 7 · 2026-08-15 — repository cleanup, and three bugs that were all in the test environment

Rewrote the README around a three-column status table, moved this build log out of it, sorted the early exercises into `rtl/practice/` and `tb/practice/`, added a `.gitignore` for simulation artifacts, and tagged `v0.1`.

Three things broke during the cleanup, and none of them was in a design under test:

1. **A hand-derived expected value was wrong.** Encoding `beq x1, x2, -8`, the `imm[4:1]` field was written as the last four bits of -8 — those are `imm[3:0]`. Off by one bit position.
2. **Stimulus silently failed to load.** Moving files broke the `$readmemh` path in `sync_ram_tb`. `$readmemh` reports a failure and carries on, leaving memory as `x`, so twelve checks failed — but the write-then-read check still passed, because it never depended on the preloaded contents. A testbench with only that one check would have reported success.
3. **Two core testbenches were deleted by accident** during a batch operation, and were caught only by reading `git status` line by line before committing.

The common shape: a self-checking testbench proves the DUT agrees with the expected value written in the testbench. It does not prove the expected value was derived correctly, that the stimulus actually reached the DUT, or that the test still exists. Those need their own checks — labelling bit positions explicitly before writing a vector, and deliberately breaking the DUT once to confirm the testbench actually reports FAIL.

---

## 2026-08-18 — ALU on hardware

Synthesised `alu.v` onto the Basys 3 (xc7a35tcpg236-1), driving operands from the slide switches and reading the result on the LEDs. Covered five classes of path on real hardware: arithmetic, logic, shift, comparison, and the `zero` flag.

Only the LED passthrough had been on the board before (July), and that was validating the toolchain. This time what was validated was RTL written for this project.

### Pin assignment

| Switches | Purpose |
|---|---|
| SW3–SW0 | Operand A (low 4 bits, zero-extended to 32) |
| SW7–SW4 | Operand B |
| SW11–SW8 | `alu_op` opcode |
| SW15–SW12 | Unused |

| LEDs | Meaning |
|---|---|
| LD14–LD0 | `result[14:0]` |
| LD15 | `zero` flag |

### alu_op encoding

| Code | Operation | Code | Operation |
|---|---|---|---|
| `0000` | ADD | `0110` | SLL |
| `0001` | SUB | `0111` | SRL |
| `0010` | AND | `1000` | SRA |
| `0011` | OR | `1001` | SLTU |
| `0100` | XOR | `1010` | LUI |
| `0101` | SLT | | |

### Board-level test cases

| A | B | op | Expected | Result |
|---|---|---|---|---|
| 3 | 5 | ADD | LD3 (8) | ✅ |
| 5 | 3 | SUB | LD1 (2) | ✅ |
| 3 | 3 | SUB | all off + LD15 | ✅ |
| `1100` | `1010` | AND | LD3 (8) | ✅ |
| `1100` | `1010` | OR | LD3/2/1 (14) | ✅ |
| 1 | 3 | SLL | LD3 (8) | ✅ |
| 3 | 5 | SLT | LD0 (1) | ✅ |
| 7 | 1 | ADD | LD3 (8) | ✅ |

![3 + 5 = 8, LD3 lit](images/alu_add_3plus5.jpg)
![3 − 3 = 0, zero flag set, LD15 lit](images/alu_zero_flag.jpg)

### Synthesis resources (Report Utilization)

| Item | Used | Available | Share |
|---|---|---|---|
| Slice LUTs | 81 | 20800 | 1% |
| F7 Muxes | 4 | 16300 | <1% |
| F8 Muxes | 2 | 8150 | <1% |
| Bonded IOB | 28 | 106 | 26% |
| Slice Registers | 0 | 41600 | 0% |

A few observations:

- Of the 81 LUTs, the bulk goes to the adder carry chain and the three 32-bit shifters (SLL/SRL/SRA); the pure bitwise operations — AND/OR/XOR/LUI — cost almost nothing.
- F7/F8 MUXes are dedicated Xilinx hardware for building wide multiplexers. `case (alu_op)` has 11 branches, so the synthesiser implements it as a MUX tree and borrows F7/F8 where the tree gets too wide for a single LUT.
- **Slice Registers = 0** is an important health indicator: the ALU is purely combinational and should contain no flip-flops at all. A non-zero count would mean a missing `case` branch caused the synthesiser to infer a latch — the most common hidden bug in combinational Verilog. A `default` branch was written here, so this one was avoided.

### Snags

None. The whole flow passed on the first attempt.

The only real friction was how deeply Vivado buries things in its GUI — Report Utilization only appears in a second-level menu after Open Synthesized Design, and it took a while to find the first time. Not a technical problem, a tool-familiarity problem.

---

## 2026-08-19 — PC unit, instruction memory, data memory

Three modules, each with its own self-checking testbench:

| Module | File | Result |
|---|---|---|
| PC unit | `rtl/pc_unit.v` | `tb/tb_pc_unit.v` — 12/12 |
| Instruction memory | `rtl/imem.v` | `tb/tb_imem.v` — 10/10 |
| Data memory | `rtl/dmem.v` | `tb/tb_dmem.v` — 10/10 |

`pc_unit.v` packages the PC register, the PC+4 adder, the branch-target adder and the next-address selector into one module, and exposes `pc_plus4` and `pc_target` as combinational outputs for the top level to use. JALR computes its target as `rs1 + imm` rather than `PC + imm`, so it needs a separate path at the top level — a known to-do.

`tb/prog_imem.hex` holds eight hand-encoded RV32I instructions. The machine-code test program planned for 8/22 can reuse them.

### Three design decisions

**Synchronous reset on the PC.** The `if (rst)` sits inside `always @(posedge clk)`, so it synthesises onto the register's own synchronous reset input and costs no extra resources. An asynchronous reset introduces a metastability window when the reset is released close to a clock edge, which then needs a reset synchroniser; with a single clock domain there is no reason to pay that price.

The sequential-logic exercises recorded the mirror image of this mistake — intending an asynchronous reset but omitting it from the sensitivity list, which silently produced a synchronous one. Read together, the two entries make the real point: neither style is better in the abstract, but the sensitivity list has to match the intent.

**Instruction memory reads combinationally; data memory writes synchronously and reads combinationally.** A single-cycle core has to complete fetch, decode, execute, memory and write-back within one cycle, so neither the fetch nor the data read can afford another clock edge — both reads must be combinational. The write has to be synchronous, otherwise a change on the address bus would immediately trigger a write and corrupt a location that was never meant to be touched.

**The low two address bits are ignored (`addr[9:2]`).** RISC-V addresses count bytes while the memory is organised in 32-bit words, so word N sits at byte address 4N; slicing `addr[9:2]` is a divide by four. Depth is 256 words (1 KB), and this slice has to be updated in step with any change to the depth. Byte and half-word accesses (`sb` / `sh` / `lb` / `lh`) are not implemented — they need byte enables and sign extension driven by `funct3` — a known to-do.

### Bug of the day — an implicit wire let a typo'd port name past the compiler

The output port of `imem.v` was typed as `inster`, while the `assign` inside the module drove `instr`:

```verilog
output [31:0] inster              // the port
...
assign instr = mem[addr[9:2]];    // drives something else entirely
```

This compiles without complaint. Verilog implicitly declares any undeclared identifier as a 1-bit wire, so `instr` was quietly created as a new one-bit net while the actual output port `inster` stayed unconnected. The error only surfaced when the testbench tried to instantiate the module:

```
tb/tb_imem.v:7: error: port `instr' is not a port of dut.
```

This is the same root cause as the mismatched signal name recorded in the combinational-logic batch, showing up a second time in a different disguise. The first time it was a signal that failed to connect; this time it was a typo'd port name. In both cases nothing goes wrong at the point where the mistake is made — the failure is deferred to the point of use.

An available defence is to disable implicit nets:

```verilog
`default_nettype none
// ... module body ...
`default_nettype wire
```

With `none` in force, an undeclared identifier is a compile error rather than a new one-bit wire; restoring `wire` at the end of the file keeps the setting from leaking into whatever is compiled next. The cost is that every intermediate signal then has to be declared explicitly.

### Other notes

`$readmemh` loads only 8 words into a 256-word memory and emits a "Not enough words in the file" warning, leaving the remaining locations as `x`. The tests only touch the first eight words, so the warning is expected rather than a failure.

Housekeeping: two working directories on this machine both pointed at the same remote, but their commit histories had diverged. `git fetch origin` confirmed which one matches the published `origin/main`; the other is a stale copy and is no longer in use. Worth recording as the same class of hazard as the accidentally deleted testbenches on Day 7 — nothing wrong with the design, everything wrong with the environment around it.
