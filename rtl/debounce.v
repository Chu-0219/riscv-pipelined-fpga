module debounce #(
    parameter CNT_MAX = 21'd2000000
)(
    input clk,
    input rst,
    input btn_in,
    output reg btn_pulse
);
// 1. 状态编码：localparam 定义4个状态
localparam IDLE           = 2'd0;
localparam PRESS_CHECK    = 2'd1;
localparam PRESSED        = 2'd2;
localparam RELEASE_CHECK = 2'd3;



reg [1:0] state , next_state;
reg [20:0] cnt;

// 2. 第一段：时序逻辑，状态寄存器更新
always @(posedge clk) begin
    if (rst)
    state <= IDLE ;
    else
    state <= next_state;
end

// 3. 第二段：组合逻辑，次态译码（case语句，记得default）
always @(*) begin
    next_state = state ; //默认保持防锁存
    case  (state)
    IDLE:          if (btn_in)       next_state = PRESS_CHECK;
    PRESS_CHECK:   if(!btn_in)       next_state = IDLE;
                   else if(cnt == CNT_MAX) next_state = PRESSED;
    RELEASE_CHECK: if(btn_in)        next_state = PRESSED;
                   else if (cnt == CNT_MAX) next_state = IDLE;
     PRESSED:      if (!btn_in) next_state = RELEASE_CHECK;
    default: next_state = IDLE;
    endcase
    end

//    4. 计数器：在两个CHECK状态里递增，其他情况清零）
always @(posedge clk) begin
    if (rst)
    cnt <= 21'd0;
    else if (state == PRESS_CHECK || state == RELEASE_CHECK)
    cnt <= cnt + 21'd1;
    else
    cnt <= 21'd0;
end
//  5. 第三段：输出逻辑——想想脉冲在哪个转移瞬间产生
always @(posedge clk) begin
    if (rst)
    btn_pulse <= 1'b0;
    else
    btn_pulse <= (state == PRESS_CHECK) && (next_state ==PRESSED);
end
endmodule





