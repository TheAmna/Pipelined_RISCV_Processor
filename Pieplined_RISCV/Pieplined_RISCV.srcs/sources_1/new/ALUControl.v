`timescale 1ns / 1ps

// ALUControl encoding:
// 4'b0000 AND
// 4'b0001 OR
// 4'b0010 ADD
// 4'b0110 SUB
// 4'b0100 XOR
// 4'b0111 SLT
// 4'b1000 SLL
// 4'b1001 SRL
//
// ALUOp decoding:
// 2'b00 Load/Store  -> ADD
// 2'b01 Branch      -> SUB (gives Zero for BEQ/BNE, blt for BLT/BGE)
// 2'b10 R-type      -> funct3 + funct7[5] decide operation
// 2'b11 I-arithmetic -> funct3 decides operation

module ALUControl (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] ALUControl
);
    always @(*) begin
        case (ALUOp)

            2'b00: ALUControl = 4'b0010;  // Load/Store -> ADD

            2'b01: ALUControl = 4'b0110;  // Branch -> SUB
                                          // Zero flag handles BEQ/BNE
                                          // blt  flag handles BLT/BGE

            2'b10: begin  // R-type
                case (funct3)
                    3'b000: begin
                        if (funct7[5] == 1'b1)
                            ALUControl = 4'b0110;  // SUB
                        else
                            ALUControl = 4'b0010;  // ADD
                    end
                    3'b001: ALUControl = 4'b1000;  // SLL
                    3'b010: ALUControl = 4'b0111;  // SLT
                    3'b100: ALUControl = 4'b0100;  // XOR
                    3'b101: ALUControl = 4'b1001;  // SRL
                    3'b110: ALUControl = 4'b0001;  // OR
                    3'b111: ALUControl = 4'b0000;  // AND
                    default: ALUControl = 4'b0010;
                endcase
            end

            2'b11: begin  // I-type arithmetic
                case (funct3)
                    3'b000: ALUControl = 4'b0010;  // ADDI
                    3'b111: ALUControl = 4'b0000;  // ANDI
                    3'b110: ALUControl = 4'b0001;  // ORI
                    3'b100: ALUControl = 4'b0100;  // XORI
                    3'b001: ALUControl = 4'b1000;  // SLLI
                    3'b101: ALUControl = 4'b1001;  // SRLI
                    default: ALUControl = 4'b0010;
                endcase
            end

            default: ALUControl = 4'b0010;

        endcase
    end
endmodule