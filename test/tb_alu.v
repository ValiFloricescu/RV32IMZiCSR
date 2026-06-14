`timescale 1ns/1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_alu.v  -  Testbench pentru unitatea ALU
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_alu.vcd"
`endif

module tb_alu;

    reg  [`XLEN-1:0]     a, b;
    reg  [`ALU_OP_W-1:0] op;
    wire [`XLEN-1:0]     result;
    wire                 zero;
    integer              errors = 0;

    alu dut (.a(a), .b(b), .alu_op(op), .result(result), .zero(zero));

    // verifica rezultatul; id = numarul testului (fara string-uri in task)
    task chk;
        input integer        id;
        input [`XLEN-1:0]    got;
        input [`XLEN-1:0]    exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d: got=%h exp=%h", id, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_alu);
        $display("[ALU] pornire teste...");

        a=32'd5;          b=32'd7;          op=`ALU_ADD;    #1; chk(1,  result, 32'd12);
        a=32'd10;         b=32'd3;          op=`ALU_SUB;    #1; chk(2,  result, 32'd7);
        a=32'd1;          b=32'd4;          op=`ALU_SLL;    #1; chk(3,  result, 32'd16);
        a=32'hFFFFFFFF;   b=32'd1;          op=`ALU_SLT;    #1; chk(4,  result, 32'd1);  // -1 < 1
        a=32'hFFFFFFFF;   b=32'd1;          op=`ALU_SLTU;   #1; chk(5,  result, 32'd0);  // huge >= 1
        a=32'hF0F0F0F0;   b=32'h0FF00FF0;   op=`ALU_XOR;    #1; chk(6,  result, 32'hFF00FF00);
        a=32'h80000000;   b=32'd4;          op=`ALU_SRL;    #1; chk(7,  result, 32'h08000000);
        a=32'h80000000;   b=32'd4;          op=`ALU_SRA;    #1; chk(8,  result, 32'hF8000000);
        a=32'h000000F0;   b=32'h0000000F;   op=`ALU_OR;     #1; chk(9,  result, 32'h000000FF);
        a=32'h000000FF;   b=32'h0000000F;   op=`ALU_AND;    #1; chk(10, result, 32'h0000000F);
        a=32'd0;          b=32'hDEADBEEF;   op=`ALU_COPY_B; #1; chk(11, result, 32'hDEADBEEF);

        // verificare flag zero
        a=32'd5; b=32'd5; op=`ALU_SUB; #1;
        if (zero !== 1'b1) begin errors=errors+1; $display("  FAIL test 12: zero ar trebui 1"); end
        a=32'd5; b=32'd3; op=`ALU_SUB; #1;
        if (zero !== 1'b0) begin errors=errors+1; $display("  FAIL test 13: zero ar trebui 0"); end

        if (errors==0) $display("[ALU] >>> PASS <<< (toate operatiile corecte)");
        else           $display("[ALU] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
