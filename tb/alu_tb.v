// alu_tb.v -- alu.v 定向测试 (第2段 Day4)
// 自检式: 每条用例比对 result 和 zero, 末尾打印 PASS/FAIL 汇总
// 覆盖: 回绕/零/负数/移位掩码/signed分歧
`timescale 1ns/1ps

module alu_tb;

    localparam WIDTH = 8;

    // --- 操作码, 与 alu.v 对齐 ---
    localparam OP_ADD = 4'b0000;
    localparam OP_SUB = 4'b0001;
    localparam OP_AND = 4'b0010;
    localparam OP_OR  = 4'b0011;
    localparam OP_XOR = 4'b0100;
    localparam OP_SLT = 4'b0101;
    localparam OP_SLL = 4'b0110;
    localparam OP_SRL = 4'b0111;

    // --- DUT 端口 ---
    reg  [3:0]       alu_op;
    reg  [WIDTH-1:0] a, b;
    wire [WIDTH-1:0] result;
    wire             zero;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // --- 实例化 DUT ---
    alu #(.WIDTH(WIDTH)) dut (
        .alu_op (alu_op),
        .a      (a),
        .b      (b),
        .result (result),
        .zero   (zero)
    );

    // --- 自检 task: 一条清单 = 一次调用 ---
    // exp_result: 期望结果; exp_zero: 期望 zero 标志
    task check;
        input [3:0]       t_op;
        input [WIDTH-1:0] t_a, t_b;
        input [WIDTH-1:0] exp_result;
        input             exp_zero;
        begin
            alu_op = t_op;
            a      = t_a;
            b      = t_b;
            #1;  // 跨过 NBA/组合稳定区再采样
            if (result === exp_result && zero === exp_zero) begin
                pass_cnt = pass_cnt + 1;
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL: op=%b a=%h b=%h | result got=%h exp=%h | zero got=%b exp=%b",
                         t_op, t_a, t_b, result, exp_result, zero, exp_zero);
            end
        end
    endtask

    initial begin
        // ========== ADD ==========
        check(OP_ADD, 8'h7F, 8'h01, 8'h80, 1'b0); // 127+1 回绕
        check(OP_ADD, 8'h05, 8'hFB, 8'h00, 1'b1); // a+(-a)=0
        check(OP_ADD, 8'hFF, 8'h01, 8'h00, 1'b1); // 全1加1回绕
        check(OP_ADD, 8'h03, 8'h04, 8'h07, 1'b0); // 基准

        // ========== SUB ==========
        check(OP_SUB, 8'h08, 8'h08, 8'h00, 1'b1); // a-a=0 (beq路径)
        check(OP_SUB, 8'h00, 8'h01, 8'hFF, 1'b0); // 0-1 借位
        check(OP_SUB, 8'h05, 8'h03, 8'h02, 1'b0); // 基准

        // ========== AND ==========
        check(OP_AND, 8'hA5, 8'h00, 8'h00, 1'b1); // 与0清零
        check(OP_AND, 8'hA5, 8'hFF, 8'hA5, 1'b0); // 与全1=自己

        // ========== OR ==========
        check(OP_OR,  8'hA5, 8'h00, 8'hA5, 1'b0); // 或0=自己
        check(OP_OR,  8'h5A, 8'hFF, 8'hFF, 1'b0); // 或全1=全1

        // ========== XOR ==========
        check(OP_XOR, 8'hA5, 8'hA5, 8'h00, 1'b1); // 自消=0
        check(OP_XOR, 8'hA5, 8'hFF, 8'h5A, 1'b0); // 异或全1=取反

        // ========== SLT (有符号) ==========
        check(OP_SLT, 8'hFF, 8'h01, 8'h01, 1'b0); // -1<1 真, 抓$signed
        check(OP_SLT, 8'h7F, 8'h80, 8'h00, 1'b1); // 127<-128 假, 反向抓
        check(OP_SLT, 8'h80, 8'hFF, 8'h01, 1'b0); // -128<-1 真
        check(OP_SLT, 8'h05, 8'h05, 8'h00, 1'b1); // 相等→不小于→0

        // ========== SLL ==========
        check(OP_SLL, 8'h01, 8'h00, 8'h01, 1'b0); // 移0位
        check(OP_SLL, 8'h01, 8'h07, 8'h80, 1'b0); // 移7位到最高
        check(OP_SLL, 8'h80, 8'h01, 8'h00, 1'b1); // 最高位移出界
        check(OP_SLL, 8'h01, 8'h08, 8'h01, 1'b0); // 掩码: b[2:0]=0

        // ========== SRL (逻辑, 补0) ==========
        check(OP_SRL, 8'h80, 8'h00, 8'h80, 1'b0); // 移0位
        check(OP_SRL, 8'h80, 8'h01, 8'h40, 1'b0); // 补0不补符号→0x40
        check(OP_SRL, 8'h01, 8'h01, 8'h00, 1'b1); // 最低位移出界
        check(OP_SRL, 8'h80, 8'h08, 8'h80, 1'b0); // 掩码: b[2:0]=0

        // ========== 汇总 ==========
        $display("-------------------------------------");
        $display("ALU TB done: %0d PASS, %0d FAIL (total %0d)",
                 pass_cnt, fail_cnt, pass_cnt + fail_cnt);
        if (fail_cnt == 0)
            $display("ALL PASS");
        else
            $display(">>> %0d CASE(S) FAILED <<<", fail_cnt);
        $finish;
    end

endmodule