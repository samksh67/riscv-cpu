module top (
    input clk,
    input rst,
    output [7:0] led
);
    // divide 100MHz down — single-cycle CPU won't close timing near 100MHz
    reg [23:0] div = 24'd0;
    always @(posedge clk) div <= div + 1;
    wire slow_clk = div[23];        // about 6 Hz, slow enough to watch

    wire [31:0] dbg;
    cpu u_cpu(.clk(slow_clk), .rst(~rst), .dbg(dbg));

    assign led = dbg[7:0];
endmodule