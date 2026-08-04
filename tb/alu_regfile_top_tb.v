// alu_regfile_top_tb.v -- 迷你数据通路自检测试 (第2段 Day5)
// 用立即数旁路预置初值, 再测 读->算->写回->读回验证
// 覆盖: R型运算写回 / rs==rd 自读自写 / zero flag / 立即数写入本身
`timescale 1ns/1ps

module alu_regfile_top_tb;

    localparam WIDTH  = 8;
    localparam DEPTH  = 8;
    localparam ADDR_W = 3;

    localparam OP_ADD = 4'b0000;
    localparam OP_SUB = 4'b0001;
    localparam OP_AND = 4'b0010;
    localparam OP_XOR = 4'b0100;

    reg                   clk;
    reg                   we;
    reg                   use_imm;
    reg  [WIDTH-1:0]      imm;
    reg  [3:0]            alu_op;
    reg  [ADDR_W-1:0]     rs1, rs2, rd;
    wire [WIDTH-1:0]      alu_result;
    wire                  zero;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    alu_regfile_top #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) dut (
        .clk        (clk),
        .we         (we),
        .use_imm    (use_imm),
        .imm        (imm),
        .alu_op     (alu_op),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .alu_result (alu_result),
        .zero       (zero)
    );

    // 时钟: 周期 10ns
    always #5 clk = ~clk;

    // 把 regfile 读口1 的数据引出来给 check_reg 用 (只读, 分层引用)
    wire [WIDTH-1:0] rdata1_probe = dut.u_rf.rdata1;

    // --- 预置初值: 用立即数旁路把 val 写进 rf[addr] ---
    task load_imm;
        input [ADDR_W-1:0] addr;
        input [WIDTH-1:0]  val;
        begin
            @(negedge clk);
            use_imm = 1'b1;
            imm     = val;
            rd      = addr;
            we      = 1'b1;
            @(posedge clk);
            @(negedge clk);
            we      = 1'b0;
            use_imm = 1'b0;
        end
    endtask

    // --- R型运算写回: rf[d] <= ALU(rf[s1], rf[s2]) ---
    task run_r;
        input [3:0]        op;
        input [ADDR_W-1:0] s1, s2, d;
        begin
            @(negedge clk);
            use_imm = 1'b0;
            alu_op  = op;
            rs1     = s1;
            rs2     = s2;
            rd      = d;
            we      = 1'b1;
            @(posedge clk);
            @(negedge clk);
            we      = 1'b0;
        end
    endtask

    // --- 读回验证: 读 rf[addr], 比对期望值 ---
    task check_reg;
        input [ADDR_W-1:0] addr;
        input [WIDTH-1:0]  exp;
        input [8*20-1:0]   tag;
        begin
            rs1 = addr;
            #1;
            if (rdata1_probe === exp) begin
                pass_cnt = pass_cnt + 1;
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL [%0s]: rf[%0d] got=%h exp=%h",
                         tag, addr, rdata1_probe, exp);
            end
        end
    endtask

    initial begin
        clk = 0; we = 0; use_imm = 0; imm = 0;
        alu_op = OP_ADD; rs1 = 0; rs2 = 0; rd = 0;

        // === 预置初值 ===
        load_imm(3'd1, 8'd5);    // rf[1] = 5
        load_imm(3'd2, 8'd3);    // rf[2] = 3
        load_imm(3'd4, 8'hF0);   // rf[4] = 0xF0
        load_imm(3'd5, 8'h0F);   // rf[5] = 0x0F

        // 验证立即数写入本身
        check_reg(3'd1, 8'd5,  "imm load rf1");
        check_reg(3'd2, 8'd3,  "imm load rf2");

        // === R型运算写回, 再读回验证 ===
        run_r(OP_ADD, 3'd1, 3'd2, 3'd3);
        check_reg(3'd3, 8'd8,  "ADD 5+3");

        run_r(OP_SUB, 3'd1, 3'd2, 3'd6);
        check_reg(3'd6, 8'd2,  "SUB 5-3");

        run_r(OP_AND, 3'd4, 3'd5, 3'd7);
        check_reg(3'd7, 8'h00, "AND F0&0F");

        run_r(OP_XOR, 3'd4, 3'd5, 3'd7);
        check_reg(3'd7, 8'hFF, "XOR F0^0F");

        // === 边界: rs==rd 自读自写 ===
        run_r(OP_ADD, 3'd1, 3'd2, 3'd1);
        check_reg(3'd1, 8'd8,  "self rs==rd");

        // === zero flag: SUB 相等 -> zero=1 ===
        @(negedge clk);
        use_imm = 0; alu_op = OP_SUB; rs1 = 3'd2; rs2 = 3'd2; we = 0;
        #1;
        if (zero === 1'b1) pass_cnt = pass_cnt + 1;
        else begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL [zero flag]: SUB rf2-rf2, zero got=%b exp=1", zero);
        end

        $display("-------------------------------------");
        $display("TOP TB done: %0d PASS, %0d FAIL (total %0d)",
                 pass_cnt, fail_cnt, pass_cnt + fail_cnt);
        if (fail_cnt == 0) $display("ALL PASS");
        else $display(">>> %0d FAILED <<<", fail_cnt);
        $finish;
    end

endmodule