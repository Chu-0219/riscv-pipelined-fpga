`timescale 1ns/1ps
module tb_imem;
    reg  [31:0] addr;
    wire [31:0] instr;
    integer errors = 0, checks = 0;

    imem #(.DEPTH(256), .INIT_FILE("tb/prog_imem.hex")) dut (.addr(addr), .instr(instr));

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

    initial begin
        addr = 32'd0;  #1; check(instr, 32'h00500093, "word 0");
        addr = 32'd4;  #1; check(instr, 32'h00A00113, "word 1");
        addr = 32'd8;  #1; check(instr, 32'h002081B3, "word 2");
        addr = 32'd12; #1; check(instr, 32'h40110233, "word 3");
        addr = 32'd16; #1; check(instr, 32'h0000A283, "word 4");
        addr = 32'd20; #1; check(instr, 32'h00502223, "word 5");
        addr = 32'd24; #1; check(instr, 32'hFE000CE3, "word 6");
        addr = 32'd28; #1; check(instr, 32'h00000013, "word 7");

        // 低两位必须被忽略
        addr = 32'd5;  #1; check(instr, 32'h00A00113, "addr 5 aliases 4");
        addr = 32'd7;  #1; check(instr, 32'h00A00113, "addr 7 aliases 4");

        $display("tb_imem: %0d/%0d passed", checks - errors, checks);
        if (errors == 0) $display("PASS"); else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule