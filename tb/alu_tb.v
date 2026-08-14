`timescale 1ns/1ps
//============================================================================
// alu_tb.v  --  alu.v 定向测试 (第3段版本)
//
// 结构沿用第2段：自检式，每条用例比对 result 与 zero，末尾打印汇总。
// 改动：位宽 8 -> 32，所有向量按 32 位重算；新增 SRA / SLTU / LUI 用例。
//
// 覆盖：回绕 / 零 / 负数 / 移位掩码 / signed-unsigned 分歧 / 算术-逻辑右移分歧
//============================================================================

module alu_tb;

    // --- 操作码, 与 alu.v 对齐 ---
    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b0001;
    localparam OP_AND  = 4'b0010;
    localparam OP_OR   = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_SLT  = 4'b0101;
    localparam OP_SLL  = 4'b0110;
    localparam OP_SRL  = 4'b0111;
    localparam OP_SRA  = 4'b1000;
    localparam OP_SLTU = 4'b1001;
    localparam OP_LUI  = 4'b1010;

    // --- DUT 端口 ---
    reg  [3:0]  alu_op;
    reg  [31:0] a, b;
    wire [31:0] result;
    wire        zero;

    integer pass_cnt;
    integer fail_cnt;

    alu dut (
        .alu_op (alu_op),
        .a      (a),
        .b      (b),
        .result (result),
        .zero   (zero)
    );

    // --- 自检 task: 一条清单 = 一次调用 ---
    task check;
        input [3:0]  t_op;
        input [31:0] t_a, t_b;
        input [31:0] exp_result;
        input        exp_zero;
        begin
            alu_op = t_op;
            a      = t_a;
            b      = t_b;
            #1;  // 跨过组合稳定区再采样
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
        pass_cnt = 0;
        fail_cnt = 0;

        // ========== ADD ==========
        check(OP_ADD, 32'h7FFFFFFF, 32'h00000001, 32'h80000000, 1'b0); // 最大正数+1 回绕
        check(OP_ADD, 32'h00000005, 32'hFFFFFFFB, 32'h00000000, 1'b1); // a+(-a)=0
        check(OP_ADD, 32'hFFFFFFFF, 32'h00000001, 32'h00000000, 1'b1); // 全1加1回绕
        check(OP_ADD, 32'h00000003, 32'h00000004, 32'h00000007, 1'b0); // 基准

        // ========== SUB ==========
        check(OP_SUB, 32'h00000008, 32'h00000008, 32'h00000000, 1'b1); // a-a=0 (beq 路径)
        check(OP_SUB, 32'h00000000, 32'h00000001, 32'hFFFFFFFF, 1'b0); // 0-1 借位
        check(OP_SUB, 32'h00000005, 32'h00000003, 32'h00000002, 1'b0); // 基准

        // ========== AND ==========
        check(OP_AND, 32'hA5A5A5A5, 32'h00000000, 32'h00000000, 1'b1); // 与0清零
        check(OP_AND, 32'hA5A5A5A5, 32'hFFFFFFFF, 32'hA5A5A5A5, 1'b0); // 与全1=自己

        // ========== OR ==========
        check(OP_OR,  32'hA5A5A5A5, 32'h00000000, 32'hA5A5A5A5, 1'b0); // 或0=自己
        check(OP_OR,  32'h5A5A5A5A, 32'hFFFFFFFF, 32'hFFFFFFFF, 1'b0); // 或全1=全1

        // ========== XOR ==========
        check(OP_XOR, 32'hA5A5A5A5, 32'hA5A5A5A5, 32'h00000000, 1'b1); // 自消=0
        check(OP_XOR, 32'hA5A5A5A5, 32'hFFFFFFFF, 32'h5A5A5A5A, 1'b0); // 异或全1=取反

        // ========== SLT (有符号) ==========
        check(OP_SLT, 32'hFFFFFFFF, 32'h00000001, 32'h00000001, 1'b0); // -1<1 真, 抓 $signed
        check(OP_SLT, 32'h7FFFFFFF, 32'h80000000, 32'h00000000, 1'b1); // max < min 假, 反向抓
        check(OP_SLT, 32'h80000000, 32'hFFFFFFFF, 32'h00000001, 1'b0); // -2^31 < -1 真
        check(OP_SLT, 32'h00000005, 32'h00000005, 32'h00000000, 1'b1); // 相等 -> 不小于 -> 0

        // ========== SLTU (无符号, 新增) ==========
        // 前两条与 SLT 用同一组输入但期望相反 -- 专抓有符号/无符号混用
        check(OP_SLTU, 32'hFFFFFFFF, 32'h00000001, 32'h00000000, 1'b1); // 无符号下 0xFFFFFFFF 是最大值
        check(OP_SLTU, 32'h00000001, 32'hFFFFFFFF, 32'h00000001, 1'b0);
        check(OP_SLTU, 32'h7FFFFFFF, 32'h80000000, 32'h00000001, 1'b0); // 与 SLT 同输入, 结果相反
        check(OP_SLTU, 32'h00000005, 32'h00000005, 32'h00000000, 1'b1); // 相等

        // ========== SLL ==========
        check(OP_SLL, 32'h00000001, 32'h00000000, 32'h00000001, 1'b0); // 移0位
        check(OP_SLL, 32'h00000001, 32'h0000001F, 32'h80000000, 1'b0); // 移31位到最高
        check(OP_SLL, 32'h80000000, 32'h00000001, 32'h00000000, 1'b1); // 最高位移出界
        check(OP_SLL, 32'h00000001, 32'h00000020, 32'h00000001, 1'b0); // 掩码: b[4:0]=0

        // ========== SRL (逻辑右移, 补0) ==========
        check(OP_SRL, 32'h80000000, 32'h00000000, 32'h80000000, 1'b0); // 移0位
        check(OP_SRL, 32'h80000000, 32'h00000001, 32'h40000000, 1'b0); // 补0不补符号
        check(OP_SRL, 32'h00000001, 32'h00000001, 32'h00000000, 1'b1); // 最低位移出界
        check(OP_SRL, 32'h80000000, 32'h00000020, 32'h80000000, 1'b0); // 掩码: b[4:0]=0

        // ========== SRA (算术右移, 补符号位, 新增) ==========
        // 第一条与 SRL 用同一组输入但期望不同 -- 专抓 >>> 退化成 >> 的坑
        check(OP_SRA, 32'h80000000, 32'h00000001, 32'hC0000000, 1'b0); // 补1不补0
        check(OP_SRA, 32'hFFFFFFFF, 32'h0000001F, 32'hFFFFFFFF, 1'b0); // -1 右移仍是 -1
        check(OP_SRA, 32'h7FFFFFFF, 32'h0000001F, 32'h00000000, 1'b1); // 正数补0
        check(OP_SRA, 32'h80000000, 32'h00000020, 32'h80000000, 1'b0); // 掩码: b[4:0]=0

        // ========== LUI (直通 b, 新增) ==========
        check(OP_LUI, 32'hDEADBEEF, 32'h12345000, 32'h12345000, 1'b0); // 忽略 a
        check(OP_LUI, 32'hFFFFFFFF, 32'h00000000, 32'h00000000, 1'b1); // b=0 -> zero=1

        // ========== default (未定义操作码) ==========
        check(4'b1111, 32'hA5A5A5A5, 32'h5A5A5A5A, 32'h00000000, 1'b1);

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
