`timescale 1ns / 1ps
`include "riscv_defs.vh"

module forwarding (
    input  wire [4:0] idex_rs1,
    input  wire [4:0] idex_rs2,
    input  wire [4:0] exmem_rd,
    input  wire       exmem_reg_write,
    input  wire [4:0] memwb_rd,
    input  wire       memwb_reg_write,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    always @(*) begin
        // ---- operand A (rs1) ----
        if (exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == idex_rs1))
            forward_a = `FWD_EXMEM;
        else if (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == idex_rs1))
            forward_a = `FWD_MEMWB;
        else
            forward_a = `FWD_NONE;

        // ---- operand B (rs2) ----
        if (exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == idex_rs2))
            forward_b = `FWD_EXMEM;
        else if (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == idex_rs2))
            forward_b = `FWD_MEMWB;
        else
            forward_b = `FWD_NONE;
    end

endmodule
