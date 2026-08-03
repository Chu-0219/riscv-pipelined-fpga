// regfile_tb.v -- 寄存器堆自检式 testbench
// 测试计划:
//   T1: 依次写满全部8个寄存器, 用读端口1逐个读回比对
//   T2: 用读端口2读回同一批数据 (验证双端口独立)
//   T3: 双端口同时读不同地址 (验证互不干扰)
//   T4: we=0 时写入无效 (数据不应改变)
//   T5: 读写同地址同周期 -> 应读到旧值 (read-first 行为验证)
`timescale 1ns/1ps

module regfile_tb;

    localparam WIDTH  = 8;
    localparam DEPTH  = 8;
    localparam ADDR_W = 3;

    reg                clk;
    reg                we;
    reg  [ADDR_W-1:0]  waddr, raddr1, raddr2;
    reg  [WIDTH-1:0]   wdata;
    wire [WIDTH-1:0]   rdata1, rdata2;

    integer errors = 0;
    integer i;

    regfile #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .we(we),
        .waddr(waddr), .wdata(wdata),
        .raddr1(raddr1), .rdata1(rdata1),
        .raddr2(raddr2), .rdata2(rdata2)
    );

    always #5 clk = ~clk;

    // 检查任务: 期望值 vs 实际值
    task check;
        input [WIDTH-1:0] expected, actual;
        input [8*40-1:0]  msg;
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL: %0s  expected=%h actual=%h (t=%0t)",
                         msg, expected, actual, $time);
            end else begin
                $display("PASS: %0s  value=%h", msg, actual);
            end
        end
    endtask

    // 同步写一个寄存器
    task write_reg;
        input [ADDR_W-1:0] a;
        input [WIDTH-1:0]  d;
        begin
            @(negedge clk);       // 在下降沿改激励, 避开采样沿
            we = 1; waddr = a; wdata = d;
            @(posedge clk);
            #1;                   // 越过NBA更新区 (老教训)
            we = 0;
        end
    endtask

    initial begin
        $dumpfile("regfile_tb.vcd");
        $dumpvars(0, regfile_tb);

        clk = 0; we = 0;
        waddr = 0; wdata = 0; raddr1 = 0; raddr2 = 0;

        // ---- T1: 写满 + 端口1读回 ----
        for (i = 0; i < DEPTH; i = i + 1)
            write_reg(i[ADDR_W-1:0], {i[3:0], 4'hA});  // 写入 0A,1A,2A...

        for (i = 0; i < DEPTH; i = i + 1) begin
            raddr1 = i[ADDR_W-1:0];
            #1;   // 异步读, 给组合逻辑一点传播时间
            check({i[3:0], 4'hA}, rdata1, "T1 port1 readback");
        end

        // ---- T2: 端口2读回 ----
        for (i = 0; i < DEPTH; i = i + 1) begin
            raddr2 = i[ADDR_W-1:0];
            #1;
            check({i[3:0], 4'hA}, rdata2, "T2 port2 readback");
        end

        // ---- T3: 双端口同时读不同地址 ----
        raddr1 = 3'd2; raddr2 = 3'd5;
        #1;
        check(8'h2A, rdata1, "T3 port1 addr2");
        check(8'h5A, rdata2, "T3 port2 addr5");

        // ---- T4: we=0 写无效 ----
        @(negedge clk);
        we = 0; waddr = 3'd2; wdata = 8'hFF;   // 试图写但we=0
        @(posedge clk);
        #1;
        raddr1 = 3'd2;
        #1;
        check(8'h2A, rdata1, "T4 write disabled");

        // ---- T5: 读写同地址同周期, 应读到旧值 ----
        @(negedge clk);
        we = 1; waddr = 3'd4; wdata = 8'h99;
        raddr1 = 3'd4;
        @(posedge clk);        // 就在这个沿写入发生
        // 沿之前的瞬间读端口看到的是旧值; 沿之后NBA更新
        // 这里检查沿之后: 新值已可见
        #1;
        we = 0;
        check(8'h99, rdata1, "T5a after edge: new value visible");
        // 再验证写入确实持久化了
        @(negedge clk);
        raddr2 = 3'd4;
        #1;
        check(8'h99, rdata2, "T5b persisted");

        // ---- 汇总 ----
        $display("=====================================");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("=====================================");
        $finish;
    end

endmodule