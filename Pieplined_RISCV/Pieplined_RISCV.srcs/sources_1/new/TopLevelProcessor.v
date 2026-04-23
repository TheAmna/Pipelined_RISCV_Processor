// add_wave_divider "DUT Internals"
// add_wave /Task1_tb/u_dut/*


//add_wave /Task1_tb/u_dut/*
//restart
//run all


`timescale 1ns / 1ps

module TopLevelProcessor (
    input wire clk,
    input wire rst
);

    // --------------------------------------------------------
    // PC DATAPATH WIRES
    // --------------------------------------------------------
    wire [31:0] PC;
    wire [31:0] PC_Plus4;
    wire [31:0] BranchTarget;
    wire [31:0] PC_Next;
    wire        PCSrc;

    // --------------------------------------------------------
    // INSTRUCTION MEMORY WIRES
    // --------------------------------------------------------
    wire [31:0] instruction;

    // --------------------------------------------------------
    // INSTRUCTION FIELD WIRES
    // --------------------------------------------------------
    wire [6:0]  opcode;
    wire [4:0]  rs1_addr;
    wire [4:0]  rs2_addr;
    wire [4:0]  rd_addr;
    wire [2:0]  funct3;
    wire [6:0]  funct7;

    assign opcode    = instruction[6:0];
    assign rd_addr   = instruction[11:7];
    assign funct3    = instruction[14:12];
    assign rs1_addr  = instruction[19:15];
    assign rs2_addr  = instruction[24:20];
    assign funct7    = instruction[31:25];

    // --------------------------------------------------------
    // CONTROL SIGNAL WIRES
    // --------------------------------------------------------
    wire        RegWrite;
    wire        ALUSrc;
    wire        MemRead;
    wire        MemWrite;
    wire        MemtoReg;
    wire        Branch;
    wire [1:0]  ALUOp;
    wire [3:0]  ALUControl;

    // --------------------------------------------------------
    // REGISTER FILE WIRES
    // --------------------------------------------------------
    wire [31:0] ReadData1;
    wire [31:0] ReadData2;
    wire [31:0] WriteData;

    // --------------------------------------------------------
    // IMMEDIATE AND ALU WIRES
    // --------------------------------------------------------
    wire [31:0] imm_out;
    wire [31:0] ALU_B;
    wire [31:0] ALUResult;
    wire        Zero;
    wire        blt;

    // --------------------------------------------------------
    // DATA MEMORY WIRE
    // --------------------------------------------------------
    wire [31:0] MemReadData;

    // --------------------------------------------------------
    // BRANCH CONDITION LOGIC
    // Supports BEQ, BNE, BLT, BGE using funct3
    // --------------------------------------------------------
    reg branch_condition;
    always @(*) begin
        case (funct3)
            3'b000: branch_condition = Zero;     // BEQ
            3'b001: branch_condition = ~Zero;    // BNE
            3'b100: branch_condition = blt;      // BLT
            3'b101: branch_condition = ~blt;     // BGE
            default: branch_condition = 1'b0;
        endcase
    end
    assign PCSrc = Branch & branch_condition;

    // --------------------------------------------------------
    // Program Counter
    // --------------------------------------------------------
    ProgramCounter u_pc (
        .clk     (clk),
        .rst     (rst),
        .stall   (1'b0), 
        .PC_Next (PC_Next),
        .PC      (PC)
    );

    // --------------------------------------------------------
    // PC + 4 Adder
    // --------------------------------------------------------
    pcAdder u_pcAdder (
        .PC       (PC),
        .PC_Plus4 (PC_Plus4)
    );

    // --------------------------------------------------------
    // Immediate Generator
    // --------------------------------------------------------
    immGen u_immGen (
        .instruction (instruction),
        .imm_out     (imm_out)
    );

    // --------------------------------------------------------
    // Branch Target Adder
    // Computes PC + (imm << 1)
    // --------------------------------------------------------
    branchAdder u_branchAdder (
        .PC           (PC),
        .imm          (imm_out),
        .BranchTarget (BranchTarget)
    );

    // --------------------------------------------------------
    // PC Select Mux
    // sel=0 -> PC+4 (sequential)
    // sel=1 -> BranchTarget (branch taken)
    // --------------------------------------------------------
    mux2 u_mux_pc (
        .sel (PCSrc),
        .in0 (PC_Plus4),
        .in1 (BranchTarget),
        .out (PC_Next)
    );

    // --------------------------------------------------------
    // Instruction Memory
    // --------------------------------------------------------
    InstructionMemory u_instmem (
        .instAddress (PC),
        .instruction (instruction)
    );

    // --------------------------------------------------------
    // Main Control Unit
    // --------------------------------------------------------
    MainControl u_main_ctrl (
        .opcode   (opcode),
        .RegWrite (RegWrite),
        .ALUSrc   (ALUSrc),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .MemtoReg (MemtoReg),
        .Branch   (Branch),
        .ALUOp    (ALUOp)
    );

    // --------------------------------------------------------
    // ALU Control Unit
    // --------------------------------------------------------
    ALUControl u_alu_ctrl (
        .ALUOp      (ALUOp),
        .funct3     (funct3),
        .funct7     (funct7),
        .ALUControl (ALUControl)
    );

    // --------------------------------------------------------
    // Register File
    // --------------------------------------------------------
    RegisterFile u_regfile (
        .clk         (clk),
        .rst         (rst),
        .WriteEnable (RegWrite),
        .rs1         (rs1_addr),
        .rs2         (rs2_addr),
        .rd          (rd_addr),
        .WriteData   (WriteData),
        .ReadData1   (ReadData1),
        .ReadData2   (ReadData2)
    );

    // --------------------------------------------------------
    // ALU Source Mux
    // sel=0 -> ReadData2 (R-type)
    // sel=1 -> imm_out   (I/S/B-type)
    // --------------------------------------------------------
    mux2 u_mux_alusrc (
        .sel (ALUSrc),
        .in0 (ReadData2),
        .in1 (imm_out),
        .out (ALU_B)
    );

    // --------------------------------------------------------
    // ALU
    // --------------------------------------------------------
    ALU u_alu (
        .A          (ReadData1),
        .B          (ALU_B),
        .ALUControl (ALUControl),
        .ALUResult  (ALUResult),
        .Zero       (Zero),
        .blt        (blt)
    );

    // --------------------------------------------------------
    // Data Memory
    // --------------------------------------------------------
    DataMemory u_datamem (
        .clk        (clk),
        .MemWrite   (MemWrite),
        .MemRead    (MemRead),
        .address    (ALUResult),
        .write_data (ReadData2),
        .read_data  (MemReadData)
    );

    // --------------------------------------------------------
    // Writeback Mux
    // sel=0 -> ALUResult   (R-type, I-arithmetic)
    // sel=1 -> MemReadData (load instructions)
    // --------------------------------------------------------
    mux2 u_mux_wb (
        .sel (MemtoReg),
        .in0 (ALUResult),
        .in1 (MemReadData),
        .out (WriteData)
    );

endmodule