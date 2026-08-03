// alu.v -- 参数化 ALU (第2段版本)
// 操作: ADD SUB AND OR XOR SLT(有符号) SLL SRL
// 纯组合逻辑; SRA/SLTU 及 ALUControl 对接在第3段扩展
module alu #(
    parameter WIDTH = 8,
    parameter SH_W  = $clog2(WIDTH)
)(
    input      [3:0]       alu_op,
    input      [WIDTH-1:0] a,
    input      [WIDTH-1:0] b,
    output reg [WIDTH-1:0] result,
    output                 zero
);

    // 操作码编码 (4位, 为第3段扩展留余量)
localparam OP_ADD = 4'b0000;
localparam OP_SUB = 4'b0001;
localparam OP_AND = 4'b0010;
localparam OP_OR  = 4'b0011;
localparam OP_XOR = 4'b0100;
localparam OP_SLT = 4'b0101;
localparam OP_SLL = 4'b0110;
localparam OP_SRL = 4'b0111;

always @(*) begin
    case (alu_op)
    OP_ADD: result = a + b;
    OP_SUB: result = a - b;
    OP_AND: result = a & b;
    OP_OR:  result = a | b;
    OP_XOR: result = a ^ b;
    OP_SLT: result = {{(WIDTH-1){1'b0}},
                      ($signed(a) < $signed(b))};

    OP_SLL: result = a << b[SH_W-1:0];
    OP_SRL: result = a >> b[SH_W-1:0];
    default: result = {WIDTH{1'b0}};
    endcase
end

assign zero = (result == {WIDTH{1'b0}});
endmodule