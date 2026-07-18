`timescale 1ns/1ps

module seq_detect_moore_tb;

    // -------- 信号声明 --------
    reg  clk, rst, x;
    wire y;

    // -------- 例化DUT --------
    seq_detect_moore uut (
        .clk(clk),
        .rst(rst),
        .x(x),
        .y(y)
    );

    // -------- 生成时钟 --------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------- 统计变量 --------
    integer pass_count = 0;
    integer fail_count = 0;

    // -------- task: 喂一位输入,等一个时钟沿 --------
    task apply_bit;
        input bit_in;
        begin
            x = bit_in;
            @(posedge clk);
            #1;
        end
    endtask

    // -------- function: 比较期望值和实际值 --------
    function integer check_equal;
        input expected, actual;
        begin
            if (expected === actual)
                check_equal = 1;
            else
                check_equal = 0;
        end
    endfunction

    // -------- task: 喂一位并自动检查+计数+打印 --------
    task check_bit;
        input bit_in;
        input expected_y;
        begin
            apply_bit(bit_in);
            if (check_equal(expected_y, y)) begin
                pass_count = pass_count + 1;
                $display("t=%0t PASS: x=%b -> y=%b (expected %b)", $time, bit_in, y, expected_y);
            end else begin
                fail_count = fail_count + 1;
                $display("t=%0t FAIL: x=%b -> y=%b (expected %b)", $time, bit_in, y, expected_y);
            end
        end
    endtask

    // -------- 主测试流程 --------
    initial begin
        rst = 1; x = 0;
        #12;
        rst = 0;

        // 测试用例1: "1101101",预期第4位、第7位命中(重叠匹配)
        // x:      1 1 0 1 1 0 1
        // 预期y:  0 0 0 1 0 0 1
        check_bit(1, 0);
        check_bit(1, 0);
        check_bit(0, 0);
        check_bit(1, 1);
        check_bit(1, 0);
        check_bit(0, 0);
        check_bit(1, 1);

        // 测试用例2: 复位后测一条不含"1101"的序列 "01001",全程应为0
        rst = 1; #12; rst = 0;
        check_bit(0, 0);
        check_bit(1, 0);
        check_bit(0, 0);
        check_bit(0, 0);
        check_bit(1, 0);

        // -------- 汇总 --------
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