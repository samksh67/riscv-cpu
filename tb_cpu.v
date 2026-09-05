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

        // 
        dut.imem[0]  = 32'h123450B7;  // lui  x1, 0x12345
        dut.imem[1]  = 32'h67808093;  // addi x1, x1, 0x678   -> x1 = 0x12345678
        dut.imem[2]  = 32'h02000113;  // addi x2, x0, 32      -> base address

        dut.imem[3]  = 32'h00112023;  // sw   x1, 0(x2)       -> mem[8] = 0x12345678

        dut.imem[4]  = 32'h00010183;  // lb   x3, 0(x2)       -> 0x78 = 120
        dut.imem[5]  = 32'h00214203;  // lbu  x4, 2(x2)       -> 0x34 = 52
        dut.imem[6]  = 32'h00011283;  // lh   x5, 0(x2)       -> 0x5678 = 22136
        dut.imem[7]  = 32'h00215303;  // lhu  x6, 2(x2)       -> 0x1234 = 4660

        dut.imem[8]  = 32'h0FF00393;  // addi x7, x0, 255     -> 0xFF
        dut.imem[9]  = 32'h007101A3;  // sb   x7, 3(x2)       -> top byte = FF
        dut.imem[10] = 32'h00012403;  // lw   x8, 0(x2)       -> 0xFF345678

        dut.imem[11] = 32'h00000013;  // nop
        dut.imem[12] = 32'h00000013;  // nop

        @(negedge clk); rst = 0;
        repeat (16) @(posedge clk);

        $display("x3 = %0d (want 120   - lb  byte 0)",  $signed(dut.u_rf.regs[3]));
        $display("x4 = %0d (want 52    - lbu byte 2)",  dut.u_rf.regs[4]);
        $display("x5 = %0d (want 22136 - lh  half 0)",  $signed(dut.u_rf.regs[5]));
        $display("x6 = %0d (want 4660  - lhu half 1)",  dut.u_rf.regs[6]);
        $display("x8 = %h (want ff345678 - sb wrote only the top byte)", dut.u_rf.regs[8]);

        $finish;
    end
endmodule