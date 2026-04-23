//`timescale 1ns / 1ps

//module InstructionMemory #(
//    parameter OPERAND_LENGTH = 31
//)(
//    input  [OPERAND_LENGTH:0] instAddress, // PC - byte address from processor
//    output reg [31:0]         instruction  // 32-bit instruction word output
//);
//    // 64 words of 32 bits = 256 bytes
//    // each line in the .mem file fills one word slot
//    reg [31:0] memory [0:63];
//    initial begin
//        // load the .mem file - one hex word per line, word-addressed
//        // make sure program.mem is in the Vivado project working directory
//        $readmemh("instruction.mem", memory);
//    end
//    // combinational read
//    // PC is a byte address so divide by 4 to get the word index
//    always @(*) begin
//        if ((instAddress >> 2) < 64)
//            instruction = memory[instAddress >> 2];
//        else
//            instruction = 32'b0;  // safe NOP
//    end
//endmodule



`timescale 1ns / 1ps

// ============================================================
// InstructionMemory.v  (FIXED)
// ------------------------------------------------------------
// Fix vs. previous version:
//   The 64-word array was only being partially filled by
//   $readmemh (the .mem file has 20 instructions, slots 0..19).
//   Slots 20..63 stayed at their default 'X' state, so any
//   speculative fetch past the program end (e.g. PC=80, 84
//   while the EX-stage trap branch was still resolving)
//   returned XXXXXXXX on IF_Instr and propagated to ID_Instr.
//
//   The bounds check below only protects against PC values
//   that map to a word index >= 64 - it does NOT cover the
//   in-range-but-uninitialized slots 20..63, which is where
//   the X was coming from.
//
//   Fix: pre-fill ALL 64 slots with 32'h00000063 (the EXIT
//   trap "beq x0,x0,0") BEFORE $readmemh runs. $readmemh
//   then overwrites slots 0..19 with the real program, and
//   any speculative fetch past the end now decodes as another
//   harmless trap-loop branch instead of X.
//
//   Choice of fill value:
//     32'h00000063 - same as the program's EXIT instruction.
//                    Speculative fetches past the program
//                    behave identically to the real EXIT.
//     32'h00000013 - canonical RISC-V NOP (addi x0,x0,0).
//     32'h00000000 - decodes via MainControl default case
//                    as all-zero control signals (NOP).
//   Any of the three eliminates the X. 00000063 is used here
//   because it matches the program's own halt semantics.
// ============================================================

module InstructionMemory #(
    parameter OPERAND_LENGTH = 31
)(
    input  [OPERAND_LENGTH:0] instAddress, // PC - byte address from processor
    output reg [31:0]         instruction  // 32-bit instruction word output
);

    // 64 words of 32 bits = 256 bytes
    reg [31:0] memory [0:63];

    integer i;
    initial begin
        // ----------------------------------------------------
        // Step 1: pre-fill every slot with a defined value.
        // This eliminates X on any slot that $readmemh
        // does not overwrite (slots 20..63 in this program).
        // ----------------------------------------------------
        for (i = 0; i < 64; i = i + 1) begin
            memory[i] = 32'h00000063;   // EXIT/trap: beq x0, x0, 0
        end

        // ----------------------------------------------------
        // Step 2: load the actual program. Overwrites slots
        // 0..N-1 where N = number of lines in the file.
        // Make sure instruction.mem is in the Vivado project
        // working directory (or sim launch directory).
        // ----------------------------------------------------
        $readmemh("instruction.mem", memory);
    end

    // Combinational read.
    // PC is a byte address so divide by 4 to get the word index.
    always @(*) begin
        if ((instAddress >> 2) < 64)
            instruction = memory[instAddress >> 2];
        else
            instruction = 32'h00000063;  // out-of-range fetch -> trap
    end

endmodule


