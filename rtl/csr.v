`timescale 1ns / 1ps
`include "riscv_defs.vh"

module csr (
    input  wire        clk,
    input  wire        rst_n,
    // acces CSR (din EX)
    input  wire        rd_en,
    input  wire        wr_en,
    input  wire [11:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg         addr_valid,
    // eveniment trap / mret (din EX)
    input  wire        trap_en,
    input  wire [31:0] trap_cause,
    input  wire [31:0] trap_epc,
    input  wire [31:0] trap_val,
    input  wire        mret_en,
    // iesiri spre redirectarea PC-ului
    output wire [31:0] mtvec_o,
    output wire [31:0] mepc_o
);

    // ---- registri de stare (campurile relevante) ----
    reg        mstatus_mie, mstatus_mpie;
    reg [31:0] mtvec, mscratch, mepc, mcause, mtval, mie, mip;

    // mstatus reconstituit: MIE=bit3, MPIE=bit7, MPP=bits[12:11]=11
    wire [31:0] mstatus = {19'b0, 2'b11, 4'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};

    assign mtvec_o = {mtvec[31:2], 2'b00};   // mod direct
    assign mepc_o  = mepc;

    always @(*) begin
        addr_valid = 1'b1;
        case (addr)
            `CSR_MSTATUS : rdata = mstatus;
            `CSR_MISA    : rdata = `MISA_RV32IM;
            `CSR_MIE     : rdata = mie;
            `CSR_MTVEC   : rdata = mtvec;
            `CSR_MSCRATCH: rdata = mscratch;
            `CSR_MEPC    : rdata = mepc;
            `CSR_MCAUSE  : rdata = mcause;
            `CSR_MTVAL   : rdata = mtval;
            `CSR_MIP     : rdata = mip;
            `CSR_MVENDORID,
            `CSR_MARCHID,
            `CSR_MIMPID,
            `CSR_MHARTID : rdata = 32'b0;
            default      : begin rdata = 32'b0; addr_valid = 1'b0; end
        endcase
    end

    // ---- scriere / actualizare la trap / mret ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_mie <= 1'b0; mstatus_mpie <= 1'b0;
            mtvec <= 32'b0; mscratch <= 32'b0; mepc <= 32'b0;
            mcause <= 32'b0; mtval <= 32'b0; mie <= 32'b0; mip <= 32'b0;
        end else if (trap_en) begin
            mepc        <= trap_epc;
            mcause      <= trap_cause;
            mtval       <= trap_val;
            mstatus_mpie<= mstatus_mie;
            mstatus_mie <= 1'b0;
        end else if (mret_en) begin
            mstatus_mie <= mstatus_mpie;
            mstatus_mpie<= 1'b1;
        end else if (wr_en) begin
            case (addr)
                `CSR_MSTATUS : begin mstatus_mie <= wdata[3]; mstatus_mpie <= wdata[7]; end
                `CSR_MIE     : mie      <= wdata;
                `CSR_MTVEC   : mtvec    <= wdata;
                `CSR_MSCRATCH: mscratch <= wdata;
                `CSR_MEPC    : mepc     <= wdata;
                `CSR_MCAUSE  : mcause   <= wdata;
                `CSR_MTVAL   : mtval    <= wdata;
                `CSR_MIP     : mip      <= wdata;
                default      : ;
            endcase
        end
    end

endmodule
