# riscv-pipelined-fpga

Day-by-day build log for a 5-stage pipelined RISC-V (RV32I) core,
targeting a Digilent Basys 3 (Artix-7) FPGA. Verification is treated
as a first-class deliverable, not an afterthought — every module gets
a test plan and a self-checking testbench.

## Goal

Build a readable, well-tested RV32I pipelined core — hazard detection,
forwarding, control-hazard handling — that runs correctly both in
simulation and on real hardware.

## Status

Day 0 — environment setup, board not yet arrived (arrives tomorrow).

## Day 0 (2026-07-09)

- Installed Vivado ML Edition (WebPACK, free).
- Installed Icarus Verilog + GTKWave for fast local iteration.
- Installed Digilent cable drivers (`install_drivers_wrapper.bat`)
  and added Basys 3 board files from `Digilent/vivado-boards`.
- Set up this repo.
- Skimmed Harris & Harris ch.4 (HDLs) as warm-up for tomorrow.

Board arrives tomorrow — first hardware bring-up (LED blink test)
planned for Day 1.

## Repo structure

    /rtl          RTL source (Verilog)
    /tb           Testbenches
    /constraints  XDC constraint files
    /docs         Test plans, weekly notes, design docs

## Roadmap

- [ ] Verilog fundamentals + combinational/sequential basics
- [ ] Self-checking testbench conventions
- [ ] RV32I ALU, immediate generator, control unit
- [ ] Single-cycle datapath, integrated and verified
- [ ] Formal verification test plan + directed test suite
- [ ] Pipeline conversion, hazard detection, forwarding
- [ ] FPGA bring-up + demo
