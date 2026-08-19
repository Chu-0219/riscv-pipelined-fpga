`timescale 1ns/1ps
module tb_dmem;
    reg         clk = 0, we = 0;
    reg  [31:0] addr = 0, wdata = 0;
    wire [31:0] rdata;
    integer errors = 0, checks = 0;

    dmem #(.DEPTH(256)) dut (.clk(clk), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata));

    always #5 clk = ~clk;

    task check;
        input [31:0]  got;
        input [31:0]  exp;
        input [255:0] name;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: got=%h exp=%h", name, got, exp);
            end
        end
    endtask

    task wr;                       // 在一个时钟沿写入一个字
        input [31:0] a;
        input [31:0] d;
        begin
            @(negedge clk);
            we = 1; addr = a; wdata = d;
            @(negedge clk);
            we = 0;
        end
    endtask

    initial begin
        wr(32'd0, 32'hDEAD_BEEF);
        addr = 32'd0; #1; check(rdata, 32'hDEAD_BEEF, "write/read addr 0");

        wr(32'd4, 32'h1234_5678);
        addr = 32'd4; #1; check(rdata, 32'h1234_5678, "write/read addr 4");
        addr = 32'd0; #1; check(rdata, 32'hDEAD_BEEF, "addr 0 untouched");

        // we=0 不得写入
        @(negedge clk);
        we = 0; addr = 32'd0; wdata = 32'hFFFF_FFFF;
        @(negedge clk); #1;
        addr = 32'd0; #1; check(rdata, 32'hDEAD_BEEF, "we=0 no write");

        wr(32'd0, 32'h0000_0001);
        addr = 32'd0; #1; check(rdata, 32'h0000_0001, "overwrite addr 0");

        wr(32'd8, 32'hA5A5_A5A5);
        addr = 32'd8; #1; check(rdata, 32'hA5A5_A5A5, "addr 8");

        // 边界：最后一个字 (255*4 = 1020)
        wr(32'd1020, 32'h5A5A_5A5A);
        addr = 32'd1020; #1; check(rdata, 32'h5A5A_5A5A, "addr 1020 boundary");

        // 低两位忽略
        addr = 32'd6; #1; check(rdata, 32'h1234_5678, "addr 6 aliases 4");
        addr = 32'd10; #1; check(rdata, 32'hA5A5_A5A5, "addr 10 aliases 8");

        // 写地址也忽略低两位
        wr(32'd5, 32'h0BAD_F00D);
        addr = 32'd4; #1; check(rdata, 32'h0BAD_F00D, "write addr 5 hits word 1");

        $display("tb_dmem: %0d/%0d passed", checks - errors, checks);
        if (errors == 0) $display("PASS"); else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule