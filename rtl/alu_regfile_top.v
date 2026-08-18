// alu_regfile_top.v -- ALU + regfile 迷你数据通路 (第2段 Day5)
// 读 rs1/rs2 -> ALU 运算 -> 写回 rd
// 立即数旁路: wdata 在 ALU结果 / 立即数 间二选一 (WriteBack mux 雏形)
// 复用子模块: alu.v (纯组合) + regfile.v (异步读/同步写)
//
// 注: alu.v 在第3段改写为固定 32 位、不再参数化。
//     本模块仍是 8 位数据通路，例化 ALU 时输入高位补零、输出高位截断。
//     加减与位运算在结果不超过 8 位时正确；SLT / SRA 等有符号操作
//     因补零而语义改变。彻底对齐留待单周期集成时重写本模块。
module alu_regfile_top #(
    parameter WIDTH  = 8,
    parameter DEPTH  = 8,
    parameter ADDR_W = $clog2(DEPTH)
)(
    input                   clk,
    input                   we,        // 写回使能
    input                   use_imm,   // 1=写立即数, 0=写ALU结果
    input  [WIDTH-1:0]      imm,       // 立即数 (use_imm=1 时写入)
    input  [3:0]            alu_op,
    input  [ADDR_W-1:0]     rs1,
    input  [ADDR_W-1:0]     rs2,
    input  [ADDR_W-1:0]     rd,
    output [WIDTH-1:0]      alu_result, // 观察用
    output                  zero        // 观察用
);

    wire [WIDTH-1:0] rf_rdata1;
    wire [WIDTH-1:0] rf_rdata2;
    wire [WIDTH-1:0] alu_out;
    wire [WIDTH-1:0] wb_data;    // 写回数据 (mux 输出)

    // ALU 侧为固定 32 位，此处显式做位宽转换，
    // 不依赖 Verilog 的隐式补零/截断，避免静默出错
    wire [31:0] alu_a = {{(32-WIDTH){1'b0}}, rf_rdata1};
    wire [31:0] alu_b = {{(32-WIDTH){1'b0}}, rf_rdata2};
    wire [31:0] alu_out_32;

    // --- 写回来源二选一 (WriteBack mux) ---
    assign wb_data = use_imm ? imm : alu_out;

    // --- 寄存器堆 ---
    regfile #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) u_rf (
        .clk    (clk),
        .we     (we),
        .waddr  (rd),
        .wdata  (wb_data),
        .raddr1 (rs1),
        .rdata1 (rf_rdata1),
        .raddr2 (rs2),
        .rdata2 (rf_rdata2)
    );

    // --- ALU (第3段起固定 32 位，无参数) ---
    alu u_alu (
        .alu_op (alu_op),
        .a      (alu_a),
        .b      (alu_b),
        .result (alu_out_32),
        .zero   (zero)
    );

    assign alu_out    = alu_out_32[WIDTH-1:0];
    assign alu_result = alu_out;

endmodule