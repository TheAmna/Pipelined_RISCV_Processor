`timescale 1ns / 1ps
// ============================================================
// mux3.v
// 3-input 32-bit multiplexer
// Used for forwarding muxes in EX stage
// ============================================================
//
// SELECTION ENCODING (matches ForwardingUnit output):
//   2'b00 -> in0  (no forwarding: use register file value)
//   2'b01 -> in1  (forward from WB stage: WB_WriteData)
//   2'b10 -> in2  (forward from MEM stage: MEM_ALUResult)
//   2'b11 -> in0  (unused: default to in0 safely)
//
// ============================================================

module mux3 (
    input  wire [1:0]  sel,   // select signal from ForwardingUnit
    input  wire [31:0] in0,   // 00: no forward (register file)
    input  wire [31:0] in1,   // 01: forward from WB
    input  wire [31:0] in2,   // 10: forward from MEM
    output reg  [31:0] out
);

    always @(*) begin
        case (sel)
            2'b00:   out = in0;   // no forwarding
            2'b01:   out = in1;   // forward from WB
            2'b10:   out = in2;   // forward from MEM
            default: out = in0;   // safe default
        endcase
    end

endmodule