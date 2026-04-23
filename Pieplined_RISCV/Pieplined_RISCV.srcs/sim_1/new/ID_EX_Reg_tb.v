`timescale 1ns / 1ps

module ID_EX_Reg_tb();
reg clk;
reg rst;
reg flush;
reg stall;

reg        ID_ALUSrc;
reg [1:0]  ID_ALUOp;
reg [2:0]  ID_BranchType;
reg        ID_Branch;
reg        ID_Jump;
reg        ID_MemRead;
reg        ID_MemWrite;
reg        ID_RegWrite;
reg        ID_MemtoReg;

reg [4:0]  ID_rs1;        // source register 1
reg [4:0]  ID_rs2;        // source register 2
reg [4:0]  ID_rd;         // destination register
reg [2:0]  ID_funct3;
reg [6:0]  ID_funct7;

reg [31:0] ID_PC;         // pc going into EX
reg [31:0] ID_PC_Plus4;
reg [31:0] ID_ReadData1;  // rs1 data
reg [31:0] ID_ReadData2;  // rs2 data
reg [31:0] ID_Imm;        // immediate value

wire        EX_ALUSrc;
wire [1:0]  EX_ALUOp;
wire [2:0]  EX_BranchType;
wire        EX_Branch;
wire        EX_Jump;
wire        EX_MemRead;
wire        EX_MemWrite;
wire        EX_RegWrite;
wire        EX_MemtoReg;

wire [4:0]  EX_rs1;
wire [4:0]  EX_rs2;
wire [4:0]  EX_rd;
wire [2:0]  EX_funct3;
wire [6:0]  EX_funct7;

wire [31:0] EX_PC;
wire [31:0] EX_PC_Plus4;
wire [31:0] EX_ReadData1;
wire [31:0] EX_ReadData2;
wire [31:0] EX_Imm;

// creating the ID_EX pipeline register
ID_EX_Reg e1(
    clk,
    rst,
    flush,
    stall,
    ID_PC,
    ID_PC_Plus4,
    ID_ReadData1,
    ID_ReadData2,
    ID_Imm,
    ID_rs1,
    ID_rs2,
    ID_rd,
    ID_funct3,
    ID_funct7,
    ID_ALUSrc,
    ID_ALUOp,
    ID_BranchType,
    ID_Branch,
    ID_Jump,
    ID_MemRead,
    ID_MemWrite,
    ID_RegWrite,
    ID_MemtoReg,
    EX_PC,
    EX_PC_Plus4,
    EX_ReadData1,
    EX_ReadData2,
    EX_Imm,
    EX_rs1,
    EX_rs2,
    EX_rd,
    EX_funct3,
    EX_funct7,
    EX_ALUSrc,
    EX_ALUOp,
    EX_BranchType,
    EX_Branch,
    EX_Jump,
    EX_MemRead,
    EX_MemWrite,
    EX_RegWrite,
    EX_MemtoReg
);

initial begin
    // initial values
    clk           = 1'b0;
    rst           = 1'b0;
    flush         = 1'b0;
    stall         = 1'b0;

    ID_ALUSrc     = 1'b0;
    ID_ALUOp      = 2'b00;
    ID_BranchType = 3'b000;
    ID_Branch     = 1'b0;
    ID_Jump       = 1'b0;
    ID_MemRead    = 1'b0;
    ID_MemWrite   = 1'b0;
    ID_RegWrite   = 1'b0;
    ID_MemtoReg   = 1'b0;

    ID_rs1        = 5'd0;
    ID_rs2        = 5'd0;
    ID_rd         = 5'd0;
    ID_funct3     = 3'b000;
    ID_funct7     = 7'b0000000;

    ID_PC         = 32'h00000000;
    ID_PC_Plus4   = 32'h00000000;
    ID_ReadData1  = 32'd0;
    ID_ReadData2  = 32'd0;
    ID_Imm        = 32'd0;

    // apply reset
    #10 rst = 1'b1;
    #10 rst = 1'b0;

    // --------------------------------------------------
    // instruction: 32'h00400113  (addi x2, x0, 4)
    // --------------------------------------------------
    #10;
    ID_Branch     = 1'b0;
    ID_MemRead    = 1'b0;
    ID_MemWrite   = 1'b0;
    ID_MemtoReg   = 1'b0;
    ID_RegWrite   = 1'b1;      // write back enabled
    ID_ALUSrc     = 1'b1;      // use immediate
    ID_ALUOp      = 2'b11;     // I-type arithmetic

    ID_funct3     = 3'b000;
    ID_funct7     = 7'b0000000;
    ID_rs1        = 5'd0;      // x0
    ID_rs2        = 5'd0;      // not used
    ID_rd         = 5'd2;      // x2

    ID_PC         = 32'h00000000;
    ID_PC_Plus4   = 32'h00000004;
    ID_ReadData1  = 32'd0;     // x0 = 0
    ID_ReadData2  = 32'd0;
    ID_Imm        = 32'h00000004; // immediate = 4

    // --------------------------------------------------
    // instruction: 32'h00500193  (addi x3, x0, 5)
    // --------------------------------------------------
    #20;
    ID_Branch     = 1'b0;
    ID_MemRead    = 1'b0;
    ID_MemWrite   = 1'b0;
    ID_MemtoReg   = 1'b0;
    ID_RegWrite   = 1'b1;      // write back enabled
    ID_ALUSrc     = 1'b1;      // use immediate
    ID_ALUOp      = 2'b11;     // I-type arithmetic

    ID_funct3     = 3'b000;
    ID_funct7     = 7'b0000000;
    ID_rs1        = 5'd0;      // x0
    ID_rs2        = 5'd0;      // not used
    ID_rd         = 5'd3;      // x3

    ID_PC         = 32'h00000004;
    ID_PC_Plus4   = 32'h00000008;
    ID_ReadData1  = 32'd0;     // x0 = 0
    ID_ReadData2  = 32'd0;
    ID_Imm        = 32'h00000005; // immediate = 5

    // --------------------------------------------------
    // instruction: 32'h00310233  (add x4, x2, x3)
    // --------------------------------------------------
    #20;
    ID_Branch     = 1'b0;
    ID_MemRead    = 1'b0;
    ID_MemWrite   = 1'b0;
    ID_MemtoReg   = 1'b0;
    ID_RegWrite   = 1'b1;      // write back enabled
    ID_ALUSrc     = 1'b0;      // use register
    ID_ALUOp      = 2'b10;     // R-type

    ID_funct3     = 3'b000;
    ID_funct7     = 7'b0000000; // ADD
    ID_rs1        = 5'd2;      // x2
    ID_rs2        = 5'd3;      // x3
    ID_rd         = 5'd4;      // x4

    ID_PC         = 32'h00000008;
    ID_PC_Plus4   = 32'h0000000C;
    ID_ReadData1  = 32'd4;     // x2 = 4
    ID_ReadData2  = 32'd5;     // x3 = 5
    ID_Imm        = 32'd0;     // not used

    // --------------------------------------------------
    // apply flush to insert bubble in EX (branch taken)
    // --------------------------------------------------
    #20 flush = 1'b1;
    #10 flush = 1'b0;

    // --------------------------------------------------
    // instruction: 32'h403102B3  (sub x5, x2, x3)
    // --------------------------------------------------
    #10;
    ID_Branch     = 1'b0;
    ID_MemRead    = 1'b0;
    ID_MemWrite   = 1'b0;
    ID_MemtoReg   = 1'b0;
    ID_RegWrite   = 1'b1;      // write back enabled
    ID_ALUSrc     = 1'b0;      // use register
    ID_ALUOp      = 2'b10;     // R-type

    ID_funct3     = 3'b000;
    ID_funct7     = 7'b0100000; // SUB
    ID_rs1        = 5'd2;      // x2
    ID_rs2        = 5'd3;      // x3
    ID_rd         = 5'd5;      // x5

    ID_PC         = 32'h0000000C;
    ID_PC_Plus4   = 32'h00000010;
    ID_ReadData1  = 32'd4;     // x2 = 4
    ID_ReadData2  = 32'd5;     // x3 = 5
    ID_Imm        = 32'd0;     // not used

    // --------------------------------------------------
    // apply stall to insert NOP bubble (load-use hazard)
    // --------------------------------------------------
    #20 stall = 1'b1;
    #10 stall = 1'b0;

    // --------------------------------------------------
    // instruction: 32'h00317333  (and x6, x2, x3)
    // --------------------------------------------------
    #10;
    ID_Branch     = 1'b0;
    ID_MemRead    = 1'b0;
    ID_MemWrite   = 1'b0;
    ID_MemtoReg   = 1'b0;
    ID_RegWrite   = 1'b1;      // write back enabled
    ID_ALUSrc     = 1'b0;      // use register
    ID_ALUOp      = 2'b10;     // R-type

    ID_funct3     = 3'b111;    // AND
    ID_funct7     = 7'b0000000;
    ID_rs1        = 5'd2;      // x2
    ID_rs2        = 5'd3;      // x3
    ID_rd         = 5'd6;      // x6

    ID_PC         = 32'h00000010;
    ID_PC_Plus4   = 32'h00000014;
    ID_ReadData1  = 32'd4;     // x2 = 4
    ID_ReadData2  = 32'd5;     // x3 = 5
    ID_Imm        = 32'd0;     // not used

end

// clock generation
always #10 clk = ~clk;

endmodule