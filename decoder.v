module decoder (
    input  [31:0] inst,
    output [6:0]  opcode,
    output [4:0]  rd,
    output [2:0]  funct3,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [6:0]  funct7,
    output reg [31:0] imm
);
    // pure wire-splitting, no logic
    assign opcode = inst[6:0];
    assign rd     = inst[11:7];
    assign funct3 = inst[14:12];
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign funct7 = inst[31:25];

    localparam OP_R     = 7'b0110011;  // add, sub, and, or...
    localparam OP_I     = 7'b0010011;  // addi, andi, ori...
    localparam OP_LOAD  = 7'b0000011;  // lw, lb...
    localparam OP_STORE = 7'b0100011;  // sw, sb...
    localparam OP_BR    = 7'b1100011;  // beq, bne...

    always @(*) begin
        case (opcode)
            OP_I, OP_LOAD:
                imm = {{20{inst[31]}}, inst[31:20]};

            OP_STORE:
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

            OP_BR:
                imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};

            default:
                imm = 32'b0;   // R-type has no immediate
        endcase
    end
endmodule