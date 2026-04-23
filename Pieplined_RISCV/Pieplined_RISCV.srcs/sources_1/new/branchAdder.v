`timescale 1ns / 1ps

module branchAdder (
    input  wire [31:0] PC,  // current PC
    input  wire [31:0] imm, // sign-extended immediate from immGen
    output wire [31:0] BranchTarget 
);
    assign BranchTarget = PC + imm ;
endmodule