`timescale 1ns/1ps
// ============================================================
//  tb_sanity.v  -  Test minimal pentru verificarea toolchain-ului
// ------------------------------------------------------------
//  Confirma ca iverilog + vvp compileaza/ruleaza si ca scrierea
//  formei de unda (VCD pentru GTKWave) merge. Nu testeaza CPU-ul.
// ============================================================

// Numele fisierului VCD vine din Makefile (-D DUMP_FILE). Fallback local:
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_sanity.vcd"
`endif

module tb_sanity;

    reg        clk = 1'b0;
    reg  [7:0] count = 8'd0;

    always #5 clk = ~clk;            // ceas 100 MHz (perioada 10 ns)

    always @(posedge clk)
        count <= count + 8'd1;

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_sanity);

        $display("[SANITY] Toolchain Icarus pornit. Numar 10 fronturi de ceas...");
        #100;
        $display("[SANITY] count = %0d (asteptat: 10)", count);
        if (count == 8'd10) $display("[SANITY] >>> PASS <<<");
        else                $display("[SANITY] >>> FAIL <<<");
        $finish;
    end

endmodule