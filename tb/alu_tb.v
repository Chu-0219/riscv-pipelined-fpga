// alu_tb.v -- ALU 冒烟测试 (Day 4 将扩建为完整定向测试)
// 今日仅验证: 每个操作各1组基本用例 + SLT有符号陷阱1例
`timescale 1ns/1ps

module alu_tb;

    localparam WIDTH = 8;

    reg  [3:0]        alu_op;
    reg  [WIDTH-1:0]  a, b;
    wire [WIDTH-1:0]  result;
    wire              zero;

    integer errors = 0;

    alu #(.WIDTH(WIDTH)) dut (
        .alu_op(alu_op), .a(a), .b(b),
        .result(result), .zero(zero)
    );

    task check;
        input [3:0]       op;
        input [WIDTH-1:0] ta, tb, expected;
        input [8*24-1:0]  msg;
        begin
            alu_op = op; a = ta; b = tb;
            #1;   // 组合逻辑传播
            if (result !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s a=%h b=%h expected=%h got=%h",
                         msg, ta, tb, expected, result);
            end else
                $display("PASS: %0s result=%h", msg, result);
        end
    endtask

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        check(4'b0000, 8'h03, 8'h05, 8'h08, "ADD");
        check(4'b0001, 8'h0A, 8'h03, 8'h07, "SUB");
        check(4'b0010, 8'hF0, 8'hAA, 8'hA0, "AND");
        check(4'b0011, 8'hF0, 8'h0A, 8'hFA, "OR");
        check(4'b0100, 8'hFF, 8'h0F, 8'hF0, "XOR");
        check(4'b0101, 8'h02, 8'h05, 8'h01, "SLT basic");
        // 有符号陷阱: -1 < 1 应为真 (无符号会判 255<1 为假)
        check(4'b0101, 8'hFF, 8'h01, 8'h01, "SLT signed trap");
        check(4'b0110, 8'h01, 8'h03, 8'h08, "SLL");
        check(4'b0111, 8'h80, 8'h03, 8'h10, "SRL");

        // zero 标志: 5-5=0
        alu_op = 4'b0001; a = 8'h05; b = 8'h05; #1;
        if (zero !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: zero flag");
        end else
            $display("PASS: zero flag");

        $display("=====================================");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("=====================================");
        $finish;
    end

endmodule