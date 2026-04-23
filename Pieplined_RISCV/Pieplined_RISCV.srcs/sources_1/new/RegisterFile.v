//`timescale 1ns / 1ps
//module RegisterFile (
//    input  wire        clk,
//    input  wire        rst,
//    input  wire        WriteEnable,
//    input  wire [4:0]  rs1,
//    input  wire [4:0]  rs2,
//    input  wire [4:0]  rd,
//    input  wire [31:0] WriteData,
//    output wire [31:0] ReadData1,   // asynchronous read port 1
//    output wire [31:0] ReadData2    // asynchronous read port 2
//);
//    reg [31:0] regs [0:31];

    
//    integer i;
//    initial begin
//        for (i = 0; i < 32; i = i + 1)
//            regs[i] = i;          // regs[0]=0, regs[1]=1, regs[2]=2 ... regs[31]=31
//    end

//    // Synchronous write, asynchronous reset
//    // On reset: restore intial values
//    always @(posedge clk or posedge rst) begin
//        if (rst) begin
//            for (i = 0; i < 32; i = i + 1)
//                regs[i] <= i;     
//        end
//        else if (WriteEnable && (rd != 5'b00000)) begin
//            regs[rd] <= WriteData;
//        end
//    end

//    // Asynchronous read ports 
//    // x0 is hardwired to 0 
//    assign ReadData1 = (rs1 == 5'b00000) ? 32'b0 : regs[rs1];
//    assign ReadData2 = (rs2 == 5'b00000) ? 32'b0 : regs[rs2];

//endmodule



`timescale 1ns / 1ps
// ============================================================
// RegisterFile.v
// Lab 7
//
// 32 x 32-bit register file following RISC-V conventions.
//
// Key properties:
//   - x0 is hardwired to zero (reads always return 0,
//     writes to x0 are silently ignored)
//   - Two asynchronous read ports (combinational)
//   - One synchronous write port (rising clock edge)
//   - Asynchronous reset clears ALL registers to 0
//
// Fix applied:
//   Previously registers were initialised to their index
//   value (regs[i] = i) for debug purposes in Lab 7.
//   This caused x1=1, x2=2 etc. on reset which is wrong
//   for a real processor - the RISC-V ABI expects all
//   registers to be zero at startup unless explicitly set
//   by the program (e.g. sp is set by _start in assembly).
//   All registers now initialise and reset to 32'b0.
// ============================================================
module RegisterFile (
    input  wire        clk,
    input  wire        rst,
    input  wire        WriteEnable,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] WriteData,
    output wire [31:0] ReadData1,   // asynchronous read port 1
    output wire [31:0] ReadData2    // asynchronous read port 2
);

    reg [31:0] regs [0:31];

    integer i;

    // ----------------------------------------------------------
    // Power-on initialisation: all registers start at zero
    // ----------------------------------------------------------
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    // ----------------------------------------------------------
    // Synchronous write with asynchronous reset
    // Reset: all registers -> 0
    // Write: only when WriteEnable=1 and rd != 0
    // ----------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end
        else begin
            if (WriteEnable == 1'b1) begin
                if (rd != 5'b00000) begin
                    regs[rd] <= WriteData;
                end
            end
        end
    end

    // ----------------------------------------------------------
    // Asynchronous read ports
    // x0 always returns zero regardless of what is stored
    // ----------------------------------------------------------
    assign ReadData1 = (rs1 == 5'b00000) ? 32'b0 : regs[rs1];
    assign ReadData2 = (rs2 == 5'b00000) ? 32'b0 : regs[rs2];

endmodule