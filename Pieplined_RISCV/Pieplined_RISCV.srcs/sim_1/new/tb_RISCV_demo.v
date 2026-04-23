`timescale 1ns / 1ps
// ============================================================
// tb_RISCV_demo.v
// Bubble Sort demonstration testbench for TopLevelPipelined
//
// PROGRAM: Bubble sort on 10 elements
// INPUT  (unsorted): {23, 12, 5, 44, 98, 53, 6, 89, 32, 65}
// OUTPUT (sorted)  : {5, 6, 12, 23, 32, 44, 53, 65, 89, 98}
//
// ARRAY LAYOUT IN DATA MEMORY:
//   Our DataMemory: reg [31:0] mem [0:511]
//   Word-addressed - each entry is one full 32-bit word.
//   Access: mem[address[8:0]] where address value = word index.
//   Assembly uses base word address x19=10, no shift needed.
//
//   mem[10] = array[0] = 23
//   mem[11] = array[1] = 12
//   mem[12] = array[2] = 5
//   mem[13] = array[3] = 44
//   mem[14] = array[4] = 98
//   mem[15] = array[5] = 53
//   mem[16] = array[6] = 6
//   mem[17] = array[7] = 89
//   mem[18] = array[8] = 32
//   mem[19] = array[9] = 65
//
// INSTRUCTION MEMORY:
//   20 instructions loaded from instruction.mem via $readmemh
//   PC is byte-addressed, divided by 4 internally for word index
//   Last instruction is at PC = 0x4C  (instruction 20, index 19)
//
// PIPELINE HAZARDS THIS PROGRAM EXERCISES:
//   Load-use stall  : lw x18 followed by blt x17,x18 (1 stall)
//   EX/MEM forward  : addi x15 -> add x15,x15,x19
//   MEM/WB forward  : add x15 -> lw x17,0(x15)
//   Branch penalty  : beq unconditional back to INNERLOOP (1 bubble
//                     every iteration), blt/beq on compare,
//                     beq on outer loop repeat
//
// TERMINATION:
//   Primary  : wait for IF_PC == 0x4C (EXIT instruction fetched)
//              then drain pipeline for 10 more cycles
//   Fallback : stop after 20000ns (2000 cycles) - more than
//              enough for bubble sort on 10 elements with all
//              stalls and branch penalties included
//
// WAVEFORM - ADD THESE SIGNALS IN VIVADO:
//   Pipeline control  : PCSrc, Stall, ID_EX_Stall, ForwardA, ForwardB
//   Stage tracking    : IF_PC, IF_Instr, ID_Instr,
//                       EX_ALUResult, MEM_ALUResult,
//                       MEM_ReadData, WB_WriteData, WB_rd, WB_RegWrite
//   Array elements    : array_element_0 .. array_element_9
//                       (watch these change as the sort progresses)
//   Register file     : uut.u_regfile.regs[10..19] (key registers)
// ============================================================

`define LAST_PC  32'h0000_004C   // EXIT instruction: (20-1)*4 = 76 = 0x4C
`define TIMEOUT  20000            // fallback: 20000ns = 2000 cycles

module tb_RISCV_demo;

    reg clk;
    reg rst;

    // ============================================================
    // DUT INSTANTIATION
    // ============================================================
    TopLevelPipelined uut (
        .clk (clk),
        .rst (rst)
    );

    // ============================================================
    // CLOCK - 10ns period, posedge at t=5,15,25...
    // ============================================================
    initial clk = 1'b0;
    always  #5  clk = ~clk;

    // ============================================================
    // RESET
    // Hold rst=1 for 2 full clock cycles so every pipeline
    // register (PC, IF/ID, ID/EX, EX/MEM, MEM/WB) sees at least
    // one posedge clk while rst=1 and is guaranteed zeroed.
    // Release on a clean clock boundary (not mid-cycle).
    // ============================================================
    initial begin
        rst = 1'b1;
        @(posedge clk);
        @(posedge clk);
        #1;
        rst = 1'b0;
    end

    // ============================================================
    // ARRAY PRE-LOAD INTO DATA MEMORY
    // Directly writes unsorted values into uut.u_datamem.mem[]
    // at word indices 10-19, matching the assembly's base address.
    //
    // Timing: runs at t=25ns, just after reset deasserts (t=21ns).
    // DataMemory's own initial block zeroes all 512 words at t=0,
    // so we write on top of that zeroed state cleanly.
    //
    // Unsorted: {23, 12, 5, 44, 98, 53, 6, 89, 32, 65}
    // Expected: {5, 6, 12, 23, 32, 44, 53, 65, 89, 98}
    // ============================================================
    initial begin
        #1;
        uut.u_datamem.mem[10] = 32'd23;   // array[0]
        uut.u_datamem.mem[11] = 32'd12;   // array[1]
        uut.u_datamem.mem[12] = 32'd5;    // array[2]
        uut.u_datamem.mem[13] = 32'd44;   // array[3]
        uut.u_datamem.mem[14] = 32'd98;   // array[4]
        uut.u_datamem.mem[15] = 32'd53;   // array[5]
        uut.u_datamem.mem[16] = 32'd6;    // array[6]
        uut.u_datamem.mem[17] = 32'd89;   // array[7]
        uut.u_datamem.mem[18] = 32'd32;   // array[8]
        uut.u_datamem.mem[19] = 32'd65;   // array[9]
    end

    // ============================================================
    // PIPELINE CONTROL SIGNALS
    // Exposed as named top-level wires so they appear directly
    // in the waveform without having to expand the hierarchy.
    // ============================================================
    wire        PCSrc       = uut.PCSrc;        // branch taken in EX
    wire        Stall       = uut.Stall;         // load-use: freeze PC+IF/ID
    wire        ID_EX_Stall = uut.ID_EX_Stall;  // load-use: bubble in EX
    wire [1:0]  ForwardA    = uut.ForwardA;      // ALU input A forward select
    wire [1:0]  ForwardB    = uut.ForwardB;      // ALU input B forward select

    // ============================================================
    // STAGE TRACKING SIGNALS
    // One key signal per pipeline stage so you can trace any
    // instruction as it flows IF -> ID -> EX -> MEM -> WB.
    // ============================================================
    wire [31:0] IF_PC         = uut.IF_PC;         // fetch:   current PC
    wire [31:0] IF_Instr      = uut.IF_Instr;      // fetch:   raw instruction
    wire [31:0] ID_Instr      = uut.ID_Instr;      // decode:  instruction
    wire [31:0] ID_PC         = uut.ID_PC;         // decode:  PC
    wire [31:0] EX_ALUResult  = uut.EX_ALUResult;  // execute: ALU output
    wire [31:0] EX_BranchTarget = uut.EX_BranchTarget; // execute: branch addr
    wire [31:0] MEM_ALUResult = uut.MEM_ALUResult; // memory:  address/result
    wire [31:0] MEM_WriteData = uut.MEM_WriteData; // memory:  store data
    wire [31:0] MEM_ReadData  = uut.MEM_ReadData;  // memory:  load data
    wire        MEM_MemWrite  = uut.MEM_MemWrite;  // memory:  store enable
    wire        MEM_MemRead   = uut.MEM_MemRead;   // memory:  load enable
    wire [4:0]  MEM_rd        = uut.MEM_rd;        // memory:  destination reg
    wire        MEM_RegWrite  = uut.MEM_RegWrite;  // memory:  reg write enable
    wire [31:0] WB_WriteData  = uut.WB_WriteData;  // writeback: value to write
    wire [4:0]  WB_rd         = uut.WB_rd;         // writeback: destination reg
    wire        WB_RegWrite   = uut.WB_RegWrite;   // writeback: write enable

    // ============================================================
    // ARRAY ELEMENTS FROM DATA MEMORY
    // Each is one 32-bit word directly from mem[].
    // No byte assembly needed (unlike byte-addressed memories).
    // Watch these change in the waveform as swaps happen -
    // you will see the array gradually sort from left to right.
    //
    // Start: {23, 12,  5, 44, 98, 53,  6, 89, 32, 65}
    // End  : { 5,  6, 12, 23, 32, 44, 53, 65, 89, 98}
    // ============================================================
    wire [31:0] array_element_0 = uut.u_datamem.mem[10]; // c[0]
    wire [31:0] array_element_1 = uut.u_datamem.mem[11]; // c[1]
    wire [31:0] array_element_2 = uut.u_datamem.mem[12]; // c[2]
    wire [31:0] array_element_3 = uut.u_datamem.mem[13]; // c[3]
    wire [31:0] array_element_4 = uut.u_datamem.mem[14]; // c[4]
    wire [31:0] array_element_5 = uut.u_datamem.mem[15]; // c[5]
    wire [31:0] array_element_6 = uut.u_datamem.mem[16]; // c[6]
    wire [31:0] array_element_7 = uut.u_datamem.mem[17]; // c[7]
    wire [31:0] array_element_8 = uut.u_datamem.mem[18]; // c[8]
    wire [31:0] array_element_9 = uut.u_datamem.mem[19]; // c[9]

    // ============================================================
    // TERMINATION - PRIMARY
    // Wait until IF_PC reaches the EXIT instruction (0x4C).
    // Then wait 10 more cycles to fully drain the pipeline
    // (5 stages minimum + buffer for any trailing stall bubbles).
    // ============================================================
    initial begin
        wait (uut.IF_PC == `LAST_PC);
        repeat (10) @(posedge clk);
        $finish;
    end

    // ============================================================
    // TERMINATION - FALLBACK TIMEOUT
    // Stops simulation after 20000ns if LAST_PC is never reached.
    // 20000ns = 2000 cycles at 10ns period - sufficient for
    // bubble sort on 10 elements including all hazard penalties.
    // ============================================================
    initial begin
        #`TIMEOUT;
        $finish;
    end

endmodule