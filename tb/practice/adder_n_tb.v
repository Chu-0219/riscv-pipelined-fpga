`timescale 1ns/1ps
module adder_n_tb;

reg  [7:0] a, b;
reg        cin;
wire [7:0] sum;
wire       cout;

reg [8:0] expected;

adder_n #(.WIDTH(8)) uut (
    .a   (a),
    .b   (b),
    .cin (cin),
    .sum (sum),
    .cout(cout)
);

integer pass_count, fail_count;
integer i;

task run_test;
    input [7:0] ta, tb;
    input       tcin;
    begin
        a = ta; b = tb; cin = tcin;
        #10;

        expected = ta + tb + tcin;

        if ({cout, sum} == expected) begin
            pass_count = pass_count + 1;
            $display("PASS: a=%0d b=%0d cin=%0d -> sum=%0d cout=%0d", ta, tb, tcin, sum, cout);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: a=%0d b=%0d cin=%0d -> got sum=%0d cout=%0d, expected %0d",
                       ta, tb, tcin, sum, cout, expected);
        end
    end
endtask

initial begin
    $dumpfile("sim.vcd");
    $dumpvars(0, adder_n_tb);

    pass_count = 0; fail_count = 0;

    // 基本用例
    run_test(8'd0, 8'd0, 1'b0);      // 0+0+0 = 0, cout=0
    run_test(8'd5, 8'd3, 1'b0);      // 5+3+0 = 8, cout=0

    // 边界/溢出用例：8位最大值255 + 1，应该 sum=0, cout=1
    run_test(8'd255, 8'd1, 1'b0);

    // 随机测试
    for (i = 0; i < 20; i = i + 1) begin
        run_test($random, $random, $random);
    end

    $display("---- SUMMARY: %0d PASS, %0d FAIL ----", pass_count, fail_count);
    $finish;
end

endmodule