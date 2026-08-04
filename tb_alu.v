`timescale 1ns/1ps
module tb_alu;
    reg  [31:0] a, b;
    reg  [3:0]  op;
    wire [31:0] result;
    integer errors = 0;

    alu dut(.a(a), .b(b), .op(op), .result(result));

    task check(input [255:0] name, input [31:0] expected);
        begin
            #1;
            if (result === expected) $display("PASS: %0s", name);
            else begin
                $display("FAIL: %0s  got %h  expected %h", name, result, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, tb_alu);

        a = 32'd10;      b = 32'd5;   op = 4'd0; check("ADD 10+5",       32'd15);
        a = 32'd10;      b = 32'd5;   op = 4'd1; check("SUB 10-5",       32'd5);
        a = 32'd5;       b = 32'd10;  op = 4'd1; check("SUB 5-10",       -32'd5);
        a = 32'hFF00FF00;b = 32'h0F0F0F0F; op = 4'd2; check("AND",       32'h0F000F00);
        a = 32'hFF00FF00;b = 32'h0F0F0F0F; op = 4'd3; check("OR",        32'hFF0FFF0F);
        a = 32'hFF00FF00;b = 32'h0F0F0F0F; op = 4'd4; check("XOR",       32'hF00FF00F);
        a = 32'd1;       b = 32'd4;   op = 4'd5; check("SLL 1<<4",       32'd16);
        a = 32'd16;      b = 32'd2;   op = 4'd6; check("SRL 16>>2",      32'd4);
        a = -32'd8;      b = 32'd1;   op = 4'd7; check("SRA -8>>>1",     -32'd4);
        a = -32'd8;      b = 32'd1;   op = 4'd6; check("SRL -8>>1",      32'h7FFFFFFC);
        a = -32'd5;      b = 32'd3;   op = 4'd8; check("SLT -5<3",       32'd1);
        a = -32'd5;      b = 32'd3;   op = 4'd9; check("SLTU -5<3",      32'd0);

        if (errors == 0) $display("=== ALL ALU TESTS PASSED ===");
        else $display("=== %0d FAILURES ===", errors);
        $finish;
    end
endmodule