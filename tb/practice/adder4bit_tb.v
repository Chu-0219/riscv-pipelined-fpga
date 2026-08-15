module adder4bit_tb;

// 第一步:先声明几根线,准备接到DUT的引脚上
  reg [3:0] a_test, b_test;
  reg     cin_test;
  wire [3:0] sum_test;
wire cout_test;
//stbench 这边需要主动去改变a、b、cin的值(相当于你在按计算器的按钮),
// 凡是需要在 initial 块里被赋值的信号,必须是 reg 类型;
// 而 sum_test、cout_test 是观察DUT算出来的结果,你不会去改它,
// 它是被动接收DUT输出的,所以是 wire



// 第二步:例化,把图纸变成实体,并且把引脚接到上面这些线上
adder4bit uut(//uut = Unit Under Test,被测单元,这是个约定俗成的命名习惯,
//可以叫别的名字,比如 dut)。这一整行的意思是:"照着 adder4bit 图纸做一个东西,起名叫 uut
    .a(a_test),
    .b(b_test),
    .cin(cin_test),
    .sum(sum_test),
    .cout(cout_test)
);

  initial begin

   a_test = 4'b0000; b_test = 4'b0000; cin_test = 1'b0;
   #10;
   if (sum_test == 4'b0000 && cout_test == 1'b0)
   $display ("PASS: 0000+0000+0");
   else
   $display ("FAIL: 0000+0000+0, got sum=%b cout=%b", sum_test, cout_test);

   a_test = 4'b1111; b_test = 4'b1111; cin_test = 1'b0;
   #10;
   if (sum_test == 4'b1110 && cout_test == 1'b1)
   $display("PASS: 1111+1111 (overflow)");
   else
   $display("FAIL: 1111+1111, got sum=%b cout=%b", sum_test, cout_test);

// 结果恰好回绕到0:边界中的边界,容易漏测
a_test = 4'b1000; b_test = 4'b1000; cin_test = 1'b0;
#10;
if (sum_test == 4'b0000 && cout_test == 1'b1)  // 8+8=16=10000,低4位0000,cout=1
    $display("PASS: 1000+1000 (wraps to zero)");
else
    $display("FAIL: 1000+1000, got sum=%b cout=%b", sum_test, cout_test);

// 带cin的溢出:容易漏测的组合,单独测a/b都不会溢出,但加上cin就会
a_test = 4'b1111; b_test = 4'b0000; cin_test = 1'b1;
#10;
if (sum_test == 4'b0000 && cout_test == 1'b1)
    $display("PASS: 1111+0000+cin (carry-in triggers overflow)");
else
    $display("FAIL: 1111+0000+cin, got sum=%b cout=%b", sum_test, cout_test);

// 中间值确认不会误报cout(防止"永远输出cout=1"这种bug被漏测出来)
a_test = 4'b0111; b_test = 4'b0001; cin_test = 1'b0;
#10;
if (sum_test == 4'b1000 && cout_test == 1'b0)
    $display("PASS: 0111+0001 (no overflow)");
else
    $display("FAIL: 0111+0001, got sum=%b cout=%b", sum_test, cout_test);
end 
  
  endmodule
// 4'd3 的意思是:用4位二进制来表示十进制数3,也就是二进制的 0011
//# 在 Verilog 里是延时控制符(delay control),
// 专门用在仿真里,表示"等待多少个时间单位再继续往下执行"()