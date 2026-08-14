`timescale 1ns/1ps
//============================================================================
// decoder_tb.v  --  decoder.v 自检式定向测试
//
// 每条用例送入一条真实机器码，比对全部控制信号。
// 所有指令编码均按 RISC-V 规范手工编码并独立核验过。
//
// 重点用例：
//   - addi x1,x2,0x5A3  : inst[30]=1 的 I 型加法，必须译成 ADD 而非 SUB
//   - srai / srli       : funct3=101 时 I 型也看 inst[30]，与上一条相反
//   - sw                : inst[30]=1 但 alu_op 强制 ADD，不受影响
//============================================================================

module decoder_tb;

    // ALU 操作码（与 alu.v / decoder.v 对齐）
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SLL  = 4'b0110;
    localparam ALU_SRL  = 4'b0111;
    localparam ALU_SRA  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;

    reg  [31:0] inst;

    wire        reg_write, mem_read, mem_write;
    wire        alu_src, alu_a_src;
    wire [1:0]  wb_sel;
    wire        branch, jump, jalr;
    wire [2:0]  branch_type;
    wire [3:0]  alu_control;

    integer pass_cnt;
    integer fail_cnt;

    decoder dut (
        .inst        (inst),
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

    //------------------------------------------------------------------------
    // 全信号比对
    //------------------------------------------------------------------------
    task check;
        input [511:0] name;
        input [31:0]  t_inst;
        input         e_reg_write;
        input         e_mem_read;
        input         e_mem_write;
        input         e_alu_src;
        input         e_alu_a_src;
        input [1:0]   e_wb_sel;
        input         e_branch;
        input         e_jump;
        input         e_jalr;
        input [3:0]   e_alu_control;
        begin
            inst = t_inst;
            #1;
            if (reg_write   === e_reg_write   &&
                mem_read    === e_mem_read    &&
                mem_write   === e_mem_write   &&
                alu_src     === e_alu_src     &&
                alu_a_src   === e_alu_a_src   &&
                wb_sel      === e_wb_sel      &&
                branch      === e_branch      &&
                jump        === e_jump        &&
                jalr        === e_jalr        &&
                alu_control === e_alu_control) begin
                pass_cnt = pass_cnt + 1;
                $display("PASS | %0s", name);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL | %0s   inst=%h", name, t_inst);
                $display("       signal    got  exp");
                $display("       reg_write  %b    %b", reg_write, e_reg_write);
                $display("       mem_read   %b    %b", mem_read,  e_mem_read);
                $display("       mem_write  %b    %b", mem_write, e_mem_write);
                $display("       alu_src    %b    %b", alu_src,   e_alu_src);
                $display("       alu_a_src  %b    %b", alu_a_src, e_alu_a_src);
                $display("       wb_sel    %b   %b",  wb_sel,    e_wb_sel);
                $display("       branch     %b    %b", branch,    e_branch);
                $display("       jump       %b    %b", jump,      e_jump);
                $display("       jalr       %b    %b", jalr,      e_jalr);
                $display("       alu_ctrl %b %b",      alu_control, e_alu_control);
            end
        end
    endtask

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        $display("");
        $display("========================================================");
        $display("  decoder self-checking testbench");
        $display("========================================================");

        //====================================================================
        // R-type   reg_write=1 alu_src=0 wb_sel=00
        //====================================================================
        $display("");
        $display("---- R-type ----");
        //     name                       inst          rw mr mw as aa wb    br jp jr  alu
        check("R: add  x10,x11,x12", 32'h00C58533, 1,0,0,0,0,2'b00,0,0,0, ALU_ADD);
        check("R: sub  x10,x11,x12", 32'h40C58533, 1,0,0,0,0,2'b00,0,0,0, ALU_SUB);
        check("R: sll  x10,x11,x12", 32'h00C59533, 1,0,0,0,0,2'b00,0,0,0, ALU_SLL);
        check("R: slt  x10,x11,x12", 32'h00C5A533, 1,0,0,0,0,2'b00,0,0,0, ALU_SLT);
        check("R: sltu x10,x11,x12", 32'h00C5B533, 1,0,0,0,0,2'b00,0,0,0, ALU_SLTU);
        check("R: xor  x10,x11,x12", 32'h00C5C533, 1,0,0,0,0,2'b00,0,0,0, ALU_XOR);
        check("R: srl  x10,x11,x12", 32'h00C5D533, 1,0,0,0,0,2'b00,0,0,0, ALU_SRL);
        check("R: sra  x10,x11,x12", 32'h40C5D533, 1,0,0,0,0,2'b00,0,0,0, ALU_SRA);
        check("R: or   x10,x11,x12", 32'h00C5E533, 1,0,0,0,0,2'b00,0,0,0, ALU_OR);
        check("R: and  x10,x11,x12", 32'h00C5F533, 1,0,0,0,0,2'b00,0,0,0, ALU_AND);

        //====================================================================
        // I-type ALU   alu_src=1
        //====================================================================
        $display("");
        $display("---- I-type ALU ----");
        check("I: addi x5,x6,100",   32'h06430293, 1,0,0,1,0,2'b00,0,0,0, ALU_ADD);
        // 关键用例：立即数 0x5A3 使 inst[30]=1，若无 opcode 限定会误译成 SUB
        check("I: addi x1,x2,0x5A3 (inst[30]=1 trap)",
                                     32'h5A310093, 1,0,0,1,0,2'b00,0,0,0, ALU_ADD);
        check("I: srli x5,x6,3",     32'h00335293, 1,0,0,1,0,2'b00,0,0,0, ALU_SRL);
        // funct3=101 时 I 型也看 inst[30]，与 addi 的情形相反
        check("I: srai x5,x6,3 (I-type reads inst[30])",
                                     32'h40335293, 1,0,0,1,0,2'b00,0,0,0, ALU_SRA);

        //====================================================================
        // LOAD / STORE
        //====================================================================
        $display("");
        $display("---- LOAD / STORE ----");
        check("L: lw x5,8(x6)",      32'h00832283, 1,1,0,1,0,2'b01,0,0,0, ALU_ADD);
        // sw 的 inst[30]=1，但 alu_op 强制 ADD，不受 funct7 影响
        check("S: sw x7,-8(x9) (inst[30]=1, forced ADD)",
                                     32'hFE74AC23, 0,0,1,1,0,2'b00,0,0,0, ALU_ADD);

        //====================================================================
        // BRANCH   reg_write=0 branch=1 alu_src=0
        //====================================================================
        $display("");
        $display("---- BRANCH ----");
        check("B: beq  x1,x2,100",   32'h06208263, 0,0,0,0,0,2'b00,1,0,0, ALU_SUB);
        check("B: blt  x1,x2,100",   32'h0620C263, 0,0,0,0,0,2'b00,1,0,0, ALU_SLT);
        check("B: bltu x1,x2,100",   32'h0620E263, 0,0,0,0,0,2'b00,1,0,0, ALU_SLTU);

        //====================================================================
        // LUI / AUIPC / JAL / JALR
        //====================================================================
        $display("");
        $display("---- U / J ----");
        check("U: lui   x5,0x12345", 32'h123452B7, 1,0,0,1,0,2'b00,0,0,0, ALU_LUI);
        check("U: auipc x5,0x1",     32'h00001297, 1,0,0,1,1,2'b00,0,0,0, ALU_ADD);
        check("J: jal   x1,100",     32'h064000EF, 1,0,0,1,1,2'b10,0,1,0, ALU_ADD);
        check("J: jalr  x1,x2,4",    32'h004100E7, 1,0,0,1,0,2'b10,0,1,1, ALU_ADD);

        //====================================================================
        // 非法指令：所有写使能必须为 0
        //====================================================================
        $display("");
        $display("---- illegal ----");
        check("D: all-zero inst",    32'h00000000, 0,0,0,0,0,2'b00,0,0,0, ALU_ADD);
        check("D: all-one inst",     32'hFFFFFFFF, 0,0,0,0,0,2'b00,0,0,0, ALU_ADD);

        //====================================================================
        // branch_type 直通检查
        //====================================================================
        $display("");
        $display("---- branch_type passthrough ----");
        inst = 32'h0620E263; #1;   // bltu, funct3 = 110
        if (branch_type === 3'b110) begin
            pass_cnt = pass_cnt + 1;
            $display("PASS | branch_type == funct3 (bltu -> 110)");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL | branch_type got=%b exp=110", branch_type);
        end

        //====================================================================
        $display("");
        $display("========================================================");
        $display("  TOTAL: %0d,  FAILED: %0d", pass_cnt + fail_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> %0d TEST(S) FAILED <<<", fail_cnt);
        $display("========================================================");
        $display("");

        $finish;
    end

endmodule
