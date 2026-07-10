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

Day 1 complete — toolchain verified end-to-end on Basys 3.

## Day 0 (2026-07-09)

- Initialized this Git repository.
- Created the project README.
- Set up the remote GitHub repository.

## Day 1 (2026-07-10)

- Board arrived; completed toolchain bring-up on Basys 3.
- Hit and resolved several environment issues along the way:
  AMD account profile incomplete (blocked device-file download),
  7 Series device support not installed (board silently disappeared
  from the New Project wizard), constraint file not actually added
  to the project (DRC failed with all 32 ports unconstrained).
- `rtl/led_passthrough.v`: minimal combinational design
  (`assign led = sw`) used purely to validate the toolchain.
- `constraints/basys3_led_test.xdc`: full switch/LED pin mapping
  for Basys3 rev B/C.
- Verified on hardware: synthesis → implementation → bitstream →
  JTAG program, toggling SW0–15 correctly drives LD0–15.

Toolchain confirmed working end-to-end.

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