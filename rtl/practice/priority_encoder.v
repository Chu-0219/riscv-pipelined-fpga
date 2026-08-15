module priority_encoder(
    input wire [3:0] in,
    output reg [1:0] out
);
always @(*) begin
    casez (in)
    4'b1???: out = 2'd3;
    4'b01??: out = 2'd2;
    4'b001?: out = 2'd1;
    4'd0001: out = 2'd0;
    default: out = 2'd0;
    endcase
end

endmodule