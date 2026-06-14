`timescale 1ns/1ps
`include "riscv_defs.vh"

`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_regfile.vcd"
`endif

module tb_regfile;

    reg               clk = 1'b0;
    reg               we;
    reg  [4:0]        rd_addr, rs1_addr, rs2_addr;
    reg  [`XLEN-1:0]  rd_data;
    wire [`XLEN-1:0]  rs1_data, rs2_data;
    integer           errors = 0;

    always #5 clk = ~clk;   // ceas 100 MHz

    regfile dut (
        .clk(clk),
        .we(we), .rd_addr(rd_addr), .rd_data(rd_data),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    // scrie val in registrul addr (stimul aliniat pe negedge -> scriere pe posedge)
    task write_reg;
        input [4:0]       addr;
        input [`XLEN-1:0] val;
        begin
            @(negedge clk); we = 1'b1; rd_addr = addr; rd_data = val;
            @(negedge clk); we = 1'b0;
        end
    endtask

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
        $dumpvars(0, tb_regfile);
        $display("[REGFILE] pornire teste...");

        // --- la initializare, registrele sunt 0 (bloc initial) ---
        we = 1'b0; rd_addr = 0; rd_data = 0;
        rs1_addr = 5'd5; rs2_addr = 5'd6;
        @(negedge clk);
        chk(1, rs1_data, 32'd0);          // la initializare, x5 = 0

        // --- scriere/citire x5 ---
        write_reg(5'd5, 32'hDEADBEEF);
        rs1_addr = 5'd5; #1;
        chk(2, rs1_data, 32'hDEADBEEF);

        // --- al doilea port de citire, x6 ---
        write_reg(5'd6, 32'h12345678);
        rs2_addr = 5'd6; #1;
        chk(3, rs2_data, 32'h12345678);

        // --- x0 ramane 0 chiar daca incercam sa scriem in el ---
        write_reg(5'd0, 32'hFFFFFFFF);
        rs1_addr = 5'd0; #1;
        chk(4, rs1_data, 32'd0);

        // --- citiri simultane independente ---
        rs1_addr = 5'd5; rs2_addr = 5'd6; #1;
        chk(5, rs1_data, 32'hDEADBEEF);
        chk(6, rs2_data, 32'h12345678);

        if (errors==0) $display("[REGFILE] >>> PASS <<< (scriere/citire/x0 corecte)");
        else           $display("[REGFILE] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule