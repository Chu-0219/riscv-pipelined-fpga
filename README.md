# riscv-pipelined-fpga

A from-scratch RV32I processor core in Verilog. Every module is hand-written RTL and covered by a self-checking testbench — verification is treated as a first-class deliverable, not an afterthought.

- **Goal** — a 5-stage pipelined RV32I core, with hazard detection and forwarding, running on a Digilent Basys 3 (Artix-7) board.
- **Where it is today** — the datapath and control modules are written and verified individually; the ALU has additionally been synthesised and tested on real hardware. Single-cycle top-level integration is in progress. Pipelining has not started yet.

The repository name describes the goal. The table below describes today.

---

## Status (updated 2026-08-18)

| Done & verified | In progress | Planned (after Sep 2026) |
| --- | --- | --- |
| `alu.v` — 32-bit ALU, incl. SRA / SLTU / LUI (36/36 checks pass); synthesised and verified on a Basys 3 board — arithmetic, logic, shift, comparison and the zero flag all exercised through switches/LEDs (81 LUTs, 1% of the device) | Single-cycle top-level integration: PC logic, instruction & data memory, full module wiring | Pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) |
| `regfile.v` — parameterised register file, 2 async reads / 1 sync write, 8×8 as instantiated (21/21 checks pass) | | Hazard detection & forwarding |
| `imm_gen.v` — all five RV32I immediate formats (26/26 checks pass) | | Branch flush logic |
| `decoder.v` — main decoder + ALU decoder (26/26 checks pass) | | On-board demo of the full core |
| `alu_regfile_top.v` — ALU + register file integration (8/8 checks pass) | | |
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
iverilog -g2012 -o build/imm_gen_tb.vvp rtl/imm_gen.v tb/imm_gen_tb.v   # compile
vvp build/imm_gen_tb.vvp                                                # run, prints PASS/FAIL + summary
gtkwave build/imm_gen_tb.vcd                                            # optional: inspect waveform
```

Swap the module and testbench names to run any other unit — `alu`, `regfile`, `decoder`.

Example run — `regfile_tb` (21 checks, output elided in the middle):

```
VCD info: dumpfile regfile_tb.vcd opened for output.
PASS: T1 port1 readback  value=0a
PASS: T1 port1 readback  value=1a
...                                    (T1 sweeps all 8 registers on port 1)
PASS: T1 port1 readback  value=7a
PASS: T2 port2 readback  value=0a
...                                    (T2 sweeps all 8 registers on port 2)
PASS: T2 port2 readback  value=7a
PASS: T3 port1 addr2  value=2a
PASS: T3 port2 addr5  value=5a
PASS: T4 write disabled  value=2a
PASS: T5a after edge: new value visible  value=99
PASS: T5b persisted  value=99
=====================================
ALL TESTS PASSED
=====================================
tb/regfile_tb.v:124: $finish called at 131000 (1ps)
```

Full logs for every module are committed under `logs/`.

---

## Repository layout

```
rtl/                core modules
rtl/practice/       early Verilog exercises, kept as a record of the learning path
tb/                 self-checking testbenches for the core modules
tb/practice/        testbenches for the exercises
constraints/        XDC constraint files (Basys 3)
docs/build-log.md   day-by-day build log, including bugs hit and how they were found
docs/images/        board photos from on-board testing
logs/               captured simulation output from the self-checking testbenches
```

---

## Roadmap

1. Single-cycle integration — connect all modules, run a hand-assembled test program (arithmetic → branch → load/store) and check every instruction against a hand-computed expectation.
2. Insert pipeline registers, split the datapath into five stages.
3. Hazard detection and forwarding.
4. Branch flush logic.
5. Basys 3 bring-up of the full core (the ALU alone is already synthesised and tested on board; constraints are in constraints/).

---

## Known limitations

- The core is not yet integrated; the modules above are verified in isolation, plus one ALU + register file integration.
- The register file is a generic parameterised design (8×8 as currently instantiated) and does not yet implement the RV32I `x0`-hardwired-to-zero rule. Widening to 32×32 and adding `x0` handling is the next step, part of single-cycle integration.
- `alu_regfile_top.v` is an 8-bit datapath from an earlier stage. Since `alu.v` was later rewritten as fixed 32-bit, the integration zero-extends its inputs and truncates its output — explicitly, not by relying on Verilog's implicit width conversion. Arithmetic and bitwise results are correct within 8 bits, but signed operations (SLT, SRA) change meaning under zero-extension. This module will be rewritten during single-cycle integration.
- Instruction and data memory are behavioural models loaded with `$readmemh`, not FPGA block RAM.
- No pipelining, therefore no hazard handling yet. Control hazards in particular are a known open item, planned as step 4 above.
- RV32I base integer instruction set only. No CSRs, no interrupts, no multiply/divide extension.
