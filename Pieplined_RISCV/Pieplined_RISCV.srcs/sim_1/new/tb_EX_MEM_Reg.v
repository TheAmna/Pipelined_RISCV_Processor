`timescale 1ns / 1ps
// ============================================================
// tb_EX_MEM_Reg.v
// Testbench for EX_MEM_Reg pipeline register
//
// WHAT WE ARE TESTING:
//   EX_MEM_Reg sits between Execute and Memory stages.
//   It holds the ALU result, store data, branch target,
//   PCSrc decision, and all MEM/WB control signals.
//
// KEY BEHAVIOUR:
//   - No flush input (branch decision already made in EX;
//     only IF_ID and ID_EX are flushed)
//   - No stall input (load continues through MEM normally)
//   - Only rst zeroes it
//
// TEST CASES:
//   1. Normal latch: R-type result (ADD, ALUResult=15)
//   2. Normal latch: Store (SW - MemWrite=1, WriteData valid)
//   3. Normal latch: Branch taken (PCSrc=1, BranchTarget valid)
//   4. Normal latch: JAL (Jump=1, PC+4 carried for writeback)
//   5. Reset
// ============================================================

module tb_EX_MEM_Reg;

    // ---- DUT inputs -----------------------------------------
    reg        clk;
    reg        rst;

    reg [31:0] EX_PC_Plus4;
    reg [31:0] EX_BranchTarget;
    reg        EX_PCSrc;
    reg [31:0] EX_ALUResult;
    reg [31:0] EX_WriteData;
    reg [4:0]  EX_rd;
    reg        EX_Zero;
    reg        EX_Negative;
    reg        EX_MemRead;
    reg        EX_MemWrite;
    reg        EX_RegWrite;
    reg        EX_MemtoReg;
    reg        EX_Jump;

    // ---- DUT outputs ----------------------------------------
    wire [31:0] MEM_PC_Plus4;
    wire [31:0] MEM_BranchTarget;
    wire        MEM_PCSrc;
    wire [31:0] MEM_ALUResult;
    wire [31:0] MEM_WriteData;
    wire [4:0]  MEM_rd;
    wire        MEM_Zero;
    wire        MEM_Negative;
    wire        MEM_MemRead;
    wire        MEM_MemWrite;
    wire        MEM_RegWrite;
    wire        MEM_MemtoReg;
    wire        MEM_Jump;

    // ---- Instantiate DUT ------------------------------------
    EX_MEM_Reg dut (
        .clk              (clk),
        .rst              (rst),
        .EX_PC_Plus4      (EX_PC_Plus4),
        .EX_BranchTarget  (EX_BranchTarget),
        .EX_PCSrc         (EX_PCSrc),
        .EX_ALUResult     (EX_ALUResult),
        .EX_WriteData     (EX_WriteData),
        .EX_rd            (EX_rd),
        .EX_Zero          (EX_Zero),
        .EX_Negative      (EX_Negative),
        .EX_MemRead       (EX_MemRead),
        .EX_MemWrite      (EX_MemWrite),
        .EX_RegWrite      (EX_RegWrite),
        .EX_MemtoReg      (EX_MemtoReg),
        .EX_Jump          (EX_Jump),
        .MEM_PC_Plus4     (MEM_PC_Plus4),
        .MEM_BranchTarget (MEM_BranchTarget),
        .MEM_PCSrc        (MEM_PCSrc),
        .MEM_ALUResult    (MEM_ALUResult),
        .MEM_WriteData    (MEM_WriteData),
        .MEM_rd           (MEM_rd),
        .MEM_Zero         (MEM_Zero),
        .MEM_Negative     (MEM_Negative),
        .MEM_MemRead      (MEM_MemRead),
        .MEM_MemWrite     (MEM_MemWrite),
        .MEM_RegWrite     (MEM_RegWrite),
        .MEM_MemtoReg     (MEM_MemtoReg),
        .MEM_Jump         (MEM_Jump)
    );

    // ---- Clock ----------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Stimulus -------------------------------------------
    initial begin

        // Reset
        rst            = 1;
        EX_PC_Plus4    = 32'hDEAD_BEEF;
        EX_BranchTarget= 32'hDEAD_BEEF;
        EX_PCSrc       = 1'b1;
        EX_ALUResult   = 32'hDEAD_BEEF;
        EX_WriteData   = 32'hDEAD_BEEF;
        EX_rd          = 5'd31;
        EX_Zero        = 1'b1;
        EX_Negative    = 1'b1;
        EX_MemRead     = 1'b1;
        EX_MemWrite    = 1'b1;
        EX_RegWrite    = 1'b1;
        EX_MemtoReg    = 1'b1;
        EX_Jump        = 1'b1;
        @(posedge clk); #1;
        // EXPECTED: all MEM outputs zero (rst=1)

        rst = 0;

        // ----------------------------------------------------
        // TEST 1: R-type ADD result
        // ADD x4, x2, x3  ->  ALUResult = 10+5 = 15
        // EXPECTED:
        //   MEM_ALUResult = 32'd15
        //   MEM_RegWrite  = 1
        //   MEM_MemRead   = 0, MEM_MemWrite = 0
        //   MEM_PCSrc     = 0
        //   MEM_rd        = 4
        // ----------------------------------------------------
        EX_PC_Plus4    = 32'h0000_0104;
        EX_BranchTarget= 32'h0000_0200;
        EX_PCSrc       = 1'b0;           // not a branch
        EX_ALUResult   = 32'h0000_000F;  // 10 + 5 = 15
        EX_WriteData   = 32'h0000_0005;  // rs2 = 5 (not used for R-type)
        EX_rd          = 5'd4;
        EX_Zero        = 1'b0;
        EX_Negative    = 1'b0;
        EX_MemRead     = 1'b0;
        EX_MemWrite    = 1'b0;
        EX_RegWrite    = 1'b1;
        EX_MemtoReg    = 1'b0;
        EX_Jump        = 1'b0;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 2: Store (SW x6, 8(x5))
        // ALUResult = address = base + 8
        // WriteData = value to store = rs2
        // EXPECTED:
        //   MEM_MemWrite  = 1
        //   MEM_RegWrite  = 0
        //   MEM_ALUResult = 0x0000_0208  (address)
        //   MEM_WriteData = 0x0000_ABCD  (data to store)
        // ----------------------------------------------------
        EX_PC_Plus4    = 32'h0000_0108;
        EX_BranchTarget= 32'h0000_0200;
        EX_PCSrc       = 1'b0;
        EX_ALUResult   = 32'h0000_0208;  // computed store address
        EX_WriteData   = 32'h0000_ABCD;  // data to write to memory
        EX_rd          = 5'd0;           // stores don't write register
        EX_Zero        = 1'b0;
        EX_Negative    = 1'b0;
        EX_MemRead     = 1'b0;
        EX_MemWrite    = 1'b1;           // store!
        EX_RegWrite    = 1'b0;
        EX_MemtoReg    = 1'b0;
        EX_Jump        = 1'b0;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 3: BEQ taken (branch)
        // ALU did SUB, result=0 so Zero=1, BranchTaken -> PCSrc=1
        // EXPECTED:
        //   MEM_PCSrc        = 1
        //   MEM_Zero         = 1
        //   MEM_BranchTarget = 0x0000_0150
        //   MEM_RegWrite     = 0
        // ----------------------------------------------------
        EX_PC_Plus4    = 32'h0000_010C;
        EX_BranchTarget= 32'h0000_0150;  // branch target address
        EX_PCSrc       = 1'b1;           // branch taken!
        EX_ALUResult   = 32'h0000_0000;  // SUB result = 0 -> equal
        EX_WriteData   = 32'h0000_0000;
        EX_rd          = 5'd0;
        EX_Zero        = 1'b1;           // equal
        EX_Negative    = 1'b0;
        EX_MemRead     = 1'b0;
        EX_MemWrite    = 1'b0;
        EX_RegWrite    = 1'b0;
        EX_MemtoReg    = 1'b0;
        EX_Jump        = 1'b0;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 4: JAL x1, offset
        // Jump=1, PC+4 must reach WB to be written into x1
        // EXPECTED:
        //   MEM_Jump     = 1
        //   MEM_RegWrite = 1
        //   MEM_PC_Plus4 = 0x0000_0110  (return address)
        //   MEM_rd       = 1
        //   MEM_PCSrc    = 1  (jump target taken)
        // ----------------------------------------------------
        EX_PC_Plus4    = 32'h0000_0110;  // return address for JAL
        EX_BranchTarget= 32'h0000_0300;  // jump target
        EX_PCSrc       = 1'b1;           // jump taken
        EX_ALUResult   = 32'h0000_0300;  // not used for writeback
        EX_WriteData   = 32'h0000_0000;
        EX_rd          = 5'd1;           // JAL writes to x1 (ra)
        EX_Zero        = 1'b0;
        EX_Negative    = 1'b0;
        EX_MemRead     = 1'b0;
        EX_MemWrite    = 1'b0;
        EX_RegWrite    = 1'b1;           // writes PC+4 to rd
        EX_MemtoReg    = 1'b0;
        EX_Jump        = 1'b1;           // JAL flag
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 5: RESET mid-pipeline
        // EXPECTED: all MEM outputs go to zero
        // ----------------------------------------------------
        rst = 1;
        @(posedge clk); #1;
        rst = 0;

        @(posedge clk);
        @(posedge clk);
        $finish;
    end

endmodule