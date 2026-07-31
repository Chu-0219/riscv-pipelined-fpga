module adder_n #(
    parameter WIDTH = 4
)(
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    input             cin,
    output [WIDTH-1:0] sum,
    output             cout

);
wire [WIDTH:0] carry;

assign carry[0] = cin;
assign cout = carry[WIDTH];
// 把链条最末端那一格的值,原样接到外部输出端口上
 
 genvar i;
 generate
     for (i = 0; i < WIDTH; i = i + 1) begin : gen_fa
        full_adder u_fa (
            .a   (a[i]),
            .b   (b[i]),
            .cin (carry[i]),
            .cout(carry[i+1]),
            .sum (sum[i])
        );
    end
 endgenerate
 endmodule