`timescale 1ns/1ps
// 数据存储器：同步写、组合读，字寻址
// 已知待办：字节/半字访问（sb/sh/lb/lh）未实现，需按 funct3 加字节使能
module dmem #(
    parameter  DEPTH     = 256
)(
     input             clk,
    input             we,
    input      [31:0] addr,
    input      [31:0] wdata,
    output     [31:0] rdata
);
    reg [31:0] mem [0:DEPTH-1];

    assign rdata = mem[addr[9:2]];

    always @(posedge clk) begin
        if (we) mem[addr[9:2]] <= wdata;
    end
endmodule