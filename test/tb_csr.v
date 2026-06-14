`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_csr.v  -  Testbench pentru fisierul de CSR-uri + trap
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_csr.vcd"
`endif

module tb_csr;
    reg         clk = 0, rst_n;
    reg         rd_en, wr_en, trap_en, mret_en;
    reg  [11:0] addr;
    reg  [31:0] wdata, trap_cause, trap_epc, trap_val;
    wire [31:0] rdata, mtvec_o, mepc_o;
    wire        addr_valid;
    integer     errors = 0;
    always #5 clk = ~clk;

    csr dut (.clk(clk), .rst_n(rst_n), .rd_en(rd_en), .wr_en(wr_en),
             .addr(addr), .wdata(wdata), .rdata(rdata), .addr_valid(addr_valid),
             .trap_en(trap_en), .trap_cause(trap_cause), .trap_epc(trap_epc),
             .trap_val(trap_val), .mret_en(mret_en), .mtvec_o(mtvec_o), .mepc_o(mepc_o));

    task wr; input [11:0] a; input [31:0] d; begin
        @(negedge clk); addr=a; wdata=d; wr_en=1; @(negedge clk); wr_en=0; end
    endtask
    task rd_chk; input integer id; input [11:0] a; input [31:0] exp; begin
        @(negedge clk); addr=a; rd_en=1; #1;
        if (rdata !== exp) begin errors=errors+1; $display("  FAIL %0d: CSR %h = %h (astept %h)", id, a, rdata, exp); end
        rd_en=0; end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE); $dumpvars(0, tb_csr);
        rd_en=0; wr_en=0; trap_en=0; mret_en=0; addr=0; wdata=0; trap_cause=0; trap_epc=0; trap_val=0;
        rst_n=0; @(negedge clk); @(negedge clk); rst_n=1;

        // citiri read-only
        rd_chk(1, `CSR_MISA, `MISA_RV32IM);
        rd_chk(2, `CSR_MHARTID, 32'd0);

        // scriere/citire
        wr(`CSR_MTVEC, 32'h0000_1240);  rd_chk(3, `CSR_MTVEC, 32'h0000_1240);
        wr(`CSR_MSCRATCH, 32'hDEAD_BEEF); rd_chk(4, `CSR_MSCRATCH, 32'hDEAD_BEEF);
        if (mtvec_o !== 32'h0000_1240) begin errors=errors+1; $display("  FAIL: mtvec_o=%h", mtvec_o); end

        // adresa inexistenta -> addr_valid=0
        @(negedge clk); addr=12'h7C0; rd_en=1; #1;
        if (addr_valid !== 1'b0) begin errors=errors+1; $display("  FAIL: addr_valid pt CSR inexistent"); end
        rd_en=0;

        // pune MIE=1 prin mstatus, apoi declanseaza trap
        wr(`CSR_MSTATUS, 32'h0000_0008);   // MIE=bit3
        @(negedge clk); trap_en=1; trap_cause=`CAUSE_ECALL_M; trap_epc=32'h0000_0080; trap_val=0;
        @(negedge clk); trap_en=0;
        rd_chk(5, `CSR_MEPC, 32'h0000_0080);
        rd_chk(6, `CSR_MCAUSE, `CAUSE_ECALL_M);
        if (mepc_o !== 32'h0000_0080) begin errors=errors+1; $display("  FAIL: mepc_o=%h", mepc_o); end
        // dupa trap: MIE=0, MPIE=1 (vechiul MIE)
        @(negedge clk); addr=`CSR_MSTATUS; rd_en=1; #1;
        if (rdata[3] !== 1'b0 || rdata[7] !== 1'b1) begin errors=errors+1; $display("  FAIL: mstatus dupa trap = %h", rdata); end
        rd_en=0;

        // MRET: MIE<-MPIE(=1), MPIE<-1
        @(negedge clk); mret_en=1; @(negedge clk); mret_en=0;
        @(negedge clk); addr=`CSR_MSTATUS; rd_en=1; #1;
        if (rdata[3] !== 1'b1) begin errors=errors+1; $display("  FAIL: MIE dupa mret = %b", rdata[3]); end
        rd_en=0;

        if (errors==0) $display("[CSR] >>> PASS <<< (CSR-uri + trap + mret corecte)");
        else           $display("[CSR] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end
endmodule
