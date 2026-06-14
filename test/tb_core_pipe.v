`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_core_pipe.v  -  Testbench pentru nucleul pipeline (NAIV)
// ------------------------------------------------------------
//  Ruleaza un program FARA HAZARDURI (dependente separate cu
//  NOP-uri) ca sa verifice ca mecanica pipeline-ului pe 5 etaje
//  este corecta. Hazardurile reale (fara NOP-uri) se rezolva in
//  Fazele 4-5; pana atunci, codul dependent ar da rezultate gresite.
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_core_pipe.vcd"
`endif
`ifndef PROG_HEX
 `define PROG_HEX "sw/prog2.hex"
`endif

module sim_imem_p #(parameter WORDS = 256) (
    input  wire [31:0] addr, output wire [31:0] rdata
);
    reg [31:0] mem [0:WORDS-1];
    integer k;
    initial begin
        for (k = 0; k < WORDS; k = k + 1) mem[k] = `RV_NOP;
        $readmemh(`PROG_HEX, mem);
    end
    assign rdata = mem[addr[9:2]];
endmodule

module sim_dmem_p #(parameter WORDS = 256) (
    input  wire clk, input wire [31:0] addr, input wire [31:0] wdata,
    input  wire [3:0] wstrb, input wire we, output wire [31:0] rdata
);
    reg [31:0] mem [0:WORDS-1];
    integer k;
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

module tb_core_pipe;

    reg         clk = 1'b0;
    reg         rst_n;
    integer     errors = 0;
    integer     c;

    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we;

    always #5 clk = ~clk;

    riscv_core_pipe dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );

    sim_imem_p u_imem (.addr(imem_addr), .rdata(imem_rdata));
    sim_dmem_p u_dmem (.clk(clk), .addr(dmem_addr), .wdata(dmem_wdata),
                       .wstrb(dmem_wstrb), .we(dmem_we), .rdata(dmem_rdata));

    task chk;
        input integer id; input [31:0] got, exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d: got=%h exp=%h", id, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_core_pipe);
        $display("[CORE_PIPE] rulez program fara hazarduri (cu NOP-uri)...");

        rst_n = 1'b0;
        @(negedge clk); @(negedge clk);
        rst_n = 1'b1;

        for (c = 0; c < 40; c = c + 1) @(negedge clk);

        chk(1, dut.u_rf.regs[1], 32'd5);    // x1
        chk(2, dut.u_rf.regs[2], 32'd7);    // x2
        chk(3, dut.u_rf.regs[3], 32'd12);   // x3 = x1+x2
        chk(4, dut.u_rf.regs[4], 32'd12);   // x4 = MEM[0]
        chk(5, dut.u_rf.regs[5], 32'd17);   // x5 = x4+x1
        chk(6, u_dmem.mem[0],    32'd12);   // MEM[0]

        if (errors == 0)
            $display("[CORE_PIPE] >>> PASS <<< (pipeline corect pe cod fara hazarduri)");
        else
            $display("[CORE_PIPE] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
