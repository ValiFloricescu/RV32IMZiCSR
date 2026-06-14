`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_forwarding.v  -  Testbench pentru unitatea de forwarding
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_forwarding.vcd"
`endif

module tb_forwarding;

    reg  [4:0] idex_rs1, idex_rs2, exmem_rd, memwb_rd;
    reg        exmem_rw, memwb_rw;
    wire [1:0] fa, fb;
    integer    errors = 0;

    forwarding dut (
        .idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
        .exmem_rd(exmem_rd), .exmem_reg_write(exmem_rw),
        .memwb_rd(memwb_rd), .memwb_reg_write(memwb_rw),
        .forward_a(fa), .forward_b(fb)
    );

    task chk;
        input integer id; input [1:0] got, exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d: got=%b exp=%b", id, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_forwarding);
        $display("[FWD] pornire teste...");

        // niciun hazard
        idex_rs1=1; idex_rs2=2; exmem_rd=3; exmem_rw=1; memwb_rd=4; memwb_rw=1; #1;
        chk(1, fa, `FWD_NONE); chk(2, fb, `FWD_NONE);

        // hazard EX/MEM pe rs1
        idex_rs1=3; idex_rs2=2; exmem_rd=3; exmem_rw=1; memwb_rd=4; memwb_rw=1; #1;
        chk(3, fa, `FWD_EXMEM);

        // hazard MEM/WB pe rs2 (fara EX/MEM)
        idex_rs1=1; idex_rs2=4; exmem_rd=3; exmem_rw=1; memwb_rd=4; memwb_rw=1; #1;
        chk(4, fb, `FWD_MEMWB);

        // prioritate EX/MEM peste MEM/WB (ambele potrivesc rs1)
        idex_rs1=5; idex_rs2=2; exmem_rd=5; exmem_rw=1; memwb_rd=5; memwb_rw=1; #1;
        chk(5, fa, `FWD_EXMEM);

        // rd == x0 -> fara forwarding
        idex_rs1=0; idex_rs2=2; exmem_rd=0; exmem_rw=1; memwb_rd=4; memwb_rw=1; #1;
        chk(6, fa, `FWD_NONE);

        // reg_write = 0 -> fara forwarding
        idex_rs1=3; idex_rs2=2; exmem_rd=3; exmem_rw=0; memwb_rd=4; memwb_rw=0; #1;
        chk(7, fa, `FWD_NONE);

        if (errors==0) $display("[FWD] >>> PASS <<<");
        else           $display("[FWD] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
