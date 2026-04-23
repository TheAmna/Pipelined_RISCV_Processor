`timescale 1ns / 1ps
// ============================================================
// EX_MEM_Reg.v
// Pipeline Register between Execute (EX) and Memory (MEM) stages
// ============================================================
//
// WHAT THIS REGISTER HOLDS:
//   After the Execute stage, we have computed:
//
//   DATA signals:
//     - PC_Plus4      (needed in WB for JAL return address write)
//     - ALUResult     (effective address for load/store,
//                      arithmetic result for R/I type)
//     - WriteData     (rs2 value, possibly forwarded - data to
//                      be written to memory for store instructions)
//     - rd            (destination register, carried forward to WB)
//
//   CONTROL signals:
//     MEM-stage controls (used in MEM stage):
//       - MemRead    (1 = load: read from data memory)
//       - MemWrite   (1 = store: write to data memory)
//       - MemtoReg   (mux select: ALU result or memory data in WB)
//                    Also used by ForwardingUnit to block forwarding
//                    of unready load data from MEM stage
//
//     WB-stage controls (carried through untouched):
//       - RegWrite   (write to register file in WB stage)
//       - Jump       (mux select: PC+4 for JAL writeback in WB)
//
// BRANCH SIGNALS REMOVED:
//   In the previous version, BranchTarget, PCSrc, Zero, and Negative
//   were all carried through this register because branch resolution
//   happened at the MEM stage (2-cycle penalty).
//
//   Branch resolution has been moved to the EX stage (1-cycle penalty).
//   PCSrc is now computed combinationally in TopLevelPipelined directly
//   from EX stage signals (EX_Zero, EX_blt, EX_funct3, EX_Branch).
//   The PC mux and flush signals are driven from EX stage outputs
//   directly - they do not need to be latched here.
//
//   Removing these signals:
//     - Eliminates 1 cycle of branch penalty (2 -> 1 bubble)
//     - Removes dead registers (BranchTarget, PCSrc, Zero, Negative)
//     - Simplifies this register significantly
//
// NO FLUSH, NO STALL:
//   EX_MEM does not flush or stall. During a load-use stall, the load
//   instruction is already past ID stage and continues normally through
//   EX and MEM. During a branch flush, the branch instruction itself
//   completes normally - only the wrong instructions behind it are
//   flushed (handled by IF_ID_Reg and ID_EX_Reg).
//
// ============================================================

module EX_MEM_Reg (
    input  wire        clk,
    input  wire        rst,

    // ---- DATA inputs from EX stage -------------------------
    input  wire [31:0] EX_PC_Plus4,     // for JAL return address (WB)
    input  wire [31:0] EX_ALUResult,    // memory address or arithmetic result
    input  wire [31:0] EX_WriteData,    // forwarded rs2 - data for stores
    input  wire [4:0]  EX_rd,           // destination register

    // ---- CONTROL inputs from EX stage ----------------------
    input  wire        EX_MemRead,      // load instruction
    input  wire        EX_MemWrite,     // store instruction
    input  wire        EX_RegWrite,     // write result to register file (WB)
    input  wire        EX_MemtoReg,     // 0=ALUResult, 1=MemReadData written to rd
    input  wire        EX_Jump,         // JAL: write PC+4 to rd (WB)

    // ---- DATA outputs to MEM stage -------------------------
    output reg  [31:0] MEM_PC_Plus4,
    output reg  [31:0] MEM_ALUResult,
    output reg  [31:0] MEM_WriteData,
    output reg  [4:0]  MEM_rd,

    // ---- CONTROL outputs to MEM stage ----------------------
    output reg         MEM_MemRead,
    output reg         MEM_MemWrite,
    output reg         MEM_RegWrite,
    output reg         MEM_MemtoReg,    // also used by ForwardingUnit
    output reg         MEM_Jump
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_PC_Plus4  <= 32'b0;
            MEM_ALUResult <= 32'b0;
            MEM_WriteData <= 32'b0;
            MEM_rd        <= 5'b0;
            MEM_MemRead   <= 1'b0;
            MEM_MemWrite  <= 1'b0;
            MEM_RegWrite  <= 1'b0;
            MEM_MemtoReg  <= 1'b0;
            MEM_Jump      <= 1'b0;
        end
        else begin
            MEM_PC_Plus4  <= EX_PC_Plus4;
            MEM_ALUResult <= EX_ALUResult;
            MEM_WriteData <= EX_WriteData;
            MEM_rd        <= EX_rd;
            MEM_MemRead   <= EX_MemRead;
            MEM_MemWrite  <= EX_MemWrite;
            MEM_RegWrite  <= EX_RegWrite;
            MEM_MemtoReg  <= EX_MemtoReg;
            MEM_Jump      <= EX_Jump;
        end
    end

endmodule