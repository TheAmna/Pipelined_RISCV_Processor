`timescale 1ns / 1ps
module clock_divider #(
    parameter MAX_COUNT = 25_000_000
)(
    input  wire clk,
    input  wire rst,
    output wire slow_clk
);
    reg [$clog2(MAX_COUNT)-1 : 0] count;
    initial count = 0;
    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else begin
            if (count == MAX_COUNT - 1) begin
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
    // slow clk only high when reached max val
    assign slow_clk = (count == MAX_COUNT - 1) ? 1'b1 : 1'b0;
endmodule