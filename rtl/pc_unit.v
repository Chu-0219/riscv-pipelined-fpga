`timescale 1ns/1ps
// PC 寄存器 + PC+4 + 分支目标加法器 + 下一地址选择
// 复位：同步，复位到 0x00000000
// 已知待办：JALR 的目标是 rs1+imm，不是 PC+imm，需在顶层另加通路
module pc_unit (
    input                   clk,
    input                   rst,
    input                   pc_src,
    input            [31:0] imm,
    output reg       [31:0] pc,
    output           [31:0] pc_plus4,
    output           [31:0] pc_target
);

assign pc_plus4   = pc + 32'd4;
assign pc_target  = pc + imm;

wire [31:0] pc_next = pc_src ? pc_target : pc_plus4;

always @(posedge clk) begin
    if (rst) pc <= 32'h0000_0000;
    else     pc <= pc_next;
end
endmodule