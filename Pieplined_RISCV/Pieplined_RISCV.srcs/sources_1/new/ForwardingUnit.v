`timescale 1ns / 1ps
// ============================================================
// ForwardingUnit.v
// Resolves RAW (Read After Write) data hazards through forwarding
// ============================================================
//
// THE PROBLEM IT SOLVES:
//   In a pipeline, an instruction writes its result in WB (cycle N+4)
//   but the next instruction needs that value in EX (cycle N+2 or N+3).
//   Without forwarding, the pipeline would read a STALE register value.
//
//   Example:
//     Cycle 1:  ADD x1, x2, x3    -> EX in cycle 3, WB in cycle 5
//     Cycle 2:  SUB x4, x1, x5    -> EX in cycle 4, needs x1 from ADD
//     Without forwarding: SUB reads x1 from register file in cycle 3
//                         (WRONG - ADD hasn't written yet)
//     With forwarding:    SUB gets x1 directly from EX/MEM register
//                         in cycle 4 (CORRECT)
//
// TWO FORWARDING PATHS:
//
//   PATH 1: EX/MEM -> EX (forward from previous instruction)
//     When the instruction ONE cycle ahead is in MEM stage and
//     its rd matches the current EX stage instruction's rs1 or rs2.
//     Priority: HIGHER (more recent result)
//     Source:   EX_MEM_ALUResult
//
//   PATH 2: MEM/WB -> EX (forward from two instructions ahead)
//     When the instruction TWO cycles ahead is in WB stage and
//     its rd matches the current EX stage instruction's rs1 or rs2.
//     BUT only if EX/MEM forwarding is NOT already covering this.
//     Priority: LOWER
//     Source:   WB_WriteData (already muxed in TopLevel: ALUResult or MemReadData)
//
// FORWARD SIGNAL ENCODING (2 bits each):
//   2'b00 = No forwarding    : use register file output (ID/EX ReadData)
//   2'b01 = Forward from WB  : use WB_WriteData
//   2'b10 = Forward from MEM : use MEM_ALUResult  <- highest priority
//
// EX/MEM_MemtoReg GUARD:
//   When the instruction in EX/MEM is a LOAD (MemtoReg=1), its result
//   (the loaded data) is NOT yet available - it hasn't come out of
//   data memory yet. Forwarding EX/MEM_ALUResult at this point would
//   give the memory ADDRESS, not the loaded data, which is wrong.
//   The HazardDetectionUnit should have already stalled for this case,
//   but this guard is a defensive safety net: we block EX/MEM forwarding
//   when the instruction in MEM is a load (MemtoReg=1).
//
// LOAD FORWARDING (MEM/WB with MemtoReg=1):
//   One cycle LATER, the load data IS available in MEM/WB.
//   The forwarding mux in TopLevel uses WB_WriteData which already
//   selects between WB_ALUResult and WB_MemReadData via the WB mux.
//   So ForwardA/B = 2'b01 always gets the correct WB value automatically.
//
// ============================================================

module ForwardingUnit (
    // From ID/EX register: current EX-stage instruction's source registers
    input  wire [4:0] ID_EX_rs1,
    input  wire [4:0] ID_EX_rs2,

    // From EX/MEM register: previous instruction's destination + controls
    input  wire [4:0] EX_MEM_rd,
    input  wire       EX_MEM_RegWrite,
    input  wire       EX_MEM_MemtoReg,  // 1 = load in MEM stage (data not ready yet)

    // From MEM/WB register: two-back instruction's destination + write enable
    input  wire [4:0] MEM_WB_rd,
    input  wire       MEM_WB_RegWrite,

    // Forwarding mux selects
    // 2'b00 = use register file (ID/EX ReadData)
    // 2'b01 = forward from MEM/WB (WB_WriteData)
    // 2'b10 = forward from EX/MEM (MEM_ALUResult)
    output reg  [1:0] ForwardA,   // for rs1 / ALU input A
    output reg  [1:0] ForwardB    // for rs2 / ALU input B
);

    always @(*) begin

        // -------------------------------------------------------
        // FORWARD A (rs1)
        // -------------------------------------------------------

        // Default: no forwarding, use register file value
        ForwardA = 2'b00;

        // Check EX/MEM forwarding first (higher priority)
        // Guard: EX_MEM_MemtoReg=0 ensures we don't forward
        //        an unready load result from the MEM stage
        if (EX_MEM_RegWrite    == 1'b1    &&
            EX_MEM_rd          != 5'b00000 &&
            EX_MEM_rd          == ID_EX_rs1 &&
            EX_MEM_MemtoReg    == 1'b0) begin
            ForwardA = 2'b10;   // forward from EX/MEM ALUResult
        end
        // Else check MEM/WB forwarding (lower priority)
        // The else-if ensures EX/MEM takes precedence when both match
        else if (MEM_WB_RegWrite == 1'b1    &&
                 MEM_WB_rd       != 5'b00000 &&
                 MEM_WB_rd       == ID_EX_rs1) begin
            ForwardA = 2'b01;   // forward from WB_WriteData
        end

        // -------------------------------------------------------
        // FORWARD B (rs2)
        // -------------------------------------------------------

        // Default: no forwarding, use register file value
        ForwardB = 2'b00;

        // Check EX/MEM forwarding first (higher priority)
        if (EX_MEM_RegWrite    == 1'b1    &&
            EX_MEM_rd          != 5'b00000 &&
            EX_MEM_rd          == ID_EX_rs2 &&
            EX_MEM_MemtoReg    == 1'b0) begin
            ForwardB = 2'b10;   // forward from EX/MEM ALUResult
        end
        // Else check MEM/WB forwarding (lower priority)
        else if (MEM_WB_RegWrite == 1'b1    &&
                 MEM_WB_rd       != 5'b00000 &&
                 MEM_WB_rd       == ID_EX_rs2) begin
            ForwardB = 2'b01;   // forward from WB_WriteData
        end

    end

endmodule