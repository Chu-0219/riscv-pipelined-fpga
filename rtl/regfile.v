// ============================================================================
// regfile.v -- RV32I register file
//
// 32 x 32-bit registers.
// Two asynchronous (combinational) read ports, one synchronous write port.
// x0 is hardwired to zero on BOTH sides:
//   - reading address 0 always returns 32'h0000_0000
//   - writing to address 0 is discarded
//
// Same-cycle read/write returns the OLD value: the write lands on the rising
// clock edge, while the read path is pure combinational logic looking at the
// current array contents. This is the correct behaviour for a single-cycle
// RV32I datapath, where write-back happens at the end of the cycle.
// ============================================================================

module regfile (
    input  wire        clk,
    input  wire        we,        // write enable (RegWrite)
    input  wire [4:0]  rs1_addr,  // read port 1 address
    input  wire [4:0]  rs2_addr,  // read port 2 address
    input  wire [4:0]  rd_addr,   // write port address
    input  wire [31:0] rd_data,   // write port data
    output wire [31:0] rs1_data,  // read port 1 data
    output wire [31:0] rs2_data   // read port 2 data
);

    // ------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'h0000_0000;
        end
    end

    // ------------------------------------------------------------------
    // Asynchronous read ports, with x0 hardwired to zero
    // ------------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'h0000_0000 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'h0000_0000 : regs[rs2_addr];

    // ------------------------------------------------------------------
    // Synchronous write port, writes to x0 discarded
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule
