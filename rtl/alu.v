`timescale 1ns / 1ps
//============================================================================
// alu.v  --  RV32I ALU (第3段版本)
//
// 相对第2段的改动：
//   1. 位宽固定 32，去掉 WIDTH / SH_W 参数
//   2. 新增 SRA (算术右移)、SLTU (无符号比较)、LUI (直通 b)
//   3. 移位量掩码由 b[SH_W-1:0] 改为 b[4:0]
//   编码表与第2段完全一致，0000~0111 原样保留，新操作追加在 1000 之后。
//
// 为什么去掉参数化：
//   $clog2(WIDTH) 只在 WIDTH 是 2 的幂时给出正确的移位量位宽，
//   传入 WIDTH=33 之类的值会静默算错。RV32I 位宽恒为 32，
//   参数化在这里是风险不是收益，直接写死 [4:0] 更安全也更好读。
//
// 纯组合逻辑，无时钟无复位。
//============================================================================

module alu (
    input      [3:0]  alu_op,
    input      [31:0] a,
    input      [31:0] b,
    output reg [31:0] result,
    output            zero
);

    //------------------------------------------------------------------------
    // 操作码编码（0000~0111 与第2段一致，勿改动，decoder.v 与之对齐）
    //------------------------------------------------------------------------
    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b0001;
    localparam OP_AND  = 4'b0010;
    localparam OP_OR   = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_SLT  = 4'b0101;   // 有符号小于
    localparam OP_SLL  = 4'b0110;
    localparam OP_SRL  = 4'b0111;   // 逻辑右移，高位补 0
    // ---- 第3段新增 ----
    localparam OP_SRA  = 4'b1000;   // 算术右移，高位补符号位
    localparam OP_SLTU = 4'b1001;   // 无符号小于
    localparam OP_LUI  = 4'b1010;   // 直通 b，供 lui 使用

    always @(*) begin
        case (alu_op)

            OP_ADD:  result = a + b;
            OP_SUB:  result = a - b;
            OP_AND:  result = a & b;
            OP_OR:   result = a | b;
            OP_XOR:  result = a ^ b;

            // SLT / SLTU：结果是 0 或 1，其余位补 0
            // $signed() 把操作数按补码解释；不加则按无符号比较，
            // 0xFFFFFFFF 会被当成 42 亿而不是 -1
            OP_SLT:  result = {31'b0, ($signed(a) < $signed(b))};
            OP_SLTU: result = {31'b0, (a < b)};

            // 移位量只取 b[4:0]（0~31）
            // RV32I 规定移位量超过 31 时取低 5 位，不是饱和也不是清零
            OP_SLL:  result = a << b[4:0];
            OP_SRL:  result = a >> b[4:0];

            // 算术右移必须写成 $signed(a) >>> shamt
            // 只写 a >>> b[4:0] 得到的仍是逻辑右移——因为 a 声明为无符号，
            // >>> 对无符号操作数退化成 >>。这是 Verilog 里最隐蔽的坑之一：
            // 语法完全合法、不告警，但行为不是你要的。
            OP_SRA:  result = $signed(a) >>> b[4:0];

            // lui 需要把立即数原样送到写回通路，让 ALU 直通 b 即可，
            // 省掉在 a 通路上额外加一个「强制置零」的多路选择器
            OP_LUI:  result = b;

            default: result = 32'b0;

        endcase
    end

    //------------------------------------------------------------------------
    // zero 标志：供 beq / bne 使用（做 SUB，结果为 0 即相等）
    //
    // ⚠ blt / bge / bltu / bgeu 不看 zero，而是看 SLT / SLTU 的
    //   result[0]。分支判定逻辑放在顶层，见 decoder.v 的 branch_type 输出。
    //------------------------------------------------------------------------
    assign zero = (result == 32'b0);

endmodule
