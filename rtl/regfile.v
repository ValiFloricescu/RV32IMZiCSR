`timescale 1ns / 1ps
`include "riscv_defs.vh"

module regfile (
    input  wire              clk,
    input  wire              we,
    input  wire [4:0]        rd_addr,
    input  wire [`XLEN-1:0]  rd_data,
    input  wire [4:0]        rs1_addr,
    input  wire [4:0]        rs2_addr,
    output wire [`XLEN-1:0]  rs1_data,
    output wire [`XLEN-1:0]  rs2_data
);
    (* ram_style = "distributed" *)
    reg [`XLEN-1:0] regs [0:31];

    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = {`XLEN{1'b0}};

    // scriere sincrona; x0 (rd_addr==0) nu se scrie niciodata
    always @(posedge clk)
        if (we && (rd_addr != 5'd0))
            regs[rd_addr] <= rd_data;

    // citire combinationala; x0 fortat la 0
    assign rs1_data = (rs1_addr == 5'd0) ? {`XLEN{1'b0}} : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? {`XLEN{1'b0}} : regs[rs2_addr];
endmodule