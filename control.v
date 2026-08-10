module control (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg [3:0] alu_op,
    output reg       reg_write,   // write result back to a register?
    output reg       alu_src      // 0 = use rs2, 1 = use immediate
);
    localparam OP_R = 7'b0110011;
    localparam OP_I = 7'b0010011;

    always @(*) begin
        // safe defaults
        alu_op    = 4'd0;
        reg_write = 1'b0;
        alu_src   = 1'b0;

        case (opcode)
            OP_R: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;          // second operand is rs2
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? 4'd1 : 4'd0;  // sub : add
                    3'b111: alu_op = 4'd2;   // and
                    3'b110: alu_op = 4'd3;   // or
                    3'b100: alu_op = 4'd4;   // xor
                    3'b001: alu_op = 4'd5;   // sll
                    3'b101: alu_op = (funct7[5]) ? 4'd7 : 4'd6;  // sra : srl
                    3'b010: alu_op = 4'd8;   // slt
                    3'b011: alu_op = 4'd9;   // sltu
                endcase
            end

            OP_I: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;          // second operand is the immediate
                case (funct3)
                    3'b000: alu_op = 4'd0;   // addi
                    3'b111: alu_op = 4'd2;   // andi
                    3'b110: alu_op = 4'd3;   // ori
                    3'b100: alu_op = 4'd4;   // xori
                    3'b001: alu_op = 4'd5;   // slli
                    3'b101: alu_op = (funct7[5]) ? 4'd7 : 4'd6;  // srai : srli
                    3'b010: alu_op = 4'd8;   // slti
                    3'b011: alu_op = 4'd9;   // sltiu
                endcase
            end
        endcase
    end
endmodule