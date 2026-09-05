module control (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg [3:0] alu_op,
    output reg       reg_write,
    output reg       alu_src,
    output reg       mem_write,
    output reg       mem_to_reg,
    output reg       branch,
    output reg       jump,
    output reg       jalr
);
    localparam OP_R = 7'b0110011;
    localparam OP_I = 7'b0010011;
    localparam OP_LOAD  = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_BR = 7'b1100011;
    localparam OP_JAL  = 7'b1101111;
    localparam OP_JALR = 7'b1100111;


    always @(*) begin
        // safe defaults
        alu_op     = 4'd0;
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        jalr = 1'b0;

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

            OP_LOAD: begin
                reg_write  = 1'b1;   // writes a register
                alu_src    = 1'b1;   // address = rs1 + immediate
                alu_op     = 4'd0;   // add
                mem_to_reg = 1'b1;   // the value comes from memory, not the ALU
            end

            OP_STORE: begin
                reg_write  = 1'b0;   // writes nothing to registers
                alu_src    = 1'b1;   // address = rs1 + immediate
                alu_op     = 4'd0;   // add
                mem_write  = 1'b1;   // writes memory instead
            end

            OP_BR: begin
                reg_write = 1'b0;
                alu_src   = 1'b0;
                branch    = 1'b1;
                case (funct3)
                    3'b000: alu_op = 4'd1;   // beq  - subtract, check zero
                    3'b001: alu_op = 4'd1;   // bne  - subtract, check not zero
                    3'b100: alu_op = 4'd8;   // blt  - slt
                    3'b101: alu_op = 4'd8;   // bge  - slt, inverted
                    3'b110: alu_op = 4'd9;   // bltu - sltu
                    3'b111: alu_op = 4'd9;   // bgeu - sltu, inverted
                endcase
            end

            OP_JAL: begin
                reg_write = 1'b1;   // saves return address
                jump      = 1'b1;
            end

            OP_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 4'd0;   // rs1 + imm
                jump      = 1'b1;
                jalr      = 1'b1;
            end
        endcase
    end
endmodule