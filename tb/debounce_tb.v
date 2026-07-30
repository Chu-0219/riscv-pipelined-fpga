`timescale 1ns/1ps
module debounce_tb;

reg clk, rst, btn_in;
wire btn_pulse;

debounce #(.CNT_MAX(21'd10)) uut (
    .clk      (clk),
    .rst      (rst),
    .btn_in   (btn_in),
    .btn_pulse(btn_pulse)
);

always #5 clk = ~clk;

integer pulse_count;
always @(posedge clk) begin
    if (btn_pulse) pulse_count = pulse_count + 1;
end

initial begin
    $dumpfile("sim.vcd");
    $dumpvars(0, debounce_tb);

    clk = 0; rst = 1; btn_in = 0; pulse_count = 0;
    #20 rst = 0;

    btn_in = 1; #20;
    btn_in = 0; #15;
    btn_in = 1; #10;
    btn_in = 0; #12;
    btn_in = 1;#200;

    btn_in = 0;#200;

    btn_in = 1; #30;
    btn_in = 0; #20;
    btn_in = 1; #40;
    btn_in = 0;#200;

    if (pulse_count == 1)
        $display("PASS: 检测到 %0d 次有效按下", pulse_count);
    else
       $display("FAIL: expected 1, got %0d", pulse_count);

    $finish;
end

endmodule