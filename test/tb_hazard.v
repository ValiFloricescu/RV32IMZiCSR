`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_hazard.v  -  Testbench pentru detectia load-use
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_hazard.vcd"
`endif

module tb_hazard;

    reg  [4:0] idex_rd, ifid_rs1, ifid_rs2;
    reg        idex_mem_read;
    wire       stall;
    integer    errors = 0;

    hazard dut (
        .idex_mem_read(idex_mem_read), .idex_rd(idex_rd),
        .ifid_rs1(ifid_rs1), .ifid_rs2(ifid_rs2), .stall(stall)
    );

    task chk;
        input integer id; input got, exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d: got=%b exp=%b", id, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_hazard);
        $display("[HAZARD] pornire teste...");

        // load in EX, rd potriveste rs1 din ID -> stall
        idex_mem_read=1; idex_rd=5; ifid_rs1=5; ifid_rs2=2; #1; chk(1, stall, 1'b1);
        // load, rd potriveste rs2 -> stall
        idex_mem_read=1; idex_rd=7; ifid_rs1=1; ifid_rs2=7; #1; chk(2, stall, 1'b1);
        // load, rd=0 -> fara stall
        idex_mem_read=1; idex_rd=0; ifid_rs1=0; ifid_rs2=0; #1; chk(3, stall, 1'b0);
        // nu e load -> fara stall (chiar daca rd potriveste)
        idex_mem_read=0; idex_rd=5; ifid_rs1=5; ifid_rs2=5; #1; chk(4, stall, 1'b0);
        // load, fara potrivire -> fara stall
        idex_mem_read=1; idex_rd=9; ifid_rs1=1; ifid_rs2=2; #1; chk(5, stall, 1'b0);

        if (errors==0) $display("[HAZARD] >>> PASS <<<");
        else           $display("[HAZARD] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
