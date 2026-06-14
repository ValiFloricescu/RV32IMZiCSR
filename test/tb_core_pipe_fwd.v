`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_core_pipe_fwd.v  -  Pipeline cu forwarding + hazard
// ------------------------------------------------------------
//  Ruleaza prog3 (dependente RAW inlantuite + un hazard load-use)
//  FARA NICIUN NOP. Daca rezultatele sunt corecte, forwarding-ul
//  si stall-ul load-use functioneaza. Fara branch-uri (Faza 5).
//
//    x1=5, x2=8, x3=13, x4=5, x5=13, x6=18, x7=19, MEM[0]=13
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_core_pipe_fwd.vcd"
`endif
`ifndef PROG_HEX
 `define PROG_HEX "sw/prog3.hex"
`endif

module sim_imem_f #(parameter WORDS = 256) (
    input wire [31:0] addr, output wire [31:0] rdata
);
    reg [31:0] mem [0:WORDS-1]; integer k;
    initial begin
        for (k = 0; k < WORDS; k = k + 1) mem[k] = `RV_NOP;
        $readmemh(`PROG_HEX, mem);
    end
    assign rdata = mem[addr[9:2]];
endmodule

module sim_dmem_f #(parameter WORDS = 256) (
    input wire clk, input wire [31:0] addr, input wire [31:0] wdata,
    input wire [3:0] wstrb, input wire we, output wire [31:0] rdata
);
    reg [31:0] mem [0:WORDS-1]; integer k;
    initial for (k = 0; k < WORDS; k = k + 1) mem[k] = 32'b0;
    wire [7:0] widx = addr[9:2];
    always @(posedge clk) if (we) begin
        if (wstrb[0]) mem[widx][7:0]   <= wdata[7:0];
        if (wstrb[1]) mem[widx][15:8]  <= wdata[15:8];
        if (wstrb[2]) mem[widx][23:16] <= wdata[23:16];
        if (wstrb[3]) mem[widx][31:24] <= wdata[31:24];
    end
    assign rdata = mem[widx];
endmodule

module tb_core_pipe_fwd;

    reg         clk = 1'b0, rst_n;
    integer     errors = 0, c;
    wire [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we;

    always #5 clk = ~clk;

    riscv_core_pipe dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );
    sim_imem_f u_imem (.addr(imem_addr), .rdata(imem_rdata));
    sim_dmem_f u_dmem (.clk(clk), .addr(dmem_addr), .wdata(dmem_wdata),
                       .wstrb(dmem_wstrb), .we(dmem_we), .rdata(dmem_rdata));

    task chk; input integer id; input [31:0] got, exp; begin
        if (got !== exp) begin
            errors = errors + 1;
            $display("  FAIL test %0d: got=%h exp=%h", id, got, exp);
        end
    end endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_core_pipe_fwd);
        $display("[CORE_PIPE_FWD] rulez prog3 (dependente reale, FARA NOP)...");

        rst_n = 1'b0; @(negedge clk); @(negedge clk); rst_n = 1'b1;
        for (c = 0; c < 40; c = c + 1) @(negedge clk);

        chk(1, dut.u_rf.regs[1], 32'd5);    // x1
        chk(2, dut.u_rf.regs[2], 32'd8);    // x2 = x1+3
        chk(3, dut.u_rf.regs[3], 32'd13);   // x3 = x2+x1
        chk(4, dut.u_rf.regs[4], 32'd5);    // x4 = x3-x2
        chk(5, dut.u_rf.regs[5], 32'd13);   // x5 = MEM[0]
        chk(6, dut.u_rf.regs[6], 32'd18);   // x6 = x5+x1 (load-use)
        chk(7, dut.u_rf.regs[7], 32'd19);   // x7 = x6+1
        chk(8, u_dmem.mem[0],    32'd13);   // MEM[0]

        if (errors == 0)
            $display("[CORE_PIPE_FWD] >>> PASS <<< (forwarding + load-use OK, fara NOP)");
        else
            $display("[CORE_PIPE_FWD] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
