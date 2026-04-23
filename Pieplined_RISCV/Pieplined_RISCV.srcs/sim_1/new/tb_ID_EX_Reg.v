`timescale 1ns / 1ps
// ============================================================
// tb_ID_EX_Reg.v
// Testbench for ID_EX_Reg pipeline register
//
// WHAT WE ARE TESTING:
//   ID_EX_Reg sits between the Decode and Execute stages.
//   It holds ALL data and control signals that EX stage needs.
//
// KEY BEHAVIOUR TO VERIFY:
//   - Normal latch: all data and control signals pass through
//   - Reset: everything zeros
//   - Flush: everything zeros (branch taken kills ID instruction)
//   - Stall: everything zeros (load-use hazard - insert NOP bubble)
//     NOTE: for ID_EX, stall also zeroes (unlike IF_ID which freezes)
//     This is because we want to insert a bubble into EX, not
//     freeze it. The IF_ID register is the one that freezes.
//
// TEST CASES:
//   1. Normal latch with R-type control signals (ADD)
//   2. Normal latch with Load control signals (LW)
//   3. Flush: simulates branch taken
//   4. Stall: simulates load-use hazard bubble
//   5. Reset
// ============================================================

module tb_ID_EX_Reg;

    // ---- DUT inputs -----------------------------------------
    reg        clk;
    reg        rst;
    reg        flush;
    reg        stall;

    // Data inputs
    reg [31:0] ID_PC;
    reg [31:0] ID_PC_Plus4;
    reg [31:0] ID_ReadData1;
    reg [31:0] ID_ReadData2;
    reg [31:0] ID_Imm;
    reg [4:0]  ID_rs1;
    reg [4:0]  ID_rs2;
    reg [4:0]  ID_rd;
    reg [2:0]  ID_funct3;
    reg [6:0]  ID_funct7;

    // Control inputs
    reg        ID_ALUSrc;
    reg [1:0]  ID_ALUOp;
    reg [2:0]  ID_BranchType;
    reg        ID_Branch;
    reg        ID_Jump;
    reg        ID_MemRead;
    reg        ID_MemWrite;
    reg        ID_RegWrite;
    reg        ID_MemtoReg;

    // ---- DUT outputs ----------------------------------------
    wire [31:0] EX_PC;
    wire [31:0] EX_PC_Plus4;
    wire [31:0] EX_ReadData1;
    wire [31:0] EX_ReadData2;
    wire [31:0] EX_Imm;
    wire [4:0]  EX_rs1;
    wire [4:0]  EX_rs2;
    wire [4:0]  EX_rd;
    wire [2:0]  EX_funct3;
    wire [6:0]  EX_funct7;
    wire        EX_ALUSrc;
    wire [1:0]  EX_ALUOp;
    wire [2:0]  EX_BranchType;
    wire        EX_Branch;
    wire        EX_Jump;
    wire        EX_MemRead;
    wire        EX_MemWrite;
    wire        EX_RegWrite;
    wire        EX_MemtoReg;

    // ---- Instantiate DUT ------------------------------------
    ID_EX_Reg dut (
        .clk           (clk),
        .rst           (rst),
        .flush         (flush),
        .stall         (stall),
        .ID_PC         (ID_PC),
        .ID_PC_Plus4   (ID_PC_Plus4),
        .ID_ReadData1  (ID_ReadData1),
        .ID_ReadData2  (ID_ReadData2),
        .ID_Imm        (ID_Imm),
        .ID_rs1        (ID_rs1),
        .ID_rs2        (ID_rs2),
        .ID_rd         (ID_rd),
        .ID_funct3     (ID_funct3),
        .ID_funct7     (ID_funct7),
        .ID_ALUSrc     (ID_ALUSrc),
        .ID_ALUOp      (ID_ALUOp),
        .ID_BranchType (ID_BranchType),
        .ID_Branch     (ID_Branch),
        .ID_Jump       (ID_Jump),
        .ID_MemRead    (ID_MemRead),
        .ID_MemWrite   (ID_MemWrite),
        .ID_RegWrite   (ID_RegWrite),
        .ID_MemtoReg   (ID_MemtoReg),
        .EX_PC         (EX_PC),
        .EX_PC_Plus4   (EX_PC_Plus4),
        .EX_ReadData1  (EX_ReadData1),
        .EX_ReadData2  (EX_ReadData2),
        .EX_Imm        (EX_Imm),
        .EX_rs1        (EX_rs1),
        .EX_rs2        (EX_rs2),
        .EX_rd         (EX_rd),
        .EX_funct3     (EX_funct3),
        .EX_funct7     (EX_funct7),
        .EX_ALUSrc     (EX_ALUSrc),
        .EX_ALUOp      (EX_ALUOp),
        .EX_BranchType (EX_BranchType),
        .EX_Branch     (EX_Branch),
        .EX_Jump       (EX_Jump),
        .EX_MemRead    (EX_MemRead),
        .EX_MemWrite   (EX_MemWrite),
        .EX_RegWrite   (EX_RegWrite),
        .EX_MemtoReg   (EX_MemtoReg)
    );

    // ---- Clock ----------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Helper task: load R-type (ADD x4, x2, x3) signals -
    task load_rtype;
        begin
            ID_PC         = 32'h0000_0100;
            ID_PC_Plus4   = 32'h0000_0104;
            ID_ReadData1  = 32'h0000_000A;   // rs1 value = 10
            ID_ReadData2  = 32'h0000_0005;   // rs2 value = 5
            ID_Imm        = 32'h0000_0000;   // not used for R-type
            ID_rs1        = 5'd2;
            ID_rs2        = 5'd3;
            ID_rd         = 5'd4;
            ID_funct3     = 3'b000;           // ADD funct3
            ID_funct7     = 7'b000_0000;      // ADD funct7
            ID_ALUSrc     = 1'b0;             // use rs2
            ID_ALUOp      = 2'b10;            // R-type
            ID_BranchType = 3'b000;
            ID_Branch     = 1'b0;
            ID_Jump       = 1'b0;
            ID_MemRead    = 1'b0;
            ID_MemWrite   = 1'b0;
            ID_RegWrite   = 1'b1;             // writes result
            ID_MemtoReg   = 1'b0;
        end
    endtask

    // ---- Helper task: load LW signals -----------------------
    task load_lw;
        begin
            ID_PC         = 32'h0000_0104;
            ID_PC_Plus4   = 32'h0000_0108;
            ID_ReadData1  = 32'h0000_0200;   // base address
            ID_ReadData2  = 32'h0000_0000;   // not used
            ID_Imm        = 32'h0000_0010;   // offset = 16
            ID_rs1        = 5'd5;
            ID_rs2        = 5'd0;
            ID_rd         = 5'd7;
            ID_funct3     = 3'b010;           // LW funct3
            ID_funct7     = 7'b000_0000;
            ID_ALUSrc     = 1'b1;             // use immediate
            ID_ALUOp      = 2'b00;            // ADD for address
            ID_BranchType = 3'b000;
            ID_Branch     = 1'b0;
            ID_Jump       = 1'b0;
            ID_MemRead    = 1'b1;             // load
            ID_MemWrite   = 1'b0;
            ID_RegWrite   = 1'b1;
            ID_MemtoReg   = 1'b1;             // write mem data
        end
    endtask

    // ---- Stimulus -------------------------------------------
    initial begin

        // Initialise
        rst   = 1;
        flush = 0;
        stall = 0;
        load_rtype;
        @(posedge clk); #1;
        // EXPECTED: all outputs zero because rst=1

        // ----------------------------------------------------
        // TEST 1: NORMAL LATCH - R-type (ADD)
        // EXPECTED after posedge:
        //   EX_RegWrite=1, EX_ALUOp=10, EX_ALUSrc=0
        //   EX_rd=4, EX_rs1=2, EX_rs2=3
        //   EX_ReadData1=10, EX_ReadData2=5
        //   EX_MemRead=0, EX_MemWrite=0
        // ----------------------------------------------------
        rst = 0;
        load_rtype;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 2: NORMAL LATCH - LW
        // EXPECTED after posedge:
        //   EX_RegWrite=1, EX_ALUOp=00, EX_ALUSrc=1
        //   EX_MemRead=1, EX_MemtoReg=1
        //   EX_rd=7, EX_Imm=16
        // ----------------------------------------------------
        load_lw;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 3: FLUSH (branch taken)
        // Even though inputs carry valid LW signals,
        // flush=1 inserts a NOP bubble.
        // EXPECTED: ALL outputs zero
        // ----------------------------------------------------
        flush = 1;
        load_rtype;   // valid data on inputs - should be ignored
        @(posedge clk); #1;
        // All EX outputs must be zero

        flush = 0;

        // ----------------------------------------------------
        // TEST 4: STALL (load-use hazard)
        // stall=1 inserts a NOP bubble into EX stage.
        // The difference from IF_ID stall: ID_EX ZEROES outputs
        // (not freezes) because we want a bubble in EX, not
        // to repeat the same instruction again.
        // EXPECTED: ALL outputs zero
        // ----------------------------------------------------
        stall = 1;
        load_rtype;
        @(posedge clk); #1;
        // All EX outputs must be zero (bubble)

        stall = 0;

        // Normal cycle after stall - should latch normally
        load_rtype;
        @(posedge clk); #1;
        // EX_RegWrite=1, EX_rd=4 etc.

        // ----------------------------------------------------
        // TEST 5: RESET mid-operation
        // EXPECTED: all outputs go to zero
        // ----------------------------------------------------
        rst = 1;
        load_lw;
        @(posedge clk); #1;
        // All outputs zero

        rst = 0;
        @(posedge clk);
        @(posedge clk);

        $finish;
    end

endmodule