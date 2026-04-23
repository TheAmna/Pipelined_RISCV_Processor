`timescale 1ns / 1ps
module tb_TopLevelProcessor();

    reg clk;
    reg rst;
    reg [31:0] cycle_count = 0;

    TopLevelProcessor uut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #10 rst = 1'b0;
    end

    always @(posedge clk) begin
        if (rst == 1'b0) begin
            cycle_count <= cycle_count + 1;
        end
    end

    initial begin
        // wait until PC reaches end of program
        // 6 instructions * 4 bytes = 0x18
        // single cycle so one extra posedge is enough
        // to let the last instruction complete writeback
        wait (uut.PC == 32'h00000018);
        @(posedge clk);
        @(posedge clk);

        $finish;
    end

endmodule