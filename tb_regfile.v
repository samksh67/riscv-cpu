`timescale 1ns/1ps
module tb_regfile;
    reg clk = 0, we = 0;
    reg [4:0] rd_addr = 0, rs1_addr = 0, rs2_addr = 0;
    reg [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data;

    regfile dut(.clk(clk), .we(we), .rd_addr(rd_addr), .rd_data(rd_data),
                .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
                .rs1_data(rs1_data), .rs2_data(rs2_data));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("regfile.vcd");
        $dumpvars(0, tb_regfile);
        $dumpvars(0, dut.regs[5]);

        @(negedge clk); we = 1; rd_addr = 5; rd_data = 32'hDEADBEEF;
        @(negedge clk); we = 0; rs1_addr = 5; #1;
        if (rs1_data === 32'hDEADBEEF) $display("PASS: x5 holds value");
        else $display("FAIL: x5 = %h", rs1_data);

        @(negedge clk); we = 1; rd_addr = 0; rd_data = 32'h12345678;
        @(negedge clk); we = 0; rs1_addr = 0; #1;
        if (rs1_data === 32'b0) $display("PASS: x0 stayed zero");
        else $display("FAIL: x0 = %h", rs1_data);

        #20 $finish;
    end
endmodule