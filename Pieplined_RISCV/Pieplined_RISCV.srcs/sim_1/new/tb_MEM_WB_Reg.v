`timescale 1ns / 1ps
// ============================================================
// tb_MEM_WB_Reg.v
// Testbench for MEM_WB_Reg pipeline register
//
// WHAT WE ARE TESTING:
//   MEM_WB_Reg is the LAST pipeline register, between the
//   Memory and Writeback stages.
//
//   It holds:
//     - ALUResult   (for R/I-type writeback)
//     - MemReadData (for Load writeback)
//     - PC_Plus4    (for JAL return address writeback)
//     - rd          (destination register address)
//     - RegWrite    (whether to write to register file)
//     - MemtoReg    (mux: ALU result vs memory data)
//     - Jump        (mux: PC+4 for JAL)
//
//   The WB stage 3-way mux (in TopLevelPipelined) then selects:
//     Jump=1              -> WriteData = PC_Plus4
//     MemtoReg=1, Jump=0  -> WriteData = MemReadData
//     MemtoReg=0, Jump=0  -> WriteData = ALUResult
//
// NO FLUSH, NO STALL:
//   This is the last register. Wrong instructions are caught
//   before they ever reach this stage.
//
// TEST CASES:
//   1. R-type: ALUResult written to rd
//   2. Load:   MemReadData written to rd
//   3. JAL:    PC+4 written to rd
//   4. Store:  RegWrite=0, nothing written (passthrough check)
//   5. Reset
// ============================================================

module tb_MEM_WB_Reg;

    // ---- DUT inputs -----------------------------------------
    reg        clk;
    reg        rst;

    reg [31:0] MEM_PC_Plus4;
    reg [31:0] MEM_ALUResult;
    reg [31:0] MEM_MemReadData;
    reg [4:0]  MEM_rd;
    reg        MEM_RegWrite;
    reg        MEM_MemtoReg;
    reg        MEM_Jump;

    // ---- DUT outputs ----------------------------------------
    wire [31:0] WB_PC_Plus4;
    wire [31:0] WB_ALUResult;
    wire [31:0] WB_MemReadData;
    wire [4:0]  WB_rd;
    wire        WB_RegWrite;
    wire        WB_MemtoReg;
    wire        WB_Jump;

    // ---- WB mux (replicate TopLevelPipelined WB logic) ------
    // This lets us directly see what would be written to regfile
    wire [31:0] WB_WriteData;
    assign WB_WriteData = WB_Jump     ? WB_PC_Plus4    :
                          WB_MemtoReg ? WB_MemReadData  :
                                        WB_ALUResult;

    // ---- Instantiate DUT ------------------------------------
    MEM_WB_Reg dut (
        .clk              (clk),
        .rst              (rst),
        .MEM_PC_Plus4     (MEM_PC_Plus4),
        .MEM_ALUResult    (MEM_ALUResult),
        .MEM_MemReadData  (MEM_MemReadData),
        .MEM_rd           (MEM_rd),
        .MEM_RegWrite     (MEM_RegWrite),
        .MEM_MemtoReg     (MEM_MemtoReg),
        .MEM_Jump         (MEM_Jump),
        .WB_PC_Plus4      (WB_PC_Plus4),
        .WB_ALUResult     (WB_ALUResult),
        .WB_MemReadData   (WB_MemReadData),
        .WB_rd            (WB_rd),
        .WB_RegWrite      (WB_RegWrite),
        .WB_MemtoReg      (WB_MemtoReg),
        .WB_Jump          (WB_Jump)
    );

    // ---- Clock ----------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Stimulus -------------------------------------------
    initial begin

        // Reset with garbage inputs to confirm zeroing
        rst             = 1;
        MEM_PC_Plus4    = 32'hDEAD_BEEF;
        MEM_ALUResult   = 32'hDEAD_BEEF;
        MEM_MemReadData = 32'hDEAD_BEEF;
        MEM_rd          = 5'd31;
        MEM_RegWrite    = 1'b1;
        MEM_MemtoReg    = 1'b1;
        MEM_Jump        = 1'b1;
        @(posedge clk); #1;
        // EXPECTED: all WB outputs = 0, WB_WriteData = 0

        rst = 0;

        // ----------------------------------------------------
        // TEST 1: R-type result (ADD x4, x2, x3 -> x4 = 15)
        // MemtoReg=0, Jump=0  -> WB_WriteData = WB_ALUResult
        // EXPECTED:
        //   WB_ALUResult   = 32'd15
        //   WB_rd          = 4
        //   WB_RegWrite    = 1
        //   WB_WriteData   = 32'd15   (mux selects ALUResult)
        // ----------------------------------------------------
        MEM_PC_Plus4    = 32'h0000_0104;
        MEM_ALUResult   = 32'h0000_000F;  // 15
        MEM_MemReadData = 32'hDEAD_DEAD;  // irrelevant for R-type
        MEM_rd          = 5'd4;
        MEM_RegWrite    = 1'b1;
        MEM_MemtoReg    = 1'b0;           // ALU result path
        MEM_Jump        = 1'b0;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 2: Load result (LW x7, 16(x5))
        // MemtoReg=1, Jump=0  -> WB_WriteData = WB_MemReadData
        // EXPECTED:
        //   WB_MemReadData = 0x0000_1234
        //   WB_rd          = 7
        //   WB_RegWrite    = 1
        //   WB_WriteData   = 0x0000_1234  (mux selects MemReadData)
        // ----------------------------------------------------
        MEM_PC_Plus4    = 32'h0000_0108;
        MEM_ALUResult   = 32'h0000_0210;  // computed load address
        MEM_MemReadData = 32'h0000_1234;  // data loaded from memory
        MEM_rd          = 5'd7;
        MEM_RegWrite    = 1'b1;
        MEM_MemtoReg    = 1'b1;           // memory data path
        MEM_Jump        = 1'b0;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 3: JAL x1, offset
        // Jump=1  -> WB_WriteData = WB_PC_Plus4 (return address)
        // EXPECTED:
        //   WB_PC_Plus4  = 0x0000_010C  (return address)
        //   WB_rd        = 1
        //   WB_RegWrite  = 1
        //   WB_WriteData = 0x0000_010C  (mux selects PC+4)
        // ----------------------------------------------------
        MEM_PC_Plus4    = 32'h0000_010C;  // return address
        MEM_ALUResult   = 32'h0000_0300;  // jump target (not written)
        MEM_MemReadData = 32'h0000_0000;
        MEM_rd          = 5'd1;           // x1 = return address reg
        MEM_RegWrite    = 1'b1;
        MEM_MemtoReg    = 1'b0;
        MEM_Jump        = 1'b1;           // JAL: use PC+4
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 4: Store (SW) - no register writeback
        // RegWrite=0 -> register file ignores this
        // EXPECTED:
        //   WB_RegWrite  = 0
        //   WB_rd        = 0
        //   WB_WriteData = whatever (ignored because RegWrite=0)
        // ----------------------------------------------------
        MEM_PC_Plus4    = 32'h0000_0110;
        MEM_ALUResult   = 32'h0000_0208;  // store address
        MEM_MemReadData = 32'h0000_0000;
        MEM_rd          = 5'd0;
        MEM_RegWrite    = 1'b0;           // NO writeback for store
        MEM_MemtoReg    = 1'b0;
        MEM_Jump        = 1'b0;
        @(posedge clk); #1;

        // ----------------------------------------------------
        // TEST 5: Back-to-back different writeback sources
        // Cycle A: R-type  -> WB_WriteData = ALUResult
        // Cycle B: Load    -> WB_WriteData = MemReadData
        // Observe the mux switching in waveform
        // ----------------------------------------------------
        // Cycle A
        MEM_ALUResult   = 32'h0000_CAFE;
        MEM_MemReadData = 32'h0000_BABE;
        MEM_rd          = 5'd8;
        MEM_RegWrite    = 1'b1;
        MEM_MemtoReg    = 1'b0;
        MEM_Jump        = 1'b0;
        @(posedge clk); #1;
        // WB_WriteData should be 0xCAFE

        // Cycle B
        MEM_ALUResult   = 32'h0000_CAFE;
        MEM_MemReadData = 32'h0000_BABE;
        MEM_rd          = 5'd9;
        MEM_RegWrite    = 1'b1;
        MEM_MemtoReg    = 1'b1;   // NOW select memory data
        MEM_Jump        = 1'b0;
        @(posedge clk); #1;
        // WB_WriteData should be 0xBABE

        // ----------------------------------------------------
        // TEST 6: RESET
        // EXPECTED: all outputs zeroed
        // ----------------------------------------------------
        rst = 1;
        MEM_ALUResult   = 32'hFFFF_FFFF;
        MEM_MemReadData = 32'hFFFF_FFFF;
        @(posedge clk); #1;
        // All WB outputs = 0, WB_WriteData = 0

        rst = 0;
        @(posedge clk);
        @(posedge clk);
        $finish;
    end

endmodule