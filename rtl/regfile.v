module regfile #(
    parameter WIDTH = 8,
    parameter DEPTH = 8,
    parameter ADDR_W = $clog2(DEPTH)
    // $clog2 是"向上取整的 log2"
)(
    input               clk,
    input               we,
    input [ADDR_W-1:0] waddr,
    input [WIDTH-1:0]   wdata,

    input  [ADDR_W-1:0]     raddr1,
    output [WIDTH-1:0]      rdata1,
    input  [ADDR_W-1:0]     raddr2,
    output [WIDTH-1:0]      rdata2 
);

reg [WIDTH-1:0] rf [0:DEPTH-1];
    // 同步写: 只在时钟沿、we有效时更新
    always @(posedge clk) begin
        if (we)
        rf[waddr] <= wdata;
    end

    // 异步读: 纯组合, 地址一变数据即变
    // 综合成 DEPTH 选 1 的 mux

    assign rdata1 = rf[raddr1];
    assign rdata2 = rf[raddr2];

    endmodule
     