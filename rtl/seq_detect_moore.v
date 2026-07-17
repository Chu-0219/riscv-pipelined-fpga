// Moore:输出只取决于当前状态,和输入无关。特点是输出经过寄存器,干净无毛刺,但对输入的响应会晚一拍(因为要先跳转到新状态,输出才跟着变)。
// Mealy:输出取决于当前状态和当前输入。特点是响应更快(同一拍内输入变化就能反映到输出),但输出是组合逻辑直接输出,可能有毛刺(glitch)。
module seq_detect_moore (
    input wire clk,
    input wire rst,
    input wire x,
    output reg y
);
localparam s0 = 3'd0, s1 = 3'd1, s2 = 3'd2, s3 = 3'd3, s4 = 3'd4;
reg [2:0] state ,next_state;

always @(posedge clk) begin
    if (rst) state <= s0;
    else state <= next_state;
end

always @(*) begin
    next_state = state; //默认保持哦
    case (state)
    s0: next_state = x ? s1 : s0;
    s1: next_state = x ? s2 : s0;
    s2: next_state = x ? s2 : s3;
    s3: next_state = x ? s4 : s0;
    s4: next_state = x ? s2 : s0;
    default: next_state = s0;
    endcase
end

always @(*) begin
    case (state)
    s4: y = 1'b1;
    default: y = 1'b0;
    endcase
end

endmodule



