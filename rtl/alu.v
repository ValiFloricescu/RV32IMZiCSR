`timescale 1ns / 1ps
`include "riscv_defs.vh"

module alu (
    input  wire [`XLEN-1:0]     a,
    input  wire [`XLEN-1:0]     b,
    input  wire [`ALU_OP_W-1:0] alu_op,
    output reg  [`XLEN-1:0]     result,
    output wire                 zero
);

    wire [4:0] shamt = b[4:0];   // cantitatea de shift (5 biti pt. RV32)

    always @(*) begin
        case (alu_op)
            `ALU_ADD   : result = a + b;
            `ALU_SUB   : result = a - b;
            `ALU_SLL   : result = a << shamt;
            `ALU_SLT   : result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU  : result = (a < b)                   ? 32'd1 : 32'd0;
            `ALU_XOR   : result = a ^ b;
            `ALU_SRL   : result = a >> shamt;
            `ALU_SRA   : result = $signed(a) >>> shamt;
            `ALU_OR    : result = a | b;
            `ALU_AND   : result = a & b;
            `ALU_COPY_B: result = b;               // pentru LUI
            default    : result = {`XLEN{1'b0}};   // ALU_NOP / necunoscut
        endcase
    end

    assign zero = (result == {`XLEN{1'b0}});

endmodule
