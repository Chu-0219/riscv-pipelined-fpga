// ============================================================================
// top.v -- RV32I single-cycle core, top-level integration
//
// Modules connected here:
//   pc_unit   program counter, PC+4, branch/jump target
//   imem      instruction memory (asynchronous read)
//   decoder   control signals + ALU control
//   imm_gen   immediate generation and sign extension
//   regfile   32 x 32-bit registers, x0 hardwired to zero
//   alu       arithmetic / logic / comparison
//   dmem      data memory (asynchronous read, synchronous write)
//
// Note on JALR: the decoder configures the ALU to compute rs1 + imm for a
// JALR instruction, which is exactly the jump target. pc_unit reuses that
// result instead of instantiating a second adder.
// ============================================================================

module top (
    input  wire        clk,
    input  wire        rst,

    // Debug taps for the testbench. Not part of the datapath.
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire [31:0] dbg_alu_result,
    output wire [31:0] dbg_wb_data,
    output wire        dbg_reg_write
);

    // ------------------------------------------------------------------
    // Interconnect
    // ------------------------------------------------------------------
    wire [31:0] pc;
    wire [31:0] pc_plus4;
    wire [31:0] pc_target;
    wire [31:0] instr;
    wire [31:0] imm;

    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src;
    wire        alu_a_src;
    wire [1:0]  wb_sel;
    wire        branch;
    wire        jump;
    wire        jalr;
    wire [2:0]  branch_type;
    wire [3:0]  alu_control;

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire        alu_zero;
    wire [31:0] mem_rdata;
    reg  [31:0] wb_data;

    wire        branch_taken;
    wire        pc_src;

    // ------------------------------------------------------------------
    // Program counter
    // ------------------------------------------------------------------
    pc_unit u_pc (
        .clk        (clk),
        .rst        (rst),
        .pc_src     (pc_src),
        .jalr       (jalr),
        .alu_result (alu_result),
        .imm        (imm),
        .pc         (pc),
        .pc_plus4   (pc_plus4),
        .pc_target  (pc_target)
    );

    // ------------------------------------------------------------------
    // Instruction memory
    // ------------------------------------------------------------------
    imem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // ------------------------------------------------------------------
    // Control
    // ------------------------------------------------------------------
    decoder u_decoder (
        .inst        (instr),
        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .alu_src     (alu_src),
        .alu_a_src   (alu_a_src),
        .wb_sel      (wb_sel),
        .branch      (branch),
        .jump        (jump),
        .jalr        (jalr),
        .branch_type (branch_type),
        .alu_control (alu_control)
    );

    imm_gen u_imm_gen (
        .inst (instr),
        .imm  (imm)
    );

    // ------------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------------
    regfile u_regfile (
        .clk      (clk),
        .we       (reg_write),
        .rs1_addr (instr[19:15]),
        .rs2_addr (instr[24:20]),
        .rd_addr  (instr[11:7]),
        .rd_data  (wb_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ------------------------------------------------------------------
    // ALU operand selection
    //   alu_a_src : 0 = rs1, 1 = PC   (AUIPC, JAL)
    //   alu_src   : 0 = rs2, 1 = imm
    // ------------------------------------------------------------------
    assign alu_a = alu_a_src ? pc  : rs1_data;
    assign alu_b = alu_src   ? imm : rs2_data;

    alu u_alu (
        .alu_op (alu_control),
        .a      (alu_a),
        .b      (alu_b),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // ------------------------------------------------------------------
    // Data memory
    // Read is combinational, so mem_read is not needed as an enable here.
    // It is kept in the decoder because a pipelined version will need it.
    // ------------------------------------------------------------------
    dmem u_dmem (
        .clk   (clk),
        .we    (mem_write),
        .addr  (alu_result),
        .wdata (rs2_data),
        .rdata (mem_rdata)
    );

    // ------------------------------------------------------------------
    // Write-back multiplexer
    //   00 = ALU result, 01 = memory, 10 = PC+4 (JAL / JALR link address)
    // ------------------------------------------------------------------
    always @(*) begin
        case (wb_sel)
            2'b00:   wb_data = alu_result;
            2'b01:   wb_data = mem_rdata;
            2'b10:   wb_data = pc_plus4;
            default: wb_data = alu_result;
        endcase
    end

    // ------------------------------------------------------------------
    // Branch resolution
    // The decoder drives the ALU to SUB for beq/bne, SLT for blt/bge and
    // SLTU for bltu/bgeu, so the comparison result is already available:
    //   equality      -> alu_zero
    //   less-than     -> alu_result[0]
    // ------------------------------------------------------------------
    assign branch_taken =
          (branch_type == 3'b000) ?  alu_zero         :  // beq
          (branch_type == 3'b001) ? ~alu_zero         :  // bne
          (branch_type == 3'b100) ?  alu_result[0]    :  // blt
          (branch_type == 3'b101) ? ~alu_result[0]    :  // bge
          (branch_type == 3'b110) ?  alu_result[0]    :  // bltu
          (branch_type == 3'b111) ? ~alu_result[0]    :  // bgeu
                                     1'b0;

    assign pc_src = jump | (branch & branch_taken);

    // ------------------------------------------------------------------
    // Debug taps
    // ------------------------------------------------------------------
    assign dbg_pc         = pc;
    assign dbg_instr      = instr;
    assign dbg_alu_result = alu_result;
    assign dbg_wb_data    = wb_data;
    assign dbg_reg_write  = reg_write;

endmodule
