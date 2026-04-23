`timescale 1ns / 1ps
// stores the current inst addr & updates on rising clk edge unless stalled.
// asynchronous reset sets PC back to 0x00000000.

module ProgramCounter (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,     // 1 = freeze PC (load-use hazard)
    input  wire [31:0] PC_Next,   // next address (from mux2)
    output reg  [31:0] PC         // current address (to instruction memory)
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            PC <= 32'h00000000;   // reset: start from address 0
        else if (stall)
            PC <= PC;             // freeze: hold current value
        else
            PC <= PC_Next;        // normal: advance to next address
    end
endmodule