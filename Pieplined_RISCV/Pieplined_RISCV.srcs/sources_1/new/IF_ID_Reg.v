`timescale 1ns / 1ps
// ============================================================
// IF_ID_Reg.v
// Pipeline Register between Fetch (IF) and Decode (ID) stages
// ============================================================
//
// WHAT THIS REGISTER HOLDS:
//   At the end of every clock cycle, the Fetch stage has:
//     - The current PC value (needed for branch target computation
//       and for JAL to save PC+4 as return address)
//     - PC+4 (the sequential next address, also used as return
//       address for JAL, and as the default next PC)
//     - The 32-bit instruction word fetched from instruction memory
//
//   All three must be passed to the Decode stage, so they are
//   latched into this register on the rising clock edge.
//
// FLUSH (bubble insertion):
//   When a branch is taken (detected at end of EX stage), the
//   two instructions that entered IF and ID after the branch are
//   WRONG instructions - they should not execute.
//   Asserting flush=1 clears this register to all zeros.
//   A zeroed instruction word (32'h00000000) decodes as a NOP
//   (it has opcode = 7'b0000000 which hits the default case in
//   MainControl and generates all-zero control signals).
//
// STALL (pipeline freeze):
//   When a load-use hazard is detected (HazardDetectionUnit sets
//   stall=1), the IF and ID stages must be frozen for one cycle
//   so the load instruction can complete its MEM stage before
//   the dependent instruction reads the value.
//   When stall=1: the register holds its current value (no update).
//   The PC is also frozen simultaneously (PCWrite=0 from HazardUnit).
//
// PRIORITY: flush overrides stall.
//   If both are asserted simultaneously (rare but possible if a
//   branch follows a load), we flush because the branch outcome
//   makes the stall irrelevant.
//
// ============================================================

module IF_ID_Reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,      // 1 = clear register (branch taken)
    input  wire        stall,      // 1 = freeze register (load-use hazard)

    // Inputs from IF stage
    input  wire [31:0] IF_PC,      // current PC
    input  wire [31:0] IF_PC_Plus4,// PC + 4
    input  wire [31:0] IF_Instr,   // instruction from instruction memory

    // Outputs to ID stage
    output reg  [31:0] ID_PC,
    output reg  [31:0] ID_PC_Plus4,
    output reg  [31:0] ID_Instr
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Synchronous reset: clear everything
            ID_PC       <= 32'b0;
            ID_PC_Plus4 <= 32'b0;
            ID_Instr    <= 32'b0;
        end
        else if (flush) begin
            // Flush overrides stall: insert NOP bubble
            // Zeroed instruction = opcode 0000000 = NOP in our MainControl
            ID_PC       <= 32'b0;
            ID_PC_Plus4 <= 32'b0;
            ID_Instr    <= 32'b0;
        end
        else if (stall) begin
            // Stall: hold current values, do not update
            // (implicit: no assignment = keep previous value)
            ID_PC       <= ID_PC;
            ID_PC_Plus4 <= ID_PC_Plus4;
            ID_Instr    <= ID_Instr;
        end
        else begin
            // Normal operation: latch IF stage outputs
            ID_PC       <= IF_PC;
            ID_PC_Plus4 <= IF_PC_Plus4;
            ID_Instr    <= IF_Instr;
        end
    end

endmodule