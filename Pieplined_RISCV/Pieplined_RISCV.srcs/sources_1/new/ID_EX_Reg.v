`timescale 1ns / 1ps
// ============================================================
// ID_EX_Reg.v
// Pipeline Register between Decode (ID) and Execute (EX) stages
// ============================================================
//
// WHAT THIS REGISTER HOLDS:
//   After the Decode stage completes, we have:
//
//   DATA signals:
//     - PC, PC+4          (for branch target and JAL return addr)
//     - ReadData1         (rs1 value from register file)
//     - ReadData2         (rs2 value from register file)
//     - imm_out           (sign-extended immediate from immGen)
//     - rs1_addr, rs2_addr, rd_addr  (register addresses needed
//       by ForwardingUnit and HazardDetectionUnit)
//     - funct3, funct7    (needed by ALUControl in EX stage)
//
//   CONTROL signals (split into groups by when they are used):
//     EX-stage controls:
//       - ALUSrc     (mux: rs2 or immediate into ALU)
//       - ALUOp      (tells ALUControl which operation class)
//       - BranchType (funct3 of branch, for condition evaluation)
//       - Branch     (this instruction is a conditional branch)
//       - Jump       (this instruction is JAL)
//
//     MEM-stage controls (carried through EX untouched):
//       - MemRead    (load instruction)
//       - MemWrite   (store instruction)
//
//     WB-stage controls (carried through EX and MEM untouched):
//       - RegWrite   (write result to register file)
//       - MemtoReg   (mux: ALU result or memory data)
//
// WHY CARRY CONTROL SIGNALS FORWARD?
//   Each control signal is only USED in one stage, but it must
//   TRAVEL through the pipeline registers from where it is generated
//   (ID/Decode) to where it is needed.
//   For example, RegWrite is used in WB, but it is generated in ID.
//   It must pass through ID/EX, EX/MEM, and MEM/WB registers.
//
// FLUSH vs STALL - WHY THEY ARE NOW SEPARATED:
//
//   FLUSH (branch taken or reset):
//     The instruction in ID is a WRONG instruction that must be
//     completely discarded. We zero ALL signals - both data and
//     control - to turn it into a harmless NOP.
//     Triggered by: rst=1 or flush=1 (PCSrc from EX stage)
//
//   STALL (load-use hazard):
//     The instruction in ID is a CORRECT instruction that just
//     needs to wait one cycle for the load data to be ready.
//     We zero ONLY the control signals to insert a clean NOP bubble.
//     Data signals are left alone (they don't matter since all
//     control signals are 0, but leaving them preserves debuggability
//     - you can see in the waveform what instruction was stalled).
//     Triggered by: stall=1 from HazardDetectionUnit
//
//   Previously flush and stall were treated identically (both zeroed
//   everything). This worked functionally but made waveform debugging
//   harder because you couldn't distinguish a stall bubble from a
//   flush bubble. Now they are clearly separated.
//
//   PRIORITY: flush > stall > normal
//   If both flush and stall arrive simultaneously (very rare: a branch
//   resolves at the same cycle as a load-use stall), flush wins because
//   the branch outcome makes the stalled instruction irrelevant anyway.
//
// ============================================================

module ID_EX_Reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,       // 1 = discard instruction (branch taken)
    input  wire        stall,       // 1 = insert bubble (load-use hazard)

    // ---- DATA inputs from ID stage -------------------------
    input  wire [31:0] ID_PC,
    input  wire [31:0] ID_PC_Plus4,
    input  wire [31:0] ID_ReadData1,
    input  wire [31:0] ID_ReadData2,
    input  wire [31:0] ID_Imm,
    input  wire [4:0]  ID_rs1,
    input  wire [4:0]  ID_rs2,
    input  wire [4:0]  ID_rd,
    input  wire [2:0]  ID_funct3,
    input  wire [6:0]  ID_funct7,

    // ---- CONTROL inputs from ID stage ----------------------
    // EX-stage controls
    input  wire        ID_ALUSrc,
    input  wire [1:0]  ID_ALUOp,
    input  wire [2:0]  ID_BranchType,
    input  wire        ID_Branch,
    input  wire        ID_Jump,
    // MEM-stage controls
    input  wire        ID_MemRead,
    input  wire        ID_MemWrite,
    // WB-stage controls
    input  wire        ID_RegWrite,
    input  wire        ID_MemtoReg,

    // ---- DATA outputs to EX stage --------------------------
    output reg  [31:0] EX_PC,
    output reg  [31:0] EX_PC_Plus4,
    output reg  [31:0] EX_ReadData1,
    output reg  [31:0] EX_ReadData2,
    output reg  [31:0] EX_Imm,
    output reg  [4:0]  EX_rs1,
    output reg  [4:0]  EX_rs2,
    output reg  [4:0]  EX_rd,
    output reg  [2:0]  EX_funct3,
    output reg  [6:0]  EX_funct7,

    // ---- CONTROL outputs to EX stage -----------------------
    output reg         EX_ALUSrc,
    output reg  [1:0]  EX_ALUOp,
    output reg  [2:0]  EX_BranchType,
    output reg         EX_Branch,
    output reg         EX_Jump,
    output reg         EX_MemRead,
    output reg         EX_MemWrite,
    output reg         EX_RegWrite,
    output reg         EX_MemtoReg
);

    always @(posedge clk or posedge rst) begin

        // -------------------------------------------------------
        // FLUSH: reset OR branch taken
        // Zero everything - wrong instruction, fully discard
        // -------------------------------------------------------
        if (rst || flush) begin
            EX_PC          <= 32'b0;
            EX_PC_Plus4    <= 32'b0;
            EX_ReadData1   <= 32'b0;
            EX_ReadData2   <= 32'b0;
            EX_Imm         <= 32'b0;
            EX_rs1         <= 5'b0;
            EX_rs2         <= 5'b0;
            EX_rd          <= 5'b0;
            EX_funct3      <= 3'b0;
            EX_funct7      <= 7'b0;
            EX_ALUSrc      <= 1'b0;
            EX_ALUOp       <= 2'b00;
            EX_BranchType  <= 3'b000;
            EX_Branch      <= 1'b0;
            EX_Jump        <= 1'b0;
            EX_MemRead     <= 1'b0;
            EX_MemWrite    <= 1'b0;
            EX_RegWrite    <= 1'b0;
            EX_MemtoReg    <= 1'b0;
        end

        // -------------------------------------------------------
        // STALL: load-use hazard
        // Zero ONLY control signals - insert clean NOP bubble
        // Data signals kept as-is for waveform debuggability
        // -------------------------------------------------------
        else if (stall) begin
            // Control signals zeroed -> this cycle becomes a NOP
            EX_ALUSrc      <= 1'b0;
            EX_ALUOp       <= 2'b00;
            EX_BranchType  <= 3'b000;
            EX_Branch      <= 1'b0;
            EX_Jump        <= 1'b0;
            EX_MemRead     <= 1'b0;
            EX_MemWrite    <= 1'b0;
            EX_RegWrite    <= 1'b0;
            EX_MemtoReg    <= 1'b0;
            // Data signals unchanged (harmless, controls are all 0)
            EX_PC          <= EX_PC;
            EX_PC_Plus4    <= EX_PC_Plus4;
            EX_ReadData1   <= EX_ReadData1;
            EX_ReadData2   <= EX_ReadData2;
            EX_Imm         <= EX_Imm;
            EX_rs1         <= EX_rs1;
            EX_rs2         <= EX_rs2;
            EX_rd          <= EX_rd;
            EX_funct3      <= EX_funct3;
            EX_funct7      <= EX_funct7;
        end

        // -------------------------------------------------------
        // NORMAL: latch all ID stage values
        // -------------------------------------------------------
        else begin
            EX_PC          <= ID_PC;
            EX_PC_Plus4    <= ID_PC_Plus4;
            EX_ReadData1   <= ID_ReadData1;
            EX_ReadData2   <= ID_ReadData2;
            EX_Imm         <= ID_Imm;
            EX_rs1         <= ID_rs1;
            EX_rs2         <= ID_rs2;
            EX_rd          <= ID_rd;
            EX_funct3      <= ID_funct3;
            EX_funct7      <= ID_funct7;
            EX_ALUSrc      <= ID_ALUSrc;
            EX_ALUOp       <= ID_ALUOp;
            EX_BranchType  <= ID_BranchType;
            EX_Branch      <= ID_Branch;
            EX_Jump        <= ID_Jump;
            EX_MemRead     <= ID_MemRead;
            EX_MemWrite    <= ID_MemWrite;
            EX_RegWrite    <= ID_RegWrite;
            EX_MemtoReg    <= ID_MemtoReg;
        end
    end

endmodule