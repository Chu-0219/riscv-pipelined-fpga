// ============================================================================
// tb_regfile.v -- self-checking testbench for the RV32I register file
//
// Run:
//   iverilog -o tb_regfile.vvp rtl/regfile.v tb/tb_regfile.v
//   vvp tb_regfile.vvp
//
// Expected result: 45/45 PASSED
// ============================================================================

`timescale 1ns / 1ps

module tb_regfile;

    reg         clk;
    reg         we;
    reg  [4:0]  rs1_addr;
    reg  [4:0]  rs2_addr;
    reg  [4:0]  rd_addr;
    reg  [31:0] rd_data;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    integer pass_count;
    integer fail_count;
    integer k;
    reg [31:0] expected;

    regfile dut (
        .clk      (clk),
        .we       (we),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // 10 ns clock
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

    // Drive one write on the next rising edge, then settle.
    task do_write;
        input [4:0]  addr;
        input [31:0] data;
        begin
            @(negedge clk);
            we      = 1'b1;
            rd_addr = addr;
            rd_data = data;
            @(posedge clk);
            #1;
            we = 1'b0;
        end
    endtask

    // ------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        we         = 1'b0;
        rs1_addr   = 5'd0;
        rs2_addr   = 5'd0;
        rd_addr    = 5'd0;
        rd_data    = 32'h0;

        $display("=== regfile testbench ===");

        // --------------------------------------------------------------
        // Phase 1: everything reads zero after init (3 checks)
        // --------------------------------------------------------------
        @(negedge clk);
        rs1_addr = 5'd0;  rs2_addr = 5'd1;  #1;
        check(rs1_data, 32'h0, "init x0 reads zero");
        check(rs2_data, 32'h0, "init x1 reads zero");
        rs1_addr = 5'd31; #1;
        check(rs1_data, 32'h0, "init x31 reads zero");

        // --------------------------------------------------------------
        // Phase 2: write to x0 is discarded (1 check)
        // --------------------------------------------------------------
        do_write(5'd0, 32'hDEAD_BEEF);
        rs1_addr = 5'd0; #1;
        check(rs1_data, 32'h0, "write to x0 discarded");

        // --------------------------------------------------------------
        // Phase 3: write x1..x31, then read them all back (31 checks)
        // --------------------------------------------------------------
        for (k = 1; k < 32; k = k + 1) begin
            do_write(k[4:0], 32'h1234_0000 + k);
        end
        for (k = 1; k < 32; k = k + 1) begin
            @(negedge clk);
            rs1_addr = k[4:0]; #1;
            expected = 32'h1234_0000 + k;
            check(rs1_data, expected, "readback x1..x31");
        end

        // --------------------------------------------------------------
        // Phase 4: both ports read different registers (2 checks)
        // --------------------------------------------------------------
        @(negedge clk);
        rs1_addr = 5'd1;  rs2_addr = 5'd31; #1;
        check(rs1_data, 32'h1234_0001, "port1 reads x1");
        check(rs2_data, 32'h1234_001F, "port2 reads x31");

        // --------------------------------------------------------------
        // Phase 5: both ports read the same register (2 checks)
        // --------------------------------------------------------------
        @(negedge clk);
        rs1_addr = 5'd7;  rs2_addr = 5'd7; #1;
        check(rs1_data, 32'h1234_0007, "port1 reads x7");
        check(rs2_data, 32'h1234_0007, "port2 reads x7 same cycle");

        // --------------------------------------------------------------
        // Phase 6: we = 0 blocks the write (1 check)
        // --------------------------------------------------------------
        @(negedge clk);
        we      = 1'b0;
        rd_addr = 5'd10;
        rd_data = 32'hFFFF_FFFF;
        @(posedge clk);
        #1;
        rs1_addr = 5'd10; #1;
        check(rs1_data, 32'h1234_000A, "we=0 does not write x10");

        // --------------------------------------------------------------
        // Phase 7: same-cycle read/write returns OLD value (2 checks)
        // --------------------------------------------------------------
        @(negedge clk);
        we       = 1'b1;
        rd_addr  = 5'd5;
        rd_data  = 32'hCAFE_0005;
        rs1_addr = 5'd5;
        #1;
        check(rs1_data, 32'h1234_0005, "same-cycle read sees OLD value");
        @(posedge clk);
        #1;
        we = 1'b0;
        check(rs1_data, 32'hCAFE_0005, "after edge read sees NEW value");

        // --------------------------------------------------------------
        // Phase 8: all-zero and all-one data patterns (2 checks)
        // --------------------------------------------------------------
        do_write(5'd31, 32'h0000_0000);
        rs1_addr = 5'd31; #1;
        check(rs1_data, 32'h0000_0000, "write all-zero to x31");

        do_write(5'd31, 32'hFFFF_FFFF);
        rs1_addr = 5'd31; #1;
        check(rs1_data, 32'hFFFF_FFFF, "write all-one to x31");

        // --------------------------------------------------------------
        // Phase 9: writing x0 does not corrupt neighbours (1 check)
        // --------------------------------------------------------------
        do_write(5'd0, 32'hAAAA_AAAA);
        rs1_addr = 5'd1; #1;
        check(rs1_data, 32'h1234_0001, "x0 write leaves x1 intact");

        // --------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------
        $display("=========================================");
        $display("RESULT: %0d/%0d PASSED, %0d FAILED",
                 pass_count, pass_count + fail_count, fail_count);
        $display("=========================================");
        $finish;
    end

endmodule
