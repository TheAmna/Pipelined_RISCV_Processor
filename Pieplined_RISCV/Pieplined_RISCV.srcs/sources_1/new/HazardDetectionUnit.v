`timescale 1ns / 1ps
// ============================================================
// HazardDetectionUnit.v
// Detects load-use hazards and generates stall signals
// ============================================================
//
// THE ONLY HAZARD THIS UNIT HANDLES: Load-Use Hazard
//
//   A load-use hazard occurs when a LOAD instruction is immediately
//   followed by an instruction that uses the loaded value.
//
//   Example:
//     LW  x1, 0(x2)     <- load into x1
//     ADD x3, x1, x4    <- immediately uses x1
//
//   WHY FORWARDING ALONE CANNOT SOLVE THIS:
//     The load's data is not available until the END of the MEM stage.
//     The ADD needs the data at the START of its EX stage.
//     In the pipeline timeline:
//       Cycle N:   LW  in EX  (computing address)
//       Cycle N+1: LW  in MEM (reading memory) | ADD in EX (needs x1!)
//     At cycle N+1, x1 has NOT been read from memory yet when ADD
//     enters EX. Forwarding cannot go backward in time.
//     So we MUST stall for one cycle:
//       Cycle N:   LW  in EX
//       Cycle N+1: LW  in MEM | BUBBLE in EX  (stall inserted)
//       Cycle N+2: LW  in WB  | ADD in EX  <- MEM/WB forwarding now works
//
// WHAT THE UNIT DOES WHEN A HAZARD IS DETECTED:
//
//   1. Stall = 1
//      Sent to BOTH ProgramCounter (freezes PC) and IF_ID_Reg (freezes
//      IF/ID register). Both are frozen together so the same instruction
//      is re-presented to the decode stage next cycle.
//      NOTE: Previously this was two separate signals (PCWrite and
//      IF_ID_Write) but they were always assigned the same value, so
//      they are now merged into a single Stall output for simplicity.
//
//   2. ID_EX_Stall = 1
//      Sent to ID_EX_Reg to zero all control signals for one cycle.
//      This inserts a NOP bubble into the EX stage.
//      The LW instruction continues through MEM and WB normally.
//      Next cycle, ADD enters EX and MEM/WB forwarding provides x1.
//
// DETECTION CONDITION:
//   A load-use hazard exists when ALL of:
//     1. ID_EX_MemRead == 1        (instruction in EX is a load)
//     2. ID_EX_rd != 0             (load has a non-zero destination)
//     3. ID_EX_rd == IF_ID_rs1    (load destination = next instr rs1)
//        OR
//        ID_EX_rd == IF_ID_rs2    (load destination = next instr rs2)
//
// BRANCH CONTROL HAZARD:
//   Branch flush (PCSrc) is handled separately in TopLevelPipelined
//   using combinational logic directly from the EX stage.
//   It does NOT go through this unit - keeping concerns separated
//   and avoiding the simultaneous stall+flush priority bug.
//
// WHAT THIS UNIT DOES NOT HANDLE:
//   - RAW hazards from non-load instructions: ForwardingUnit
//   - Control hazards (branch): TopLevel combinational flush logic
//   - WAW, WAR hazards: do not occur in in-order 5-stage pipeline
//
// ============================================================

module HazardDetectionUnit (
    // From ID/EX register: instruction currently in EX stage
    input  wire       ID_EX_MemRead,   // 1 = EX instruction is a load
    input  wire [4:0] ID_EX_rd,        // EX instruction's destination register

    // From IF/ID register: instruction currently in ID stage
    input  wire [4:0] IF_ID_rs1,       // ID instruction's source reg 1
    input  wire [4:0] IF_ID_rs2,       // ID instruction's source reg 2

    // Outputs
    // Stall     -> goes to ProgramCounter (stall port) AND IF_ID_Reg (stall port)
    //              Both are always frozen together, so one signal covers both
    output reg        Stall,            // 1 = freeze PC and IF/ID register

    // ID_EX_Stall -> goes to ID_EX_Reg (stall port)
    //               Inserts a NOP bubble into the EX stage for one cycle
    output reg        ID_EX_Stall       // 1 = insert bubble into ID/EX
);

    always @(*) begin
        // Default: no hazard, normal operation
        Stall       = 1'b0;
        ID_EX_Stall = 1'b0;

        // Detect load-use hazard
        if (ID_EX_MemRead  == 1'b1     &&
            ID_EX_rd       != 5'b00000 &&
            (ID_EX_rd == IF_ID_rs1 || ID_EX_rd == IF_ID_rs2)) begin

            // Hazard detected: insert one-cycle stall
            Stall       = 1'b1;   // freeze PC and IF/ID register
            ID_EX_Stall = 1'b1;   // insert NOP bubble into ID/EX
        end
    end

endmodule