`timescale 1ns / 1ps
//R-type:ADD, SUB, SLL, SRL, AND, OR, XOR  (opcode = 0110011)
//I-type: ADDI (opcode = 0010011)
//Load  : LW, LH, LB  (opcode = 0000011)
//Store: SW, SH, SB  (opcode = 0100011)
//Branch:  (opcode = 1100011)
// ALUOp:
//2'b10 R-type  
//2'b11 I-type arithmetic 
//2'b00 Load/Store 
//2'b01 Branch 

module MainControl (  //input - opcode output- all signals
    input  wire [6:0] opcode,
    output reg        RegWrite,
    output reg        ALUSrc,
    output reg        MemRead,
    output reg        MemWrite,
    output reg        MemtoReg,
    output reg        Branch,
    output reg [1:0]  ALUOp
);
    localparam R_TYPE  = 7'b0110011;   // ADD SUB SLL SRL AND OR XOR
    localparam I_ARITH = 7'b0010011;   // ADDI 
    localparam LOAD    = 7'b0000011;   // LW LH LB
    localparam STORE   = 7'b0100011;   // SW SH SB
    localparam BRANCH  = 7'b1100011;   // BEQ

    always @(*) begin //signals set to 0
        RegWrite = 1'b0;
        ALUSrc   = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        MemtoReg = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;

        case (opcode) // ALUOp=10  (ALUControl decides operation)
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b0;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemtoReg = 1'b0;
                Branch   = 1'b0;
                ALUOp    = 2'b10;
            end  
        
            I_ARITH: begin //ALUOp=11 (add)
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemtoReg = 1'b0;
                Branch   = 1'b0;
                ALUOp    = 2'b11;
            end
            
            LOAD: begin   // ALUOp=00 (add)
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                MemRead  = 1'b1;
                MemWrite = 1'b0;
                MemtoReg = 1'b1;
                Branch   = 1'b0;
                ALUOp    = 2'b00;
            end
            
            STORE: begin // ALUOp=00  (add)
                RegWrite = 1'b0;
                ALUSrc   = 1'b1;
                MemRead  = 1'b0;
                MemWrite = 1'b1;
                MemtoReg = 1'b0; // X, don't care
                Branch   = 1'b0;
                ALUOp    = 2'b00;
            end

            BRANCH: begin  // ALUOp=01  (subtract)
                RegWrite = 1'b0;
                ALUSrc   = 1'b0;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemtoReg = 1'b0; //X, don't care
                Branch   = 1'b1;
                ALUOp    = 2'b01;
            end
            // Default: all signals off
            default: begin
                RegWrite = 1'b0;
                ALUSrc   = 1'b0;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemtoReg = 1'b0;
                Branch   = 1'b0;
                ALUOp    = 2'b00;
            end
        endcase
    end
endmodule