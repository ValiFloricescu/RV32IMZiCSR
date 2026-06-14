`timescale 1ns / 1ps
`include "riscv_defs.vh"

module hazard (
    input  wire       idex_mem_read,   // instructiunea din EX este LOAD
    input  wire [4:0] idex_rd,         // destinatia load-ului
    input  wire [4:0] ifid_rs1,        // sursele instructiunii din ID
    input  wire [4:0] ifid_rs2,
    output wire       stall            // 1 = ingheata IF si insereaza bula
);

    assign stall = idex_mem_read && (idex_rd != 5'd0) &&
                   ((idex_rd == ifid_rs1) || (idex_rd == ifid_rs2));

endmodule
