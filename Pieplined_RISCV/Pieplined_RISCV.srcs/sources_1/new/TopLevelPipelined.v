`timescale 1ns / 1ps

// ============================================================
// TopLevelPipelined.v
// 5-Stage Pipelined RISC-V Processor (32-bit)
//
// Stages:
//   IF  - Instruction Fetch
//   ID  - Instruction Decode + Register Read
//   EX  - Execute (ALU + Branch Resolution)
//   MEM - Memory Access
//   WB  - Write Back
//
// Key design decisions:
//
//   BRANCH RESOLUTION AT EX STAGE (1-cycle penalty)
//     PCSrc is computed combinationally in EX using EX_Zero,
//     EX_blt, EX_funct3, and EX_Branch directly from ID/EX outputs.
//     On a taken branch: IF/ID and ID/EX are flushed in the SAME
//     cycle PCSrc goes high. Only 1 bubble is inserted.
//
//   LOAD-USE STALL (1-cycle stall)
//     HazardDetectionUnit detects when EX stage is a load and
//     ID stage reads the same register. It freezes PC and IF/ID,
//     and inserts a bubble into ID/EX for one cycle.
//
//   FORWARDING (no stall for non-load RAW hazards)
//     ForwardingUnit routes EX/MEM.ALUResult or WB_WriteData
//     back to ALU inputs A and B via mux3 selectors.
//     EX/MEM forwarding is blocked when MemtoReg=1 (load in MEM).
//
//   WRITEBACK MUX (3-way)
//     Jump=1              -> WB_WriteData = WB_PC_Plus4  (JAL)
//     Jump=0, MemtoReg=1  -> WB_WriteData = WB_MemReadData (load)
//     Jump=0, MemtoReg=0  -> WB_WriteData = WB_ALUResult   (R/I)
//     Implemented as two cascaded mux2 instances.
//
// ============================================================

module TopLevelPipelined (
    input wire clk,
    input wire rst
);

// ============================================================
// IF STAGE WIRES
// ============================================================

    wire [31:0] IF_PC;          // current PC output from ProgramCounter
    wire [31:0] IF_PC_Plus4;    // PC + 4 from pcAdder
    wire [31:0] IF_Instr;       // instruction from InstructionMemory
    wire [31:0] IF_PC_Next;     // next PC into ProgramCounter (output of PC mux)

// ============================================================
// IF/ID REGISTER OUTPUTS  ?  ID stage inputs
// ============================================================

    wire [31:0] ID_PC;
    wire [31:0] ID_PC_Plus4;
    wire [31:0] ID_Instr;

// ============================================================
// ID STAGE WIRES
// ============================================================

    // Instruction fields decoded from ID_Instr
    wire [6:0]  ID_opcode;
    wire [4:0]  ID_rs1_addr;
    wire [4:0]  ID_rs2_addr;
    wire [4:0]  ID_rd_addr;
    wire [2:0]  ID_funct3;
    wire [6:0]  ID_funct7;

    assign ID_opcode   = ID_Instr[6:0];
    assign ID_rd_addr  = ID_Instr[11:7];
    assign ID_funct3   = ID_Instr[14:12];
    assign ID_rs1_addr = ID_Instr[19:15];
    assign ID_rs2_addr = ID_Instr[24:20];
    assign ID_funct7   = ID_Instr[31:25];

    // Register file read data
    wire [31:0] ID_ReadData1;
    wire [31:0] ID_ReadData2;

    // Immediate generator output
    wire [31:0] ID_Imm;

    // MainControl outputs
    wire        ID_RegWrite;
    wire        ID_ALUSrc;
    wire        ID_MemRead;
    wire        ID_MemWrite;
    wire        ID_MemtoReg;
    wire        ID_Branch;
    wire [1:0]  ID_ALUOp;

    // Hazard detection outputs
    wire        Stall;        // 1 = freeze PC + IF/ID register
    wire        ID_EX_Stall;  // 1 = insert bubble into ID/EX register

    // Branch flush: PCSrc computed in EX, flushes IF/ID and ID/EX
    wire        PCSrc;        // 1 = branch taken (computed in EX stage)

// ============================================================
// ID/EX REGISTER OUTPUTS  ?  EX stage inputs
// ============================================================

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
    wire [2:0]  EX_BranchType;  // = funct3, used for branch condition decode
    wire        EX_Branch;
    wire        EX_Jump;
    wire        EX_MemRead;
    wire        EX_MemWrite;
    wire        EX_RegWrite;
    wire        EX_MemtoReg;

// ============================================================
// EX STAGE WIRES
// ============================================================

    wire [1:0]  ForwardA;         // forwarding mux select for ALU input A
    wire [1:0]  ForwardB;         // forwarding mux select for ALU input B

    wire [31:0] EX_FwdA_Out;     // ALU input A after forwarding mux
    wire [31:0] EX_FwdB_Out;     // rs2 after forwarding mux (before ALUSrc mux)
    wire [31:0] EX_ALU_B;        // final ALU input B (after ALUSrc mux)

    wire [3:0]  EX_ALUControl;   // from ALUControl unit
    wire [31:0] EX_ALUResult;    // ALU output
    wire        EX_Zero;         // ALU zero flag
    wire        EX_blt;          // ALU signed less-than flag

    wire [31:0] EX_BranchTarget; // PC + imm (from branchAdder)

    // Branch condition evaluated combinationally in EX
    // Uses EX_funct3 to select which condition to check
    reg  EX_branch_condition;
    always @(*) begin
        case (EX_funct3)
            3'b000: EX_branch_condition = EX_Zero;    // BEQ
            3'b001: EX_branch_condition = ~EX_Zero;   // BNE
            3'b100: EX_branch_condition = EX_blt;     // BLT
            3'b101: EX_branch_condition = ~EX_blt;    // BGE
            default: EX_branch_condition = 1'b0;
        endcase
    end

    // PCSrc: drives PC mux AND flushes IF/ID and ID/EX
    assign PCSrc = EX_Branch & EX_branch_condition;

// ============================================================
// EX/MEM REGISTER OUTPUTS  ?  MEM stage inputs
// ============================================================

    wire [31:0] MEM_PC_Plus4;
    wire [31:0] MEM_ALUResult;
    wire [31:0] MEM_WriteData;
    wire [4:0]  MEM_rd;

    wire        MEM_MemRead;
    wire        MEM_MemWrite;
    wire        MEM_RegWrite;
    wire        MEM_MemtoReg;
    wire        MEM_Jump;

// ============================================================
// MEM STAGE WIRES
// ============================================================

    wire [31:0] MEM_ReadData;   // data read from DataMemory

// ============================================================
// MEM/WB REGISTER OUTPUTS  ?  WB stage inputs
// ============================================================

    wire [31:0] WB_PC_Plus4;
    wire [31:0] WB_ALUResult;
    wire [31:0] WB_MemReadData;
    wire [4:0]  WB_rd;

    wire        WB_RegWrite;
    wire        WB_MemtoReg;
    wire        WB_Jump;

// ============================================================
// WB STAGE WIRES
// ============================================================

    wire [31:0] WB_MemMux_Out;  // output of first WB mux (ALUResult vs MemReadData)
    wire [31:0] WB_WriteData;   // final value written to register file
                                // also fed back to forwarding muxes in EX

// ============================================================
// ============================================================
//  IF STAGE
// ============================================================
// ============================================================

    // ----------------------------------------------------------
    // PC Next Mux
    // sel=0 -> PC+4       (sequential, no branch)
    // sel=1 -> BranchTarget (branch taken, from EX stage)
    // ----------------------------------------------------------
    mux2 u_mux_pc (
        .sel (PCSrc),
        .in0 (IF_PC_Plus4),
        .in1 (EX_BranchTarget),
        .out (IF_PC_Next)
    );

    // ----------------------------------------------------------
    // Program Counter
    // stall=1 freezes PC (load-use hazard)
    // rst=1   resets to 0x00000000
    // ----------------------------------------------------------
    ProgramCounter u_pc (
        .clk     (clk),
        .rst     (rst),
        .stall   (Stall),
        .PC_Next (IF_PC_Next),
        .PC      (IF_PC)
    );

    // ----------------------------------------------------------
    // PC + 4 Adder
    // ----------------------------------------------------------
    pcAdder u_pcAdder (
        .PC       (IF_PC),
        .PC_Plus4 (IF_PC_Plus4)
    );

    // ----------------------------------------------------------
    // Instruction Memory
    // ----------------------------------------------------------
    InstructionMemory u_instmem (
        .instAddress (IF_PC),
        .instruction (IF_Instr)
    );

// ============================================================
// IF/ID PIPELINE REGISTER
// flush = PCSrc (branch taken in EX - discard IF instruction)
// stall = Stall (load-use hazard   - freeze IF instruction)
// ============================================================

    IF_ID_Reg u_if_id (
        .clk         (clk),
        .rst         (rst),
        .flush       (PCSrc),
        .stall       (Stall),
        .IF_PC       (IF_PC),
        .IF_PC_Plus4 (IF_PC_Plus4),
        .IF_Instr    (IF_Instr),
        .ID_PC       (ID_PC),
        .ID_PC_Plus4 (ID_PC_Plus4),
        .ID_Instr    (ID_Instr)
    );

// ============================================================
// ============================================================
//  ID STAGE
// ============================================================
// ============================================================

    // ----------------------------------------------------------
    // Main Control Unit
    // Decodes opcode -> generates all control signals
    // ----------------------------------------------------------
    MainControl u_main_ctrl (
        .opcode   (ID_opcode),
        .RegWrite (ID_RegWrite),
        .ALUSrc   (ID_ALUSrc),
        .MemRead  (ID_MemRead),
        .MemWrite (ID_MemWrite),
        .MemtoReg (ID_MemtoReg),
        .Branch   (ID_Branch),
        .ALUOp    (ID_ALUOp)
    );

    // ----------------------------------------------------------
    // Register File
    // Read:  rs1, rs2 from current ID instruction
    // Write: rd, WriteData from WB stage (WB_rd, WB_WriteData)
    // ----------------------------------------------------------
    RegisterFile u_regfile (
        .clk         (clk),
        .rst         (rst),
        .WriteEnable (WB_RegWrite),
        .rs1         (ID_rs1_addr),
        .rs2         (ID_rs2_addr),
        .rd          (WB_rd),
        .WriteData   (WB_WriteData),
        .ReadData1   (ID_ReadData1),
        .ReadData2   (ID_ReadData2)
    );

    // ----------------------------------------------------------
    // Immediate Generator
    // ----------------------------------------------------------
    immGen u_immGen (
        .instruction (ID_Instr),
        .imm_out     (ID_Imm)
    );

    // ----------------------------------------------------------
    // Hazard Detection Unit
    // Detects load-use hazard:
    //   EX stage is a load (EX_MemRead=1) AND
    //   EX_rd matches rs1 or rs2 of the instruction in ID
    //
    // Stall     -> ProgramCounter.stall + IF_ID_Reg.stall
    // ID_EX_Stall -> ID_EX_Reg.stall (inserts NOP bubble)
    // ----------------------------------------------------------
    HazardDetectionUnit u_hazard (
        .ID_EX_MemRead (EX_MemRead),
        .ID_EX_rd      (EX_rd),
        .IF_ID_rs1     (ID_rs1_addr),
        .IF_ID_rs2     (ID_rs2_addr),
        .Stall         (Stall),
        .ID_EX_Stall   (ID_EX_Stall)
    );

// ============================================================
// ID/EX PIPELINE REGISTER
// flush = PCSrc     (branch taken - discard ID instruction)
// stall = ID_EX_Stall (load-use hazard - insert NOP bubble)
//
// Note: ID_BranchType is wired to ID_funct3 because MainControl
// does not output a separate BranchType signal - funct3 carries
// the branch condition encoding (BEQ/BNE/BLT/BGE).
// Note: ID_Jump = 0 because JAL is not yet implemented in
// MainControl. Wire to 0 until JAL support is added.
// ============================================================

    ID_EX_Reg u_id_ex (
        .clk           (clk),
        .rst           (rst),
        .flush         (PCSrc),
        .stall         (ID_EX_Stall),

        // Data inputs
        .ID_PC         (ID_PC),
        .ID_PC_Plus4   (ID_PC_Plus4),
        .ID_ReadData1  (ID_ReadData1),
        .ID_ReadData2  (ID_ReadData2),
        .ID_Imm        (ID_Imm),
        .ID_rs1        (ID_rs1_addr),
        .ID_rs2        (ID_rs2_addr),
        .ID_rd         (ID_rd_addr),
        .ID_funct3     (ID_funct3),
        .ID_funct7     (ID_funct7),

        // Control inputs
        .ID_ALUSrc     (ID_ALUSrc),
        .ID_ALUOp      (ID_ALUOp),
        .ID_BranchType (ID_funct3),   // funct3 encodes branch condition type
        .ID_Branch     (ID_Branch),
        .ID_Jump       (1'b0),         // JAL not yet implemented
        .ID_MemRead    (ID_MemRead),
        .ID_MemWrite   (ID_MemWrite),
        .ID_RegWrite   (ID_RegWrite),
        .ID_MemtoReg   (ID_MemtoReg),

        // Data outputs
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

        // Control outputs
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

// ============================================================
// ============================================================
//  EX STAGE
// ============================================================
// ============================================================

    // ----------------------------------------------------------
    // Forwarding Unit
    // Compares EX rs1/rs2 against MEM and WB destination regs
    // ForwardA/B encoding:
    //   2'b00 -> no forward (use EX_ReadData1/2 from register file)
    //   2'b01 -> forward from WB  (WB_WriteData)
    //   2'b10 -> forward from MEM (MEM_ALUResult)
    // ----------------------------------------------------------
    ForwardingUnit u_fwd (
        .ID_EX_rs1      (EX_rs1),
        .ID_EX_rs2      (EX_rs2),
        .EX_MEM_rd      (MEM_rd),
        .EX_MEM_RegWrite(MEM_RegWrite),
        .EX_MEM_MemtoReg(MEM_MemtoReg),
        .MEM_WB_rd      (WB_rd),
        .MEM_WB_RegWrite(WB_RegWrite),
        .ForwardA        (ForwardA),
        .ForwardB        (ForwardB)
    );

    // ----------------------------------------------------------
    // Forwarding Mux A  (selects ALU input A)
    // 00: EX_ReadData1   (register file, no hazard)
    // 01: WB_WriteData   (forward from WB stage)
    // 10: MEM_ALUResult  (forward from MEM stage)
    // ----------------------------------------------------------
    mux3 u_mux_fwdA (
        .sel (ForwardA),
        .in0 (EX_ReadData1),
        .in1 (WB_WriteData),
        .in2 (MEM_ALUResult),
        .out (EX_FwdA_Out)
    );

    // ----------------------------------------------------------
    // Forwarding Mux B  (selects forwarded rs2, before ALUSrc mux)
    // 00: EX_ReadData2   (register file, no hazard)
    // 01: WB_WriteData   (forward from WB stage)
    // 10: MEM_ALUResult  (forward from MEM stage)
    //
    // EX_FwdB_Out is ALSO passed directly to EX_MEM_Reg as
    // EX_WriteData for store instructions - this ensures stores
    // write the FORWARDED rs2 value, not the stale register value.
    // ----------------------------------------------------------
    mux3 u_mux_fwdB (
        .sel (ForwardB),
        .in0 (EX_ReadData2),
        .in1 (WB_WriteData),
        .in2 (MEM_ALUResult),
        .out (EX_FwdB_Out)
    );

    // ----------------------------------------------------------
    // ALU Source Mux
    // sel=0 -> EX_FwdB_Out (forwarded rs2, R-type)
    // sel=1 -> EX_Imm      (immediate, I/S/B-type)
    // ----------------------------------------------------------
    mux2 u_mux_alusrc (
        .sel (EX_ALUSrc),
        .in0 (EX_FwdB_Out),
        .in1 (EX_Imm),
        .out (EX_ALU_B)
    );

    // ----------------------------------------------------------
    // ALU Control
    // Decodes ALUOp + funct3 + funct7 -> 4-bit ALUControl
    // ----------------------------------------------------------
    ALUControl u_alu_ctrl (
        .ALUOp      (EX_ALUOp),
        .funct3     (EX_funct3),
        .funct7     (EX_funct7),
        .ALUControl (EX_ALUControl)
    );

    // ----------------------------------------------------------
    // ALU
    // A = forwarded rs1 (EX_FwdA_Out)
    // B = forwarded rs2 or immediate (EX_ALU_B)
    // Produces: ALUResult, Zero flag, blt flag
    // ----------------------------------------------------------
    ALU u_alu (
        .A          (EX_FwdA_Out),
        .B          (EX_ALU_B),
        .ALUControl (EX_ALUControl),
        .ALUResult  (EX_ALUResult),
        .Zero       (EX_Zero),
        .blt        (EX_blt)
    );

    // ----------------------------------------------------------
    // Branch Target Adder
    // BranchTarget = EX_PC + EX_Imm
    // immGen already encodes the x2 shift for B-type immediates
    // so no additional shift needed here.
    // ----------------------------------------------------------
    branchAdder u_branchAdder (
        .PC           (EX_PC),
        .imm          (EX_Imm),
        .BranchTarget (EX_BranchTarget)
    );

    // PCSrc and EX_branch_condition are computed above
    // in the EX STAGE WIRES section (combinational always block)

// ============================================================
// EX/MEM PIPELINE REGISTER
// No flush, no stall needed here.
// Branch instruction completes normally through EX/MEM/WB.
// Wrong instructions behind it are already flushed in IF/ID
// and ID/EX by PCSrc.
//
// EX_WriteData = EX_FwdB_Out (forwarded rs2) NOT EX_ReadData2.
// This ensures store instructions write the correct forwarded
// value to memory, not a stale register file value.
// ============================================================

    EX_MEM_Reg u_ex_mem (
        .clk          (clk),
        .rst          (rst),

        // Data inputs
        .EX_PC_Plus4  (EX_PC_Plus4),
        .EX_ALUResult (EX_ALUResult),
        .EX_WriteData (EX_FwdB_Out),   // forwarded rs2 for stores
        .EX_rd        (EX_rd),

        // Control inputs
        .EX_MemRead   (EX_MemRead),
        .EX_MemWrite  (EX_MemWrite),
        .EX_RegWrite  (EX_RegWrite),
        .EX_MemtoReg  (EX_MemtoReg),
        .EX_Jump      (EX_Jump),

        // Data outputs
        .MEM_PC_Plus4  (MEM_PC_Plus4),
        .MEM_ALUResult (MEM_ALUResult),
        .MEM_WriteData (MEM_WriteData),
        .MEM_rd        (MEM_rd),

        // Control outputs
        .MEM_MemRead   (MEM_MemRead),
        .MEM_MemWrite  (MEM_MemWrite),
        .MEM_RegWrite  (MEM_RegWrite),
        .MEM_MemtoReg  (MEM_MemtoReg),
        .MEM_Jump      (MEM_Jump)
    );

// ============================================================
// ============================================================
//  MEM STAGE
// ============================================================
// ============================================================

    // ----------------------------------------------------------
    // Data Memory
    // address    = MEM_ALUResult (effective address from ALU)
    // write_data = MEM_WriteData (forwarded rs2 from EX/MEM)
    // read_data  = MEM_ReadData  (goes to MEM/WB register)
    // ----------------------------------------------------------
    DataMemory u_datamem (
        .clk        (clk),
        .MemWrite   (MEM_MemWrite),
        .MemRead    (MEM_MemRead),
        .address    (MEM_ALUResult),
        .write_data (MEM_WriteData),
        .read_data  (MEM_ReadData)
    );

// ============================================================
// MEM/WB PIPELINE REGISTER
// No flush, no stall. Last pipeline register.
// ============================================================

    MEM_WB_Reg u_mem_wb (
        .clk             (clk),
        .rst             (rst),

        // Data inputs
        .MEM_PC_Plus4    (MEM_PC_Plus4),
        .MEM_ALUResult   (MEM_ALUResult),
        .MEM_MemReadData (MEM_ReadData),
        .MEM_rd          (MEM_rd),

        // Control inputs
        .MEM_RegWrite    (MEM_RegWrite),
        .MEM_MemtoReg    (MEM_MemtoReg),
        .MEM_Jump        (MEM_Jump),

        // Data outputs
        .WB_PC_Plus4     (WB_PC_Plus4),
        .WB_ALUResult    (WB_ALUResult),
        .WB_MemReadData  (WB_MemReadData),
        .WB_rd           (WB_rd),

        // Control outputs
        .WB_RegWrite     (WB_RegWrite),
        .WB_MemtoReg     (WB_MemtoReg),
        .WB_Jump         (WB_Jump)
    );

// ============================================================
// ============================================================
//  WB STAGE
// ============================================================
// ============================================================

    // ----------------------------------------------------------
    // Writeback Mux - Stage 1
    // sel=0 (MemtoReg=0) -> WB_ALUResult    (R-type, I-arithmetic)
    // sel=1 (MemtoReg=1) -> WB_MemReadData  (load instructions)
    // ----------------------------------------------------------
    mux2 u_mux_wb_mem (
        .sel (WB_MemtoReg),
        .in0 (WB_ALUResult),
        .in1 (WB_MemReadData),
        .out (WB_MemMux_Out)
    );

    // ----------------------------------------------------------
    // Writeback Mux - Stage 2
    // sel=0 (Jump=0) -> WB_MemMux_Out  (normal: ALU or load result)
    // sel=1 (Jump=1) -> WB_PC_Plus4    (JAL: return address)
    // ----------------------------------------------------------
    mux2 u_mux_wb_jump (
        .sel (WB_Jump),
        .in0 (WB_MemMux_Out),
        .in1 (WB_PC_Plus4),
        .out (WB_WriteData)
    );

    // WB_WriteData feeds back to:
    //   1. RegisterFile.WriteData  (write port - wired in ID stage above)
    //   2. ForwardingUnit in1      (MEM/WB forward path - wired in EX stage above)

endmodule