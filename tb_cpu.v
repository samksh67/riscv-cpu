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
        dut.imem[0] = 32'h00500093;  // addi x1, x0, 5
        dut.imem[1] = 32'h00500113;  // addi x2, x0, 5
        dut.imem[2] = 32'h00208663;  // beq  x1, x2, 12   -> jump to imem[5]
        dut.imem[3] = 32'h063001B3;  // add  x3, x0, x3   (skipped)
        dut.imem[4] = 32'h06300213;  // addi x4, x0, 99   (skipped - poison)
        dut.imem[5] = 32'h02A00293;  // addi x5, x0, 42   (landing spot)
        dut.imem[6] = 32'h00000013;  // nop
        dut.imem[7] = 32'h00000013;  // nop

        @(negedge clk); rst = 0;
        repeat (10) @(posedge clk);

        $display("x1 = %0d (want 5)",  dut.u_rf.regs[1]);
        $display("x2 = %0d (want 5)",  dut.u_rf.regs[2]);
        $display("x4 = %0d (want 0 - branch should skip this)", dut.u_rf.regs[4]);
        $display("x5 = %0d (want 42)", dut.u_rf.regs[5]);

        $finish;
    end
endmodule