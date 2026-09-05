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
        dut.imem[0] = 32'h00C000EF;  // jal  x1, 12      -> jump to imem[3], x1 = 4
        dut.imem[1] = 32'h06300213;  // addi x4, x0, 99  (poison)
        dut.imem[2] = 32'h06300293;  // addi x5, x0, 99  (poison)
        dut.imem[3] = 32'h02A00313;  // addi x6, x0, 42  (landing spot)

        // jalr: jump to address in a register
        dut.imem[4] = 32'h01C00393;  // addi x7, x0, 28  -> target address
        dut.imem[5] = 32'h000384E7;  // jalr x9, x7, 0   -> jump to 20, x9 = 24
        dut.imem[6] = 32'h06300413;  // addi x8, x0, 99  (poison)

        dut.imem[7] = 32'h02A00513;  // addi x10, x0, 42 (landing spot, addr 28)
        dut.imem[8] = 32'h00000013;  // nop
        dut.imem[9] = 32'h00000013;  // nop

        @(negedge clk); rst = 0;
        repeat (12) @(posedge clk);

        $display("x1  = %0d (want 4  - jal return addr)",  dut.u_rf.regs[1]);
        $display("x4  = %0d (want 0  - jal skipped this)", dut.u_rf.regs[4]);
        $display("x5  = %0d (want 0  - jal skipped this)", dut.u_rf.regs[5]);
        $display("x6  = %0d (want 42 - jal landed here)",  dut.u_rf.regs[6]);
        $display("x9  = %0d (want 24 - jalr return addr)", dut.u_rf.regs[9]);
        $display("x8  = %0d (want 0  - jalr skipped this)", dut.u_rf.regs[8]);

        $finish;
    end
endmodule