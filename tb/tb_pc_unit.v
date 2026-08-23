`timescale 1ns/1ps
module tb_pc_unit;
    reg         clk = 0, rst = 1, pc_src = 0, jalr = 0;
    reg  [31:0] imm = 32'd0, alu_result = 32'd0;
    wire [31:0] pc, pc_plus4, pc_target;
    integer errors = 0, checks = 0;

    pc_unit dut (.clk(clk), .rst(rst), .pc_src(pc_src), .jalr(jalr),
                 .alu_result(alu_result), .imm(imm),
                 .pc(pc), .pc_plus4(pc_plus4), .pc_target(pc_target));

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

    initial begin
        @(negedge clk); #1;
        check(pc,       32'd0, "reset pc=0");
        check(pc_plus4, 32'd4, "pc+4 after reset");

        rst = 0;
        @(negedge clk); #1; check(pc, 32'd4,  "seq 1");
        @(negedge clk); #1; check(pc, 32'd8,  "seq 2");
        @(negedge clk); #1; check(pc, 32'd12, "seq 3");
        check(pc_plus4, 32'd16, "pc+4 comb");

        pc_src = 1; imm = 32'd16; #1;
        check(pc_target, 32'd28, "target comb +16");
        @(negedge clk); #1; check(pc, 32'd28, "branch fwd taken");

        imm = -32'd8; #1;
        check(pc_target, 32'd20, "target comb -8");
        @(negedge clk); #1; check(pc, 32'd20, "branch back taken");

        pc_src = 0; #1;
        @(negedge clk); #1; check(pc, 32'd24, "seq after branch");

        // ---- JALR target: comes from the ALU (rs1 + imm), low bit forced to 0
        // The immediate is left at a non-zero value on purpose: the JALR target
        // must ignore it entirely and follow alu_result alone.
        jalr       = 1'b1;
        alu_result = 32'h0000_1234;
        #1;
        check(pc_target, 32'h0000_1234, "jalr target even");

        alu_result = 32'h0000_1235;
        #1;
        check(pc_target, 32'h0000_1234, "jalr target low bit cleared");

        jalr = 1'b0;
        #1;

        rst = 1;
        @(negedge clk); #1; check(pc, 32'd0, "sync reset mid-run");

        $display("tb_pc_unit: %0d/%0d passed", checks - errors, checks);
        if (errors == 0) $display("PASS"); else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
