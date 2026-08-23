// ============================================================================
// top_tb.v -- self-checking testbench for the single-cycle RV32I core
//
// Run from the repository root (prog.hex must be in the working directory):
//   iverilog -o top_tb.vvp rtl/top.v rtl/pc_unit.v rtl/imem.v rtl/decoder.v \
//            rtl/imm_gen.v rtl/regfile.v rtl/alu.v rtl/dmem.v tb/top_tb.v
//   vvp top_tb.vvp
//
// The program runs to a self-loop at 0x88. Register and memory contents are
// then checked against hand-computed expected values. Registers written only
// by instructions that a correctly taken branch skips must remain zero: that
// is how branch and jump behaviour is verified.
//
// Expected result: 35/35 PASSED
// ============================================================================

`timescale 1ns / 1ps

module top_tb;

    reg clk;
    reg rst;

    wire [31:0] dbg_pc;
    wire [31:0] dbg_instr;
    wire [31:0] dbg_alu_result;
    wire [31:0] dbg_wb_data;
    wire        dbg_reg_write;

    integer pass_count;
    integer fail_count;

    top dut (
        .clk            (clk),
        .rst            (rst),
        .dbg_pc         (dbg_pc),
        .dbg_instr      (dbg_instr),
        .dbg_alu_result (dbg_alu_result),
        .dbg_wb_data    (dbg_wb_data),
        .dbg_reg_write  (dbg_reg_write)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Checker
    // ------------------------------------------------------------------
    task check;
        input [31:0] got;
        input [31:0] want;
        input [8*40:1] label;
        begin
            if (got === want) begin
                pass_count = pass_count + 1;
                $display("PASS  %0s  got=%h", label, got);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL  %0s  got=%h  expected=%h", label, got, want);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Optional instruction trace. Set +trace on the vvp command line.
    // ------------------------------------------------------------------
    reg trace_on;
    initial begin
        trace_on = $test$plusargs("trace");
    end

    always @(posedge clk) begin
        if (!rst && trace_on) begin
            $display("  [trace] pc=%h  instr=%h  alu=%h  wb=%h  rw=%b",
                     dbg_pc, dbg_instr, dbg_alu_result, dbg_wb_data,
                     dbg_reg_write);
        end
    end

    // ------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        rst        = 1'b1;

        $display("=== single-cycle core testbench ===");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // 35 instructions in the image, 6 of them skipped by taken branches
        // and jumps, so 29 executed. 50 cycles leaves ample margin, and the
        // self-loop at 0x88 makes overshoot harmless.
        repeat (50) @(posedge clk);
        #1;

        $display("--- register file ---");

        check(dut.u_regfile.regs[0],  32'h0000_0000, "x0  hardwired zero");
        check(dut.u_regfile.regs[1],  32'd10,        "x1  addi 10");
        check(dut.u_regfile.regs[2],  32'd20,        "x2  addi 20");
        check(dut.u_regfile.regs[3],  32'd30,        "x3  add");
        check(dut.u_regfile.regs[4],  32'd10,        "x4  sub");
        check(dut.u_regfile.regs[5],  32'd0,         "x5  and");
        check(dut.u_regfile.regs[6],  32'd30,        "x6  or");
        check(dut.u_regfile.regs[7],  32'd30,        "x7  xor");
        check(dut.u_regfile.regs[8],  32'd1,         "x8  slt");
        check(dut.u_regfile.regs[9],  32'd30,        "x9  lw");
        check(dut.u_regfile.regs[10], 32'd0,         "x10 beq skipped it");
        check(dut.u_regfile.regs[11], 32'd7,         "x11 addi 7");
        check(dut.u_regfile.regs[12], 32'd0,         "x12 bne skipped it");
        check(dut.u_regfile.regs[13], 32'h1234_5000, "x13 lui");
        check(dut.u_regfile.regs[14], 32'h0000_0040, "x14 auipc");
        check(dut.u_regfile.regs[15], 32'h0000_0048, "x15 jal link addr");
        check(dut.u_regfile.regs[16], 32'd0,         "x16 jal skipped it");
        check(dut.u_regfile.regs[17], 32'h0000_0058, "x17 addi 0x58");
        check(dut.u_regfile.regs[18], 32'h0000_0054, "x18 jalr link addr");
        check(dut.u_regfile.regs[19], 32'd0,         "x19 jalr skipped it");
        check(dut.u_regfile.regs[20], 32'd42,        "x20 addi 42");
        check(dut.u_regfile.regs[21], 32'hFFFF_FFFF, "x21 addi -1 sign ext");
        check(dut.u_regfile.regs[22], 32'h003F_FFFF, "x22 srl logical");
        check(dut.u_regfile.regs[23], 32'hFFFF_FFFF, "x23 sra arithmetic");
        check(dut.u_regfile.regs[24], 32'h0000_2800, "x24 sll");
        check(dut.u_regfile.regs[25], 32'd0,         "x25 sltu unsigned");
        check(dut.u_regfile.regs[26], 32'd1,         "x26 slt signed");
        check(dut.u_regfile.regs[27], 32'd0,         "x27 blt skipped it");
        check(dut.u_regfile.regs[28], 32'd0,         "x28 bge skipped it");
        check(dut.u_regfile.regs[29], 32'd1,         "x29 addi 1");
        check(dut.u_regfile.regs[30], 32'd0,         "x30 never written");
        check(dut.u_regfile.regs[31], 32'd0,         "x31 never written");

        $display("--- data memory ---");
        check(dut.u_dmem.mem[0], 32'd30, "dmem[0] sw stored x3");

        $display("--- program counter ---");
        check(dbg_pc, 32'h0000_0088, "pc parked at halt loop");

        // Still parked ten cycles later: the self-loop really is a fixed point.
        repeat (10) @(posedge clk);
        #1;
        check(dbg_pc, 32'h0000_0088, "pc still at halt after 10 more cycles");

        $display("=========================================");
        $display("RESULT: %0d/%0d PASSED, %0d FAILED",
                 pass_count, pass_count + fail_count, fail_count);
        $display("=========================================");
        $finish;
    end

endmodule
