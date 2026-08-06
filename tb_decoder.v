`timescale 1ns/1ps
module tb_decoder;
    reg  [31:0] inst;
    wire [6:0]  opcode, funct7;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3;
    wire [31:0] imm;
    integer errors = 0;

    decoder dut(.inst(inst), .opcode(opcode), .rd(rd), .funct3(funct3),
                .rs1(rs1), .rs2(rs2), .funct7(funct7), .imm(imm));

    task check(input [255:0] name, input [4:0] e_rd, input [4:0] e_rs1,
               input [4:0] e_rs2, input [31:0] e_imm);
        begin
            #1;
            if (rd === e_rd && rs1 === e_rs1 && rs2 === e_rs2 && imm === e_imm)
                $display("PASS: %0s", name);
            else begin
                $display("FAIL: %0s", name);
                $display("      rd=%0d (want %0d)  rs1=%0d (want %0d)  rs2=%0d (want %0d)  imm=%0d (want %0d)",
                         rd, e_rd, rs1, e_rs1, rs2, e_rs2, $signed(imm), $signed(e_imm));
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("decoder.vcd");
        $dumpvars(0, tb_decoder);

        //                              rd  rs1 rs2  imm
        inst = 32'h002081B3; check("add x3,x1,x2",   3,  1,  2,  0);
        inst = 32'h402081B3; check("sub x3,x1,x2",   3,  1,  2,  0);
        inst = 32'h00A00093; check("addi x1,x0,10",  1,  0,  10, 10);
        inst = 32'hFFF00093; check("addi x1,x0,-1",  1,  0,  31, -1);
        inst = 32'h00812283; check("lw x5,8(x2)",    5,  2,  8,  8);
        inst = 32'h00512623; check("sw x5,12(x2)",   12, 2,  5,  12);
        inst = 32'h00208863; check("beq x1,x2,16",   16, 1,  2,  16);

        if (errors == 0) $display("=== ALL DECODER TESTS PASSED ===");
        else $display("=== %0d FAILURES ===", errors);
        $finish;
    end
endmodule