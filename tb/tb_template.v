// 可复用testbench模板
// 使用方法:
// 1. 把 DUT_NAME 全部替换成你要测的模块名
// 2. 按DUT的端口补充信号声明和例化
// 3. 在主测试流程里写你自己的测试用例

`timescale 1ns/1ps

module DUT_NAME_tb;

    // -------- 信号声明(按DUT端口改) --------
    reg  clk, rst;
    // TODO: 补充其他输入的 reg 声明
    // TODO: 补充输出的 wire 声明

    // -------- 例化DUT(改成你的模块名和端口) --------
    // DUT_NAME uut (
    //     .clk(clk),
    //     .rst(rst),
    //     ...
    // );

    // -------- 生成时钟(通用,一般不用改) --------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------- 统计变量(通用) --------
    integer pass_count = 0;
    integer fail_count = 0;

    // -------- function: 比较期望值和实际值 --------
    function integer check_equal;
        input expected, actual;   // TODO: 比较多位信号时要加位宽,如 input [N-1:0] expected, actual;
        begin
            if (expected === actual)
                check_equal = 1;
            else
                check_equal = 0;
        end
    endfunction

    // -------- 主测试流程 --------
    initial begin
        rst = 1;
        // TODO: 给其他输入赋初值
        #12;
        rst = 0;

        // TODO: 测试用例
        // 通用套路: 驱动输入 -> @(posedge clk); -> check_equal比对输出 -> 计数+打印

        // -------- 汇总(通用) --------
        $display("--------------------------------------------------");
        $display("TEST SUMMARY: %0d PASS, %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED - CHECK LOG ABOVE");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule