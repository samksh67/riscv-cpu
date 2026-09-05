module dmem (
    input             clk,
    input      [31:0] addr,
    input      [31:0] wdata,
    input             we,
    output     [31:0] rdata
);
    reg [31:0] mem [0:255];      // 256 words = 1KB
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 32'b0;

    // combinational read
    assign rdata = mem[addr[9:2]];

    // clocked write
    always @(posedge clk)
        if (we) mem[addr[9:2]] <= wdata;
endmodule