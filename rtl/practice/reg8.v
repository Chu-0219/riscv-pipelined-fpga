module reg8 (
    input wire       clk,
    input wire       rst,
    input wire       en,
    input wire [7:0] d,
    output reg [7:0] q
);
always @(posedge clk) begin
     // en=0 时没写 else 分支,q 保持原值——这在时序逻辑里是正常且预期的行为
    if (rst)
    q <= 8'b0;
    else if (en)
    q <= d;
end
endmodule

