`timescale 1ns/1ps
module tb_cpu;
    reg clk = 0, rst = 1;
    cpu dut(.clk(clk), .rst(rst));
    always #5 clk = ~clk;

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_cpu);

        // program:
        dut.imem[0] = 32'h00500093;  // addi x1, x0, 5
        dut.imem[1] = 32'h00700113;  // addi x2, x0, 7
        dut.imem[2] = 32'h002081B3;  // add  x3, x1, x2
        dut.imem[3] = 32'h40208233;  // sub  x4, x1, x2
        dut.imem[4] = 32'h0020F2B3;  // and  x5, x1, x2
        dut.imem[5] = 32'h0020E333;  // or   x6, x1, x2

        @(negedge clk); rst = 0;
        repeat (8) @(posedge clk);

        $display("x1 = %0d (want 5)",  dut.u_rf.regs[1]);
        $display("x2 = %0d (want 7)",  dut.u_rf.regs[2]);
        $display("x3 = %0d (want 12)", dut.u_rf.regs[3]);
        $display("x4 = %0d (want -2)", $signed(dut.u_rf.regs[4]));
        $display("x5 = %0d (want 5)",  dut.u_rf.regs[5]);
        $display("x6 = %0d (want 7)",  dut.u_rf.regs[6]);

        $finish;
    end
endmodule