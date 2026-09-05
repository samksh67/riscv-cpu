`timescale 1ns/1ps
module tb_cpu;
    reg clk = 0, rst = 1;
    cpu dut(.clk(clk), .rst(rst));
    always #5 clk = ~clk;

    always @(negedge clk)
        $display("pc=%0d inst=%h m2r=%b alu=%0d memrd=%0d wdata=%0d rw=%b rd=%0d x3=%0d",
                 dut.pc, dut.inst, dut.mem_to_reg, dut.alu_result,
                 dut.mem_rdata, dut.write_data, dut.reg_write, dut.rd,
                 dut.u_rf.regs[3]);

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_cpu);

        // program: branch taken (x1 == x2, so skip the poison)
                // x1 = 5, x2 = 7, x3 = 5
               // jal: jump forward, save return address
        dut.imem[0] = 32'h123450B7;  // lui   x1, 0x12345   -> x1 = 0x12345000
        dut.imem[1] = 32'h00001117;  // auipc x2, 0x1       -> x2 = 4 + 0x1000
        dut.imem[2] = 32'h67808093;  // addi  x1, x1, 0x678 -> x1 = 0x12345678
        dut.imem[3] = 32'h00000013;  // nop
        dut.imem[4] = 32'h00000013;  // nop

        @(negedge clk); rst = 0;
        repeat (8) @(posedge clk);

        $display("x1 = %h (want 12345678 - lui + addi builds a 32-bit constant)", dut.u_rf.regs[1]);
        $display("x2 = %h (want 00001004 - auipc = pc + imm)", dut.u_rf.regs[2]);

        $finish;
    end
endmodule