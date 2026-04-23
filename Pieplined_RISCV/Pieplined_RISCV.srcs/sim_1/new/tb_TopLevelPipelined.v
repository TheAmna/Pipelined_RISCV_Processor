//`timescale 1ns / 1ps
//module tb_TopLevelPipelined;
//    reg clk;
//    reg rst;

//    TopLevelPipelined uut (
//        .clk(clk),
//        .rst(rst)
//    );

//    always #5 clk = ~clk;

//    initial begin
//        clk = 1'b0;
//        rst = 1'b1;
//        #1;

//        #10;
//        rst = 1'b0;

//        #600;

//        $finish;
//    end

//endmodule

`timescale 1ns / 1ps
// ============================================================
// tb_TopLevelPipelined.v
// Testbench for the 5-stage Pipelined RISC-V Processor
//
// HOW THIS TESTBENCH WORKS:
//   This testbench is intentionally minimal. It does NOT drive
//   any data inputs because the pipelined processor is self-
//   contained - it fetches instructions from InstructionMemory
//   (loaded from instruction.mem) and runs autonomously.
//
//   Our job here is just to:
//     1. Generate the clock
//     2. Apply and release reset cleanly
//     3. Let the processor run long enough
//     4. Stop simulation at the right time
//
// CLOCK:
//   Period = 10ns (5ns high, 5ns low)
//   All pipeline registers update on posedge clk
//
// RESET:
//   rst=1 held for 2 full clock cycles so every pipeline
//   register (PC, IF/ID, ID/EX, EX/MEM, MEM/WB) sees at
//   least one posedge clk while rst=1 and resets cleanly.
//   rst is deasserted on a clean clock boundary (not mid-cycle)
//   to avoid race conditions with the asynchronous reset.
//
// TERMINATION:
//   We wait for uut.IF_PC to reach the known last instruction
//   address of the program loaded in instruction.mem.
//   After that we wait 10 extra clock cycles to let the
//   pipeline drain completely (5 stages = 5 cycles minimum,
//   we add 5 more for any stall bubbles in the tail).
//
//   IMPORTANT: Update LAST_PC below to match the actual last
//   instruction address in your instruction.mem program.
//   Formula: LAST_PC = (number_of_instructions - 1) * 4
//   Example: 20 instructions -> LAST_PC = 19 * 4 = 76 = 0x4C
//
//   If you do not know the last PC yet, the fallback
//   #TIMEOUT block will stop simulation after a fixed time.
//   Set TIMEOUT large enough for your program to finish.
//   At 10ns/cycle: 2000ns = 200 cycles, 5000ns = 500 cycles.
//
// WAVEFORM ANALYSIS (no $display - waveforms only):
//   Add these signals to your Vivado waveform window:
//     uut.IF_PC               -- current PC (IF stage)
//     uut.ID_Instr            -- instruction in ID stage
//     uut.EX_ALUResult        -- ALU result in EX stage
//     uut.MEM_ALUResult       -- address/result in MEM stage
//     uut.MEM_ReadData        -- data read from memory
//     uut.WB_WriteData        -- value written to register file
//     uut.WB_rd               -- destination register in WB
//     uut.WB_RegWrite         -- register write enable in WB
//     uut.Stall               -- load-use stall signal
//     uut.PCSrc               -- branch taken signal
//     uut.u_regfile.regs[*]   -- register file contents
// ============================================================

// Set this to (number_of_instructions - 1) * 4 for your program
`define LAST_PC   32'h0000_004C   // update this before simulating
`define TIMEOUT   5000            // fallback: stop after 5000ns

module tb_TopLevelPipelined;

    reg clk;
    reg rst;

    // ---- Instantiate DUT ------------------------------------
    TopLevelPipelined uut (
        .clk (clk),
        .rst (rst)
    );

    // ---- Clock generation -----------------------------------
    // 10ns period: posedge at t=5, 15, 25 ...
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // ---- Reset ----------------------------------------------
    // Apply reset for 2 full clock cycles then release cleanly
    // on a clock boundary so all pipeline registers reset safely
    initial begin
        rst = 1'b1;              // assert reset immediately

        @(posedge clk);          // wait for 1st rising edge
        @(posedge clk);          // wait for 2nd rising edge
        // All pipeline registers have now seen 2 posedge clk
        // while rst=1 and are guaranteed to be zeroed

        #1;                      // tiny delay past the edge
        rst = 1'b0;              // release reset cleanly
    end

    // ---- Termination ----------------------------------------
    // Primary: stop when PC reaches end of program
    // Pipeline needs extra cycles to drain after last fetch
    initial begin
        // Wait until the processor fetches the last instruction
        wait (uut.IF_PC == `LAST_PC);

        // Drain the pipeline:
        // 5 stages means last instruction needs 4 more cycles
        // to reach WB. We wait 10 to also cover any stall cycles
        // that may be in flight at the tail of the program.
        repeat (10) @(posedge clk);

        $finish;
    end

    // ---- Fallback timeout -----------------------------------
    // Safety net: if LAST_PC is wrong or program loops,
    // stop simulation after TIMEOUT nanoseconds anyway.
    initial begin
        #`TIMEOUT;
        $finish;
    end

endmodule