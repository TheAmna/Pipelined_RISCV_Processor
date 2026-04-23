`timescale 1ns / 1ps

module mux2 (
    input  wire sel, // select signal
    input  wire [31:0] in0,  // input when sel = 0
    input  wire [31:0] in1, // input when sel = 1
    output reg  [31:0] out  // selected output
);

    always @(*) begin
        if (sel == 1'b0) begin
            out = in0;
        end
        else begin
            out = in1;
        end
    end

endmodule