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
        dut.imem[0]  = 32'h00500093;  // addi x1, x0, 5
        dut.imem[1]  = 32'h00700113;  // addi x2, x0, 7
        dut.imem[2]  = 32'h00500193;  // addi x3, x0, 5

        // bne x1, x2 (5 != 7, should take)
        dut.imem[3]  = 32'h00209463;  // bne x1, x2, 8  -> skip imem[4]
        dut.imem[4]  = 32'h06300213;  // addi x4, x0, 99  (poison)

        // blt x1, x2 (5 < 7 signed, should take)
        dut.imem[5]  = 32'h0020C463;  // blt x1, x2, 8  -> skip imem[6]
        dut.imem[6]  = 32'h06300293;  // addi x5, x0, 99  (poison)

        // bge x2, x1 (7 >= 5, should take)
        dut.imem[7]  = 32'h0010D463;  // bge x2, x1, 8  -> skip imem[8]
        dut.imem[8]  = 32'h06300313;  // addi x6, x0, 99  (poison)

        // beq x1, x3 (5 == 5, should take)
        dut.imem[9]  = 32'h00308463;  // beq x1, x3, 8  -> skip imem[10]
        dut.imem[10] = 32'h06300393;  // addi x7, x0, 99  (poison)

        // bne x1, x3 (5 == 5, should NOT take)
        dut.imem[11] = 32'h00309463;  // bne x1, x3, 8
        dut.imem[12] = 32'h02A00413;  // addi x8, x0, 42  (SHOULD run)

        dut.imem[13] = 32'h00000013;  // nop
        dut.imem[14] = 32'h00000013;  // nop

        @(negedge clk); rst = 0;
        repeat (16) @(posedge clk);

        $display("x4 = %0d (want 0  - bne taken)",     dut.u_rf.regs[4]);
        $display("x5 = %0d (want 0  - blt taken)",     dut.u_rf.regs[5]);
        $display("x6 = %0d (want 0  - bge taken)",     dut.u_rf.regs[6]);
        $display("x7 = %0d (want 0  - beq taken)",     dut.u_rf.regs[7]);
        $display("x8 = %0d (want 42 - bne NOT taken)", dut.u_rf.regs[8]);
        
        $finish;
    end
endmodule