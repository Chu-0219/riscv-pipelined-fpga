// alu_regfile_top.v -- ALU + regfile 迷你数据通路 (第2段 Day5)
// 读 rs1/rs2 -> ALU 运算 -> 写回 rd
// 立即数旁路: wdata 在 ALU结果 / 立即数 间二选一 (WriteBack mux 雏形)
// 复用子模块: alu.v (纯组合) + regfile.v (异步读/同步写)
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

    // --- ALU ---
    alu #(
        .WIDTH (WIDTH)
    ) u_alu (
        .alu_op (alu_op),
        .a      (rf_rdata1),
        .b      (rf_rdata2),
        .result (alu_out),
        .zero   (zero)
    );

    assign alu_result = alu_out;

endmodule