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

        // program:
        dut.imem[0] = 32'h02A00093;  // addi x1, x0, 42
        dut.imem[1] = 32'h00000113;  // addi x2, x0, 0
        dut.imem[2] = 32'h00112A23;  // sw   x1, 20(x2)   -> mem[5] = 42
        dut.imem[3] = 32'h01414183;  // lw   x3, 20(x2)   -> x3 = 42
        dut.imem[4] = 32'h00000013;  // nop
        dut.imem[5] = 32'h00000013;  // nop

        @(negedge clk); rst = 0;
        repeat (8) @(posedge clk);

        $display("x1 = %0d (want 42)", dut.u_rf.regs[1]);
        $display("x3 = %0d (want 42)", dut.u_rf.regs[3]);
        $display("mem[5] = %0d (want 42)", dut.u_dmem.mem[5]);

        $finish;
    end
endmodule