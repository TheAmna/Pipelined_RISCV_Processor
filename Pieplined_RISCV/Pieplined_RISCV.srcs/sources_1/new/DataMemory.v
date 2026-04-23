`timescale 1ns / 1ps
module DataMemory (
    input  wire        clk,
    input  wire        MemWrite,   // write enable 
    input  wire        MemRead,    // read  enable 
    input  wire [31:0] address,    // full address
    input  wire [31:0] write_data,
    output reg  [31:0] read_data
);
    // 512 words of 32 bits
    reg [31:0] mem [0:511];
    integer i; //initialising 
    initial begin
        for (i = 0; i < 512; i = i + 1)begin
            mem[i] = 32'd0;
        end
                // array {23,12,5,44,98,53,6,89,32,65} at word addresses 10-19
        mem[10] = 32'd23;
        mem[11] = 32'd12;
        mem[12] = 32'd5;
        mem[13] = 32'd44;
        mem[14] = 32'd98;
        mem[15] = 32'd53;
        mem[16] = 32'd6;
        mem[17] = 32'd89;
        mem[18] = 32'd32;
        mem[19] = 32'd65;

    end
    // Synchronous write
    always @(posedge clk) begin
        if (MemWrite)
            mem[address[8:0]] <= write_data;
    end
    // Asynchronous (combinational) read
    always @(*) begin
            read_data = mem[address[8:0]];
    end
endmodule