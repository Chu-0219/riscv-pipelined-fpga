module sync_ram #(
    parameter WIDTH     = 8,
    parameter DEPTH     = 16,
    parameter ADDR_W    = $clog2(DEPTH),
    parameter INIT_FILE = ""
)(
    input                  clk,
    input                  we,
    input [ADDR_W-1:0]     addr,
    input [WIDTH-1:0]      din,
    output reg [WIDTH-1:0] dout
);
reg [WIDTH-1:0] mem [0:DEPTH-1];

initial begin
    if (INIT_FILE != "")
        $readmemh(INIT_FILE, mem);
end

always @(posedge clk ) begin
    if (we)
    mem[addr] <= din;
    dout <= mem[addr];
end

    
endmodule