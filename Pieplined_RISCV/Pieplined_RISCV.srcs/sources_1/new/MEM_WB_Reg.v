`timescale 1ns / 1ps
// ============================================================
// MEM_WB_Reg.v
// Pipeline Register between Memory (MEM) and Writeback (WB) stages
// ============================================================
//
// WHAT THIS REGISTER HOLDS:
//   After the Memory stage, we have:
//
//   DATA signals:
//     - PC_Plus4      (JAL return address to write to rd)
//     - ALUResult     (arithmetic/address result - written to rd
//                      for R-type, I-type instructions)
//     - MemReadData   (data read from data memory for loads)
//     - rd            (destination register address)
//
//   CONTROL signals (all WB-stage, used right here):
//     - RegWrite   (1 = write to register file)
//     - MemtoReg   (0 = write ALUResult, 1 = write MemReadData)
//     - Jump       (1 = write PC+4 instead, for JAL)
//
// WRITEBACK MUX LOGIC (implemented in TopLevelPipelined):
//   The three-way mux for WriteData:
//     Jump=1              -> WriteData = PC_Plus4  (JAL)
//     Jump=0, MemtoReg=1  -> WriteData = MemReadData (load)
//     Jump=0, MemtoReg=0  -> WriteData = ALUResult   (R/I type)
//
// WHY PC_Plus4 IS CARRIED ALL THE WAY HERE:
//   JAL writes its return address (PC+4) to the destination
//   register. PC+4 was computed in IF stage, carried through
//   IF_ID, ID_EX, EX_MEM, and now MEM_WB before being written
//   in the WB stage. It travels as data, not a control signal.
//
// FORWARDING NOTE:
//   The ForwardingUnit can forward from MEM/WB stage to EX stage.
//   The forwarded value in that case is ALUResult (for R/I type)
//   or MemReadData (for loads, one cycle after the load completes).
//   The forwarding mux in EX selects from MEM_WB_ALUResult or
//   MEM_WB_MemReadData based on MEM_WB_MemtoReg.
//   Actually the ForwardingUnit just forwards MEM_WB_ALUResult
//   for the EX->EX forward case, and the WB writeback handles
//   the MEM->WB case. See ForwardingUnit.v for details.
//
// NO FLUSH, NO STALL:
//   MEM_WB never needs flushing or stalling. It is the last
//   pipeline register. Incorrect instructions are caught before
//   they reach this stage.
//
// ============================================================

module MEM_WB_Reg (
    input  wire        clk,
    input  wire        rst,

    // ---- DATA inputs from MEM stage ------------------------
    input  wire [31:0] MEM_PC_Plus4,
    input  wire [31:0] MEM_ALUResult,
    input  wire [31:0] MEM_MemReadData,
    input  wire [4:0]  MEM_rd,

    // ---- CONTROL inputs from MEM stage ---------------------
    input  wire        MEM_RegWrite,
    input  wire        MEM_MemtoReg,
    input  wire        MEM_Jump,

    // ---- DATA outputs to WB stage --------------------------
    output reg  [31:0] WB_PC_Plus4,
    output reg  [31:0] WB_ALUResult,
    output reg  [31:0] WB_MemReadData,
    output reg  [4:0]  WB_rd,

    // ---- CONTROL outputs to WB stage -----------------------
    output reg         WB_RegWrite,
    output reg         WB_MemtoReg,
    output reg         WB_Jump
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            WB_PC_Plus4    <= 32'b0;
            WB_ALUResult   <= 32'b0;
            WB_MemReadData <= 32'b0;
            WB_rd          <= 5'b0;
            WB_RegWrite    <= 1'b0;
            WB_MemtoReg    <= 1'b0;
            WB_Jump        <= 1'b0;
        end
        else begin
            WB_PC_Plus4    <= MEM_PC_Plus4;
            WB_ALUResult   <= MEM_ALUResult;
            WB_MemReadData <= MEM_MemReadData;
            WB_rd          <= MEM_rd;
            WB_RegWrite    <= MEM_RegWrite;
            WB_MemtoReg    <= MEM_MemtoReg;
            WB_Jump        <= MEM_Jump;
        end
    end

endmodule