# riscv-pipelined-fpga

A from-scratch RV32I processor core in Verilog. Every module is hand-written RTL and covered by a self-checking testbench — verification is treated as a first-class deliverable, not an afterthought.

- **Goal** — a 5-stage pipelined RV32I core, with hazard detection and forwarding, running on a Digilent Basys 3 (Artix-7) board.
- **Where it is today** — the single-cycle core is integrated and running: all eight modules are wired into one datapath and pass a 35-check top-level testbench driven by a hand-assembled 35-instruction program covering arithmetic, shifts, signed/unsigned comparison, load/store, all branch forms, and both jump instructions. Every module is also verified in isolation, and the ALU has been synthesised and tested on real hardware. Pipelining has not started yet.
The repository name describes the goal. The table below describes today.

---

## Status (updated 2026-08-23)

| Done & verified | In progress | Planned (after Sep 2026) |
| --- | --- | --- |
| `top.v` — **single-cycle core, fully integrated** (35/35 checks pass): 35-instruction program run to completion, all 32 registers, data memory and final PC checked against hand-computed values | | |
| `alu.v` — 32-bit ALU, incl. SRA / SLTU / LUI (36/36 checks pass); synthesised and verified on a Basys 3 board — arithmetic, logic, shift, comparison and the zero flag all exercised through switches/LEDs (81 LUTs, 1% of the device) | Byte and half-word memory accesses (`lb` / `lh` / `sb` / `sh`) | Pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) |
| `regfile.v` — 32×32 register file, 2 async reads / 1 sync write, `x0` hardwired to zero on both read and write ports (45/45 checks pass) | | || `imm_gen.v` — all five RV32I immediate formats (26/26 checks pass) | | |
| `decoder.v` — main decoder + ALU decoder (26/26 checks pass) | | On-board demo of the full core |
| `alu_regfile_top.v` — ALU + register file integration (8/8 checks pass) | | |
| `pc_unit.v` — PC register, PC+4, branch target, and JALR target with the low bit cleared per the RV32I spec (14/14 checks pass) | | || `imem.v` — instruction memory, combinational read, word-addressed (10/10 checks pass) | | |
| `dmem.v` — data memory, synchronous write / combinational read (10/10 checks pass) | | |
| Full Vivado flow verified end-to-end on Basys 3 — RTL → synthesis → implementation → bitstream → on-board test | | |

*"Verified" means the module has a testbench in `tb/` that applies a fixed stimulus set, compares each result against an expected value computed inside the testbench, prints PASS/FAIL per case, and ends with a pass/total summary. No manual waveform inspection is needed to know whether a module still works.*

---

## Architecture (single-cycle, current integration target)

```
  PC ──► Instruction Memory ──┬──► Decoder ──────► control signals ──┐
   ▲                          │                                      │
   │                          ├──► ImmGen ───────► immediate ─────┐   │
   │                          │                                   ▼   ▼
   │                          └──► Register File ──► rs1/rs2 ──► ALU (32-bit)
   │                                    ▲                            │
   │                                    │                            ▼
   │                                    │                       Data Memory
   │                                    │                            │
   │                                    └────── write-back ◄─────────┘
   │
   └──── PC+4 / branch target ◄──────────────────────────────────────
```

---

## Build & simulate

Toolchain: [Icarus Verilog](https://steveicarus.github.io/iverilog/) + GTKWave for simulation, Vivado for synthesis and board bring-up.

```bash
# any single module
iverilog -g2012 -o build/imm_gen_tb.vvp rtl/imm_gen.v tb/imm_gen_tb.v
vvp build/imm_gen_tb.vvp

# the whole core (prog.hex is read from the working directory)
iverilog -g2012 -o build/top_tb.vvp rtl/top.v rtl/pc_unit.v rtl/imem.v \
         rtl/decoder.v rtl/imm_gen.v rtl/regfile.v rtl/alu.v rtl/dmem.v \
         tb/top_tb.v
vvp build/top_tb.vvp
vvp build/top_tb.vvp +trace   # optional: per-cycle instruction trace                                          # optional: inspect waveform
```

Swap the module and testbench names to run any other unit — `alu`, `regfile`, `decoder`.

Branch and jump correctness is checked without inspecting waveforms: each taken
branch is followed by an instruction writing a sentinel value to an otherwise
unused register. If the branch resolves correctly that instruction is skipped
and the register stays zero, so control-flow behaviour becomes an ordinary
data-flow assertion the testbench can evaluate on its own.

Example run — `top_tb` (35 checks, output elided in the middle):
Full logs for every module are committed under `logs/`.

---

## Repository layout

```
rtl/                core modules
rtl/practice/       early Verilog exercises, kept as a record of the learning path
tb/                 self-checking testbenches for the core modules
tb/practice/        testbenches for the exercises
prog.hex            hand-assembled test program loaded by the instruction memory
constraints/        XDC constraint files (Basys 3)
docs/build-log.md   day-by-day build log, including bugs hit and how they were found
docs/images/        board photos from on-board testing
logs/               captured simulation output from the self-checking testbenches
```

---

## Roadmap

1. Insert pipeline registers, split the datapath into five stages.
2. Hazard detection and forwarding.
3. Basys 3 bring-up of the full core (the ALU alone is already synthesised and tested on board; constraints are in constraints/).

---

## Known limitations

- The core is not yet integrated; the modules above are verified in isolation, plus one ALU + register file integration.
- The register file is a generic parameterised design (8×8 as currently instantiated) and does not yet implement the RV32I `x0`-hardwired-to-zero rule. Widening to 32×32 and adding `x0` handling is the next step, part of single-cycle integration.
- `alu_regfile_top.v` is an 8-bit datapath from an earlier stage. Since `alu.v` was later rewritten as fixed 32-bit, the integration zero-extends its inputs and truncates its output — explicitly, not by relying on Verilog's implicit width conversion. Arithmetic and bitwise results are correct within 8 bits, but signed operations (SLT, SRA) change meaning under zero-extension. This module will be rewritten during single-cycle integration.
- Instruction and data memory are behavioural models loaded with `$readmemh`, not FPGA block RAM.
- Data memory supports word accesses only. Byte and half-word accesses (`sb` / `sh` / `lb` / `lh`) need byte enables and `funct3`-driven sign extension, and are not implemented yet.
- No pipelining, therefore no hazard handling yet. Control hazards in particular are a known open item, planned as step 4 above.
- RV32I base integer instruction set only. No CSRs, no interrupts, no multiply/divide extension.
- `pc_unit.v` computes branch targets as `PC + imm`. JALR requires `rs1 + imm` and needs a separate path, to be added during top-level integration.