`timescale 1ns / 1ps
// ============================================================
// tb_IF_ID_Reg.v
// Testbench for IF_ID_Reg pipeline register
//
// WHAT WE ARE TESTING:
//   IF_ID_Reg sits between the Fetch and Decode stages.
//   It holds: PC, PC+4, and the fetched Instruction.
//
// TEST CASES:
//   1. Reset          : all outputs go to zero regardless of inputs
//   2. Normal latch   : inputs are captured on rising clock edge
//   3. Stall          : outputs freeze, inputs ignored
//   4. Flush          : outputs go to zero (NOP bubble inserted)
//   5. Flush+Stall    : flush wins (flush has higher priority)
//
// HOW TO VERIFY:
//   Open the waveform. Add these signals:
//     clk, rst, flush, stall
//     IF_PC, IF_PC_Plus4, IF_Instr
//     ID_PC, ID_PC_Plus4, ID_Instr
//   After each clock edge check that the outputs match
//   the expected values described in the comments below.
// ============================================================

module tb_IF_ID_Reg;

    // ---- DUT inputs (driven by testbench) -------------------
    reg        clk;
    reg        rst;
    reg        flush;
    reg        stall;
    reg [31:0] IF_PC;
    reg [31:0] IF_PC_Plus4;
    reg [31:0] IF_Instr;

    // ---- DUT outputs (observed in waveform) -----------------
    wire [31:0] ID_PC;
    wire [31:0] ID_PC_Plus4;
    wire [31:0] ID_Instr;

    // ---- Instantiate DUT ------------------------------------
    IF_ID_Reg dut (
        .clk        (clk),
        .rst        (rst),
        .flush      (flush),
        .stall      (stall),
        .IF_PC      (IF_PC),
        .IF_PC_Plus4(IF_PC_Plus4),
        .IF_Instr   (IF_Instr),
        .ID_PC      (ID_PC),
        .ID_PC_Plus4(ID_PC_Plus4),
        .ID_Instr   (ID_Instr)
    );

    // ---- Clock generation -----------------------------------
    // Period = 10 ns, 50% duty cycle
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Stimulus -------------------------------------------
    initial begin

        // ----------------------------------------------------
        // INITIALISE: all inputs zero, assert reset
        // EXPECTED after first posedge: ID_PC=0, ID_PC_Plus4=0,
        //                               ID_Instr=0
        // ----------------------------------------------------
        rst   = 1;
        flush = 0;
        stall = 0;
        IF_PC       = 32'hAAAA_AAAA;   // garbage - should be ignored
        IF_PC_Plus4 = 32'hBBBB_BBBB;
        IF_Instr    = 32'hCCCC_CCCC;
        @(posedge clk); #1;
        // Outputs must all be zero because rst=1

        // ----------------------------------------------------
        // TEST 1: NORMAL LATCH
        // Release reset, apply real values, expect them latched
        // EXPECTED after posedge: ID_PC=0x100, ID_PC_Plus4=0x104,
        //                         ID_Instr=0x00C12023
        // ----------------------------------------------------
        rst         = 0;
        IF_PC       = 32'h0000_0100;
        IF_PC_Plus4 = 32'h0000_0104;
        IF_Instr    = 32'h00C1_2023;   // example: SW x12,0(x2)
        @(posedge clk); #1;
        // Now ID_PC should be 0x100

        // Change inputs to next instruction
        IF_PC       = 32'h0000_0104;
        IF_PC_Plus4 = 32'h0000_0108;
        IF_Instr    = 32'h0062_0233;   // example: ADD x4,x4,x6
        @(posedge clk); #1;
        // ID_PC should now be 0x104

        // ----------------------------------------------------
        // TEST 2: STALL
        // Assert stall=1. The register must HOLD its current
        // values even though the IF inputs are changing.
        // EXPECTED: ID_PC stays 0x104 for two cycles
        // ----------------------------------------------------
        stall       = 1;
        IF_PC       = 32'h0000_0108;   // new fetch - should be ignored
        IF_PC_Plus4 = 32'h0000_010C;
        IF_Instr    = 32'hDEAD_BEEF;   // garbage to make stall visible
        @(posedge clk); #1;
        // ID_PC must still be 0x104

        @(posedge clk); #1;
        // ID_PC must still be 0x104 (second stall cycle)

        // Release stall - normal latch resumes
        stall       = 0;
        @(posedge clk); #1;
        // Now ID_PC should update to 0x108

        // ----------------------------------------------------
        // TEST 3: FLUSH
        // Assert flush=1. The register must go to ALL ZEROS.
        // This represents a branch being taken: the instruction
        // that just entered IF is wrong and must be killed.
        // EXPECTED: ID_PC=0, ID_PC_Plus4=0, ID_Instr=0 (NOP)
        // ----------------------------------------------------
        flush       = 1;
        IF_PC       = 32'h0000_0200;   // valid data - should be ignored
        IF_PC_Plus4 = 32'h0000_0204;
        IF_Instr    = 32'h0032_0233;
        @(posedge clk); #1;
        // All ID outputs must be zero (NOP bubble)

        // Release flush
        flush       = 0;
        IF_PC       = 32'h0000_0200;
        IF_PC_Plus4 = 32'h0000_0204;
        IF_Instr    = 32'h0032_0233;
        @(posedge clk); #1;
        // Normal latch resumes: ID_PC = 0x200

        // ----------------------------------------------------
        // TEST 4: FLUSH OVERRIDES STALL
        // Both flush and stall asserted together.
        // Flush must win: outputs go to zero.
        // EXPECTED: ID_PC=0, ID_PC_Plus4=0, ID_Instr=0
        // ----------------------------------------------------
        flush = 1;
        stall = 1;
        IF_PC       = 32'h0000_0300;
        IF_PC_Plus4 = 32'h0000_0304;
        IF_Instr    = 32'hFFFF_FFFF;
        @(posedge clk); #1;
        // Outputs must be zero (flush wins over stall)

        flush = 0;
        stall = 0;

        // ----------------------------------------------------
        // TEST 5: RESET OVERRIDES EVERYTHING
        // Even with flush=0 and stall=0, rst=1 clears all
        // EXPECTED: ID_PC=0, ID_PC_Plus4=0, ID_Instr=0
        // ----------------------------------------------------
        rst         = 1;
        IF_PC       = 32'hFFFF_FFFF;
        IF_PC_Plus4 = 32'hFFFF_FFFF;
        IF_Instr    = 32'hFFFF_FFFF;
        @(posedge clk); #1;
        // Outputs must be zero

        rst = 0;

        // Let a few more cycles run so waveform is clean
        @(posedge clk);
        @(posedge clk);

        $finish;
    end

endmodule