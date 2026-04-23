//`timescale 1ns / 1ps

//module immGen (
//    input  wire [31:0] instruction, // 32-bit instruction
//    output reg  [31:0] imm_out //sign-extended immediate
//);
//    wire [6:0] opcode = instruction[6:0];
//    localparam LOAD    = 7'b0000011; // I-type
//    localparam I_ARITH = 7'b0010011; // I-type
//    localparam JALR    = 7'b1100111; // I-type
//    localparam STORE   = 7'b0100011; // S-type
//    localparam BRANCH  = 7'b1100011; // B-type
//    always @(*) begin
//        case (opcode)
//            // I-type
//            // imm[11:0] from instr[31:20], sign-extended
//            LOAD, I_ARITH, JALR: begin
//                imm_out = {{20{instruction[31]}}, instruction[31:20]};
//            end

 
//            // S-type: Store 
//            // imm upper = instr[31:25], imm lower = instr[11:7]
//            // reassembled and sign-extended
//            STORE: begin
//                imm_out = {{20{instruction[31]}},
//                           instruction[31:25],
//                           instruction[11:7]};
//            end

         
//            // B-type:
//            // Outputs bits[12:1] of the offset sign-extended
//            // bit 0 is always zero so branchAdder shifts left 1
//            // imm[12] = instr[31]   sign bit
//            // imm[11] = instr[7]
//            // imm[10:5] = instr[30:25]
//            // imm[4:1]  = instr[11:8]
           
// //12 bits assembled, sign-extended to 32
           
//            BRANCH: begin
//                imm_out = {{19{instruction[31]}},
//                           instruction[31],
//                           instruction[7],
//                           instruction[30:25],
//                           instruction[11:8],
//                           1'b0};
//            end

//            // default: zero for unrecognised opcode
            
//            default: begin
//                imm_out = 32'd0;
//            end

//        endcase
//    end

//endmodule

`timescale 1ns / 1ps

module immGen (
    input  wire [31:0] instruction, // 32-bit instruction
    output reg  [31:0] imm_out      // sign-extended immediate
);
    wire [6:0] opcode = instruction[6:0];

    localparam LOAD    = 7'b0000011; // I-type (LW, LH, LB)
    localparam I_ARITH = 7'b0010011; // I-type (ADDI, ANDI, ORI, ...)
    localparam STORE   = 7'b0100011; // S-type (SW, SH, SB)
    localparam BRANCH  = 7'b1100011; // B-type (BEQ, BNE, BLT, BGE)

    always @(*) begin
        case (opcode)

            // I-type: LOAD and I-ARITH
            // imm[11:0] = instr[31:20], sign-extended to 32 bits
            LOAD, I_ARITH: begin
                imm_out = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S-type: STORE
            // imm[11:5] = instr[31:25]  (upper)
            // imm[4:0]  = instr[11:7]   (lower)
            // reassembled and sign-extended to 32 bits
            STORE: begin
                imm_out = {{20{instruction[31]}},
                           instruction[31:25],
                           instruction[11:7]};
            end

            // B-type: BRANCH
            // imm[12]   = instr[31]     (sign bit)
            // imm[11]   = instr[7]
            // imm[10:5] = instr[30:25]
            // imm[4:1]  = instr[11:8]
            // imm[0]    = 1'b0          (always zero, half-word aligned)
            // 13 bits total, sign-extended to 32 bits
            BRANCH: begin
                imm_out = {{19{instruction[31]}},
                           instruction[31],
                           instruction[7],
                           instruction[30:25],
                           instruction[11:8],
                           1'b0};
            end

            // Default: zero for any unrecognised opcode
            default: begin
                imm_out = 32'd0;
            end

        endcase
    end

endmodule