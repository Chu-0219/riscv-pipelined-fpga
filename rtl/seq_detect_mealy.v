module seq_detect_mealy (
    input wire clk, 
    input wire rst, 
    input wire x,
    output reg y
);

localparam s0 = 2'd0, s1 = 2'd1, s2 = 2'd2, s3 = 2'd3, s4 = 2'd4;
reg [1:0] state , next_state;


always @(posedge clk) begin//段1 状态寄存器
if (rst) 
state <= s0;
else
 state <= next_state;
end

// 段2:次态逻辑(和Moore版几乎一样,只是少了一个s4)
always @(*) begin
    next_state = state;
    case (state)
    s0: next_state = x ?  s1 : s0;
    s1: next_state = x ?  s2 : s0;
    s2: next_state = x ?  s2 : s3;
    s3: next_state = x ?  s1 : s0;
    default: next_state = s0;
endcase
end

always @(*) begin
    y = 1'b0;
    if (state == s3 &&x)
     y = 1'b1;
end
endcase
endmodule
