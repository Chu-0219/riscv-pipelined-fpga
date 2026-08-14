`timescale 1ns / 1ps
//============================================================================
// decoder.v  --  RV32I 控制单元（主译码器 + ALU 译码器）
//
// 输入整条指令，内部自行提取 opcode / funct3 / funct7——与 imm_gen.v
// 保持同一风格，顶层因此少接好几根线，集成时少几个可能接错的地方。
//
// 两级结构：
//   主译码器    看 opcode      -> 数据通路控制信号 + alu_op[1:0]（内部信号）
//   ALU 译码器  看 alu_op + funct3 + inst[30] -> alu_control[3:0]
//
// 分成两级而不是写一个大 case，是因为「这条指令要不要写寄存器」和
// 「ALU 该做哪种运算」是两个正交的问题，混在一起会让 case 分支爆炸，
// 且调试时无法区分是通路控制错了还是运算选错了。
//============================================================================

module decoder (
    input  wire [31:0] inst,

    // ---- 数据通路控制 ----
    output reg         reg_write,      // 是否写回寄存器堆
    output reg         mem_read,       // 读数据存储器
    output reg         mem_write,      // 写数据存储器
    output reg         alu_src,        // ALU 第二操作数: 0=rs2, 1=imm
    output reg         alu_a_src,      // ALU 第一操作数: 0=rs1, 1=PC
    output reg  [1:0]  wb_sel,         // 写回数据来源: 00=ALU, 01=MEM, 10=PC+4
    output reg         branch,         // 条件分支指令
    output reg         jump,           // 无条件跳转 (jal / jalr)
    output reg         jalr,           // 跳转目标: 0=PC+imm, 1=rs1+imm
    output wire [2:0]  branch_type,    // = funct3, 供顶层判定分支是否成立

    // ---- ALU 控制 ----
    output reg  [3:0]  alu_control
);

    //------------------------------------------------------------------------
    // 字段提取
    //------------------------------------------------------------------------
    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire       f7b5   = inst[30];   // funct7 的第 5 位，区分 add/sub 与 srl/sra

    assign branch_type = funct3;

    //------------------------------------------------------------------------
    // opcode 常量
    //------------------------------------------------------------------------
    localparam OP_R      = 7'b0110011;
    localparam OP_I_ALU  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;

    //------------------------------------------------------------------------
    // ALU 操作码（与 alu.v 逐位对齐，改动必须两边同步）
    //------------------------------------------------------------------------
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

    //------------------------------------------------------------------------
    // alu_op：主译码器 -> ALU 译码器的内部信号，只有 4 种取值
    //------------------------------------------------------------------------
    localparam AOP_ADD    = 2'b00;  // 强制加法（访存地址、跳转目标、auipc）
    localparam AOP_BRANCH = 2'b01;  // 按 funct3 选比较方式
    localparam AOP_ARITH  = 2'b10;  // 按 funct3 / inst[30] 选运算
    localparam AOP_LUI    = 2'b11;  // 直通立即数

    reg [1:0] alu_op;

    //========================================================================
    // 第一级：主译码器
    //========================================================================
    always @(*) begin
        // 默认值：全部关掉。
        // 这一段不能省——组合 always 块中若有路径未赋值会推断出锁存器。
        // 而且默认「不写寄存器、不写内存」是安全侧：遇到未识别指令时
        // 处理器状态不会被破坏。
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        alu_src   = 1'b0;
        alu_a_src = 1'b0;
        wb_sel    = 2'b00;
        branch    = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;
        alu_op    = AOP_ADD;

        case (opcode)

            // add / sub / and / or / xor / slt / sltu / sll / srl / sra
            OP_R: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;      // 第二操作数取 rs2
                alu_op    = AOP_ARITH;
            end

            // addi / andi / ori / xori / slti / sltiu / slli / srli / srai
            OP_I_ALU: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;      // 第二操作数取立即数
                alu_op    = AOP_ARITH;
            end

            // lw / lh / lb / lhu / lbu：地址 = rs1 + imm
            OP_LOAD: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_src   = 1'b1;
                wb_sel    = 2'b01;     // 写回来自内存
                alu_op    = AOP_ADD;
            end

            // sw / sh / sb：地址 = rs1 + imm，不写寄存器
            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = AOP_ADD;
            end

            // beq / bne / blt / bge / bltu / bgeu
            // ALU 做比较，是否跳转由顶层结合 branch_type 与 zero/result[0] 判定
            OP_BRANCH: begin
                branch  = 1'b1;
                alu_src = 1'b0;        // 两个操作数都来自寄存器
                alu_op  = AOP_BRANCH;
            end

            // lui：立即数直接写回，ALU 直通 b
            OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = AOP_LUI;
            end

            // auipc：rd = PC + imm
            OP_AUIPC: begin
                reg_write = 1'b1;
                alu_a_src = 1'b1;      // 第一操作数取 PC
                alu_src   = 1'b1;
                alu_op    = AOP_ADD;
            end

            // jal：rd = PC + 4，跳转目标 = PC + imm
            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_a_src = 1'b1;
                alu_src   = 1'b1;
                wb_sel    = 2'b10;     // 写回 PC+4
                alu_op    = AOP_ADD;
            end

            // jalr：rd = PC + 4，跳转目标 = rs1 + imm
            OP_JALR: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;      // 目标来自 rs1 而非 PC
                alu_src   = 1'b1;
                wb_sel    = 2'b10;
                alu_op    = AOP_ADD;
            end

            // 未识别指令：保持默认值（不写寄存器、不写内存）
            default: ;

        endcase
    end

    //========================================================================
    // 第二级：ALU 译码器
    //========================================================================
    always @(*) begin
        case (alu_op)

            AOP_ADD: alu_control = ALU_ADD;
            AOP_LUI: alu_control = ALU_LUI;

            // 分支：beq/bne 用减法看 zero；blt/bge 用 SLT；bltu/bgeu 用 SLTU
            AOP_BRANCH: begin
                case (funct3)
                    3'b000, 3'b001: alu_control = ALU_SUB;   // beq  / bne
                    3'b100, 3'b101: alu_control = ALU_SLT;   // blt  / bge
                    3'b110, 3'b111: alu_control = ALU_SLTU;  // bltu / bgeu
                    default:        alu_control = ALU_SUB;
                endcase
            end

            AOP_ARITH: begin
                case (funct3)

                    //--------------------------------------------------------
                    // ⚠ 全模块最容易出错的一行
                    //
                    // funct3=000 时，R 型看 inst[30] 区分 add / sub。
                    // 但 I 型（addi）的 inst[30] 是立即数的一位，不是 funct7！
                    //
                    // 若只写 f7b5 ? ALU_SUB : ALU_ADD，那么
                    //   addi x1, x2, 0x5A3   （0x5A3 的 bit10 = 1 -> inst[30]=1）
                    // 会被译码成减法，执行结果变成 x2 - 0x5A3。
                    //
                    // 症状极具迷惑性：大部分 addi 正常，只有立即数落在
                    // 某些区间时出错，很容易被误判成立即数生成器的问题。
                    //
                    // 因此必须用 opcode 限定：只有 R 型才看 inst[30]。
                    //--------------------------------------------------------
                    3'b000: alu_control = (opcode == OP_R && f7b5) ? ALU_SUB : ALU_ADD;

                    3'b001: alu_control = ALU_SLL;
                    3'b010: alu_control = ALU_SLT;
                    3'b011: alu_control = ALU_SLTU;
                    3'b100: alu_control = ALU_XOR;

                    //--------------------------------------------------------
                    // 与上面 000 的情形相反：funct3=101 时不需要 opcode 限定。
                    //
                    // 因为 srli / srai 的移位量只占 inst[24:20] 五位，
                    // inst[31:25] 仍然是货真价实的 funct7。
                    // 所以 I 型和 R 型在这里都可以直接看 inst[30]。
                    //
                    // 这个不对称是 RISC-V 编码的真实特性，不是笔误。
                    //--------------------------------------------------------
                    3'b101: alu_control = f7b5 ? ALU_SRA : ALU_SRL;

                    3'b110: alu_control = ALU_OR;
                    3'b111: alu_control = ALU_AND;

                    default: alu_control = ALU_ADD;
                endcase
            end

            default: alu_control = ALU_ADD;

        endcase
    end

endmodule

//============================================================================
// 顶层集成备忘（8/21 会用到）：
//
// 1. 分支是否成立，需要顶层用 branch_type 组合 ALU 输出判定：
//      beq  (000): zero == 1
//      bne  (001): zero == 0
//      blt  (100): result[0] == 1     (SLT)
//      bge  (101): result[0] == 0
//      bltu (110): result[0] == 1     (SLTU)
//      bgeu (111): result[0] == 0
//    PCSrc = (branch && 条件成立) || jump
//
// 2. jalr 的目标地址按规范需将最低位清零：(rs1 + imm) & ~1
//
// 3. 移位指令 slli/srli/srai 的移位量来自 imm[4:0]，
//    由 alu.v 的 b[4:0] 掩码自动完成，imm_gen 照常输出 I 型即可。
//============================================================================
