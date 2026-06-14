`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_core_pipe_trap.v  -  CSR (Zicsr) + trap prin pipeline (Faza 9)
// ------------------------------------------------------------
//  Ruleaza prog6: seteaza mtvec, scrie/citeste CSR-uri, face ECALL,
//  ruleaza handler-ul, ajusteaza mepc si revine cu MRET.
//
//    x7  = 0x123        (csrr mscratch dupa csrw)
//    x8  = 0x40001100   (csrr misa)
//    x9  = 11           (mcause = ECALL din mod M)
//    x20 = 42           (handler a rulat)
//    x21 = 7            (am revenit din trap via MRET)
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_core_pipe_trap.vcd"
`endif
`ifndef PROG_HEX
 `define PROG_HEX "sw/prog6.hex"
`endif

module sim_imem_t #(parameter WORDS=256)(input wire [31:0] addr, output wire [31:0] rdata);
    reg [31:0] mem [0:WORDS-1]; integer k;
    initial begin for (k=0;k<WORDS;k=k+1) mem[k]=`RV_NOP; $readmemh(`PROG_HEX, mem); end
    assign rdata = mem[addr[9:2]];
endmodule
module sim_dmem_t #(parameter WORDS=256)(
    input wire clk, input wire [31:0] addr, wdata, input wire [3:0] wstrb,
    input wire we, output wire [31:0] rdata);
    reg [31:0] mem [0:WORDS-1]; integer k;
    initial for (k=0;k<WORDS;k=k+1) mem[k]=32'b0;
    wire [7:0] idx = addr[9:2];
    always @(posedge clk) if (we) begin
        if(wstrb[0]) mem[idx][7:0]<=wdata[7:0];     if(wstrb[1]) mem[idx][15:8]<=wdata[15:8];
        if(wstrb[2]) mem[idx][23:16]<=wdata[23:16]; if(wstrb[3]) mem[idx][31:24]<=wdata[31:24];
    end
    assign rdata = mem[idx];
endmodule

module tb_core_pipe_trap;
    reg clk=0, rst_n; integer errors=0, c;
    wire [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0] dmem_wstrb; wire dmem_we;
    always #5 clk=~clk;

    riscv_core_pipe dut(.clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata));
    sim_imem_t u_imem(.addr(imem_addr), .rdata(imem_rdata));
    sim_dmem_t u_dmem(.clk(clk), .addr(dmem_addr), .wdata(dmem_wdata),
                      .wstrb(dmem_wstrb), .we(dmem_we), .rdata(dmem_rdata));

    task chk; input integer id; input [31:0] got, exp; begin
        if (got!==exp) begin errors=errors+1; $display("  FAIL %0d: got=%h exp=%h", id, got, exp); end
    end endtask

    initial begin
        $dumpfile(`DUMP_FILE); $dumpvars(0, tb_core_pipe_trap);
        $display("[CORE_PIPE_TRAP] rulez prog6 (CSR + ECALL + MRET)...");
        rst_n=0; @(negedge clk); @(negedge clk); rst_n=1;
        for (c=0;c<200;c=c+1) @(negedge clk);
        chk(1, dut.u_rf.regs[7],  32'h0000_0123);
        chk(2, dut.u_rf.regs[8],  `MISA_RV32IM);
        chk(3, dut.u_rf.regs[9],  `CAUSE_ECALL_M);
        chk(4, dut.u_rf.regs[20], 32'd42);
        chk(5, dut.u_rf.regs[21], 32'd7);
        if (errors==0) $display("[CORE_PIPE_TRAP] >>> PASS <<< (Zicsr + trap + mret OK in pipeline)");
        else           $display("[CORE_PIPE_TRAP] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end
endmodule
