module cpu (
    input clk,
    input rst
);
    // ---- program counter ----
    reg [31:0] pc;
    always @(posedge clk) begin
        if (rst) pc <= 32'd0;
        else     pc <= pc + 32'd4;
    end

    // ---- instruction memory (64 words) ----
    reg [31:0] imem [0:63];
    wire [31:0] inst = imem[pc[31:2]];   // pc/4 = word index

    // ---- decode ----
    wire [6:0]  opcode, funct7;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3;
    wire [31:0] imm;

    decoder u_dec(.inst(inst), .opcode(opcode), .rd(rd), .funct3(funct3),
                  .rs1(rs1), .rs2(rs2), .funct7(funct7), .imm(imm));

    // ---- control ----
    wire [3:0] alu_op;
    wire       reg_write, alu_src, mem_write, mem_to_reg;

    control u_ctrl(.opcode(opcode), .funct3(funct3), .funct7(funct7),
                   .alu_op(alu_op), .reg_write(reg_write), .alu_src(alu_src),
                   .mem_write(mem_write), .mem_to_reg(mem_to_reg));

    // ---- register file ----
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] alu_result;
    wire [31:0] mem_rdata;
    wire [31:0] write_data = mem_to_reg ? mem_rdata : alu_result;

    regfile u_rf(.clk(clk), .we(reg_write), .rd_addr(rd), .rd_data(write_data),
                 .rs1_addr(rs1), .rs2_addr(rs2),
                 .rs1_data(rs1_data), .rs2_data(rs2_data));

    // ---- the mux: rs2 or immediate? ----
    wire [31:0] alu_b = alu_src ? imm : rs2_data;

    // ---- execute ----
    alu u_alu(.a(rs1_data), .b(alu_b), .op(alu_op), .result(alu_result));

    dmem u_dmem(.clk(clk), .addr(alu_result), .wdata(rs2_data),
                .we(mem_write), .rdata(mem_rdata));
endmodule