// sync_ram_tb.v -- 同步RAM自检式testbench
// 测试计划:
//   T1: $readmemh 预加载验证 (地址0~7 顺序数据)
//   T2: @0C 地址跳转加载验证 (地址12,13)
//   T3: 写入后读回
//   T4: 同步读延迟验证 -- 地址变化后需等1个时钟沿数据才更新
`timescale 1ns/1ps

module sync_ram_tb;

    localparam WIDTH  = 8;
    localparam DEPTH  = 16;
    localparam ADDR_W = 4;

    reg                clk;
    reg                we;
    reg  [ADDR_W-1:0]  addr;
    reg  [WIDTH-1:0]   din;
    wire [WIDTH-1:0]   dout;

    integer errors = 0;
    integer i;

    // 注意: 路径相对于运行 vvp 的目录 (仓库根目录)
    sync_ram #(
        .WIDTH(WIDTH), .DEPTH(DEPTH),
        .INIT_FILE("tb/practice/ram_init.hex")
    ) dut (
        .clk(clk), .we(we),
        .addr(addr), .din(din), .dout(dout)
    );

    always #5 clk = ~clk;

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

    // 同步读: 给地址, 等一个时钟沿, 数据才有效
    task read_check;
        input [ADDR_W-1:0] a;
        input [WIDTH-1:0]  expected;
        input [8*40-1:0]   msg;
        begin
            @(negedge clk);
            we = 0; addr = a;
            @(posedge clk);   // 地址在这个沿被采样
            #1;               // 越过NBA, dout 更新为 mem[a]
            check(expected, dout, msg);
        end
    endtask

    task write_ram;
        input [ADDR_W-1:0] a;
        input [WIDTH-1:0]  d;
        begin
            @(negedge clk);
            we = 1; addr = a; din = d;
            @(posedge clk);
            #1;
            we = 0;
        end
    endtask

    initial begin
        $dumpfile("sync_ram_tb.vcd");
        $dumpvars(0, sync_ram_tb);

        clk = 0; we = 0; addr = 0; din = 0;

        // ---- T1: 预加载数据 0~7 ----
        for (i = 0; i < 8; i = i + 1)
            read_check(i[ADDR_W-1:0], {i[3:0], i[3:0]} & 8'h77,
                       "T1 preload");
        // 期望值 00,11,22...77: 即 {i,i} => 用下面这行更直观也行:
        // read_check(i, {i[3:0], i[3:0]}, "T1 preload");

        // ---- T2: @0C 跳转加载 ----
        read_check(4'hC, 8'hAB, "T2 jump-load addr C");
        read_check(4'hD, 8'hCD, "T2 jump-load addr D");

        // ---- T3: 写后读回 ----
        write_ram(4'h9, 8'h5E);
        read_check(4'h9, 8'h5E, "T3 write-readback");

        // ---- T4: 同步读延迟验证 ----
        // 先把 dout 稳定在地址0的值, 然后改地址,
        // 在时钟沿到来之前 dout 不应该变
        @(negedge clk);
        we = 0; addr = 4'h0;
        @(posedge clk); #1;          // dout = mem[0] = 00
        @(negedge clk);
        addr = 4'h1;                 // 地址变了, 但还没到时钟沿
        #1;
        check(8'h00, dout, "T4a before edge: old data holds");
        @(posedge clk); #1;          // 沿之后才更新
        check(8'h11, dout, "T4b after edge: new data");

        $display("=====================================");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("=====================================");
        $finish;
    end

endmodule