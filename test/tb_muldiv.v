`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_muldiv.v  -  Testbench pentru unitatea M (muldiv)
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_muldiv.vcd"
`endif

module tb_muldiv;

    reg         clk = 1'b0, rst_n;
    reg         start;
    reg  [31:0] a, b;
    reg  [2:0]  op;
    wire [31:0] result;
    wire        busy, done;
    integer     errors = 0;

    always #5 clk = ~clk;

    muldiv dut (.clk(clk), .rst_n(rst_n), .start(start),
                .a(a), .b(b), .op(op),
                .result(result), .busy(busy), .done(done));

    task run_op;
        input integer id;
        input [2:0]   o;
        input [31:0]  x, y, exp;
        begin
            @(negedge clk); op = o; a = x; b = y; start = 1'b1;
            @(negedge clk); start = 1'b0;
            wait (done == 1'b1);
            if (result !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d (op=%b): got=%h exp=%h", id, o, result, exp);
            end
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_muldiv);
        $display("[MULDIV] pornire teste...");
        rst_n = 1'b0; start = 1'b0; a = 0; b = 0; op = 0;
        @(negedge clk); @(negedge clk); rst_n = 1'b1;

        // inmultiri
        run_op(1,  `F3_MUL,    32'd6, 32'd7, 32'd42);
        run_op(2,  `F3_MUL,    -32'd3, 32'd5, 32'hFFFFFFF1);
        run_op(3,  `F3_MULHU,  32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE);
        run_op(4,  `F3_MULH,   32'h80000000, 32'h80000000, 32'h40000000);
        run_op(5,  `F3_MULHSU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF);
        // impartiri / resturi
        run_op(6,  `F3_DIV,   32'd100, 32'd7, 32'd14);
        run_op(7,  `F3_REM,   32'd100, 32'd7, 32'd2);
        run_op(8,  `F3_DIV,   -32'd100, 32'd7, -32'd14);
        run_op(9,  `F3_REM,   -32'd100, 32'd7, -32'd2);
        run_op(10, `F3_DIVU,  32'd100, 32'd7, 32'd14);
        run_op(11, `F3_REMU,  32'd100, 32'd7, 32'd2);
        // cazuri speciale
        run_op(12, `F3_DIV,   32'd5, 32'd0, 32'hFFFFFFFF);
        run_op(13, `F3_REM,   32'd5, 32'd0, 32'd5);
        run_op(14, `F3_DIVU,  32'd5, 32'd0, 32'hFFFFFFFF);
        run_op(15, `F3_REMU,  32'd5, 32'd0, 32'd5);
        run_op(16, `F3_DIV,   32'h80000000, 32'hFFFFFFFF, 32'h80000000);
        run_op(17, `F3_REM,   32'h80000000, 32'hFFFFFFFF, 32'd0);

        if (errors == 0) $display("[MULDIV] >>> PASS <<< (toate operatiile M corecte)");
        else             $display("[MULDIV] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
