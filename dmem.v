module dmem (
    input             clk,
    input      [31:0] addr,
    input      [31:0] wdata,
    input             we,
    input      [2:0]  funct3,
    output reg [31:0] rdata
);
    reg [31:0] mem [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 32'b0;

    wire [7:0] widx = addr[9:2];    // which word
    wire [1:0] boff = addr[1:0];    // which byte inside it
    wire [31:0] word = mem[widx];

    // ---- read: select and extend ----
    reg [7:0]  byte_sel;
    reg [15:0] half_sel;

    always @(*) begin
        case (boff)
            2'd0: byte_sel = word[7:0];
            2'd1: byte_sel = word[15:8];
            2'd2: byte_sel = word[23:16];
            2'd3: byte_sel = word[31:24];
        endcase

        half_sel = boff[1] ? word[31:16] : word[15:0];

        case (funct3)
            3'b000: rdata = {{24{byte_sel[7]}},  byte_sel};   // lb  - signed
            3'b001: rdata = {{16{half_sel[15]}}, half_sel};   // lh  - signed
            3'b010: rdata = word;                             // lw
            3'b100: rdata = {24'b0, byte_sel};                // lbu - unsigned
            3'b101: rdata = {16'b0, half_sel};                // lhu - unsigned
            default: rdata = word;
        endcase
    end

    // ---- write: merge into the existing word ----
    reg [31:0] merged;

    always @(*) begin
        merged = word;
        case (funct3)
            3'b000: case (boff)                    // sb
                2'd0: merged[7:0]   = wdata[7:0];
                2'd1: merged[15:8]  = wdata[7:0];
                2'd2: merged[23:16] = wdata[7:0];
                2'd3: merged[31:24] = wdata[7:0];
            endcase
            3'b001: if (boff[1]) merged[31:16] = wdata[15:0];  // sh
                    else         merged[15:0]  = wdata[15:0];
            default: merged = wdata;               // sw
        endcase
    end

    always @(posedge clk)
        if (we) mem[widx] <= merged;
endmodule