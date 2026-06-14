`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_imm_gen.v  -  Testbench pentru generatorul de immediate
// ------------------------------------------------------------
//  Strategie: pornim de la o valoare immediate cunoscuta, o
//  "impachetam" in campurile instructiunii (cod independent de
//  imm_gen), apoi verificam ca imm_gen reconstruieste valoarea
//  extinsa cu semn. Asa evitam sa testam implementarea cu ea insasi.
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_imm_gen.vcd"
`endif

module tb_imm_gen;

    reg  [31:0]           instr;
    reg  [`IMM_SEL_W-1:0] sel;
    wire [`XLEN-1:0]      imm;
    integer               errors = 0;

    imm_gen dut (.instr(instr), .imm_sel(sel), .imm(imm));

    task chk;
        input integer     id;
        input [`XLEN-1:0] got;
        input [`XLEN-1:0] exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d: got=%h exp=%h", id, got, exp);
            end
        end
    endtask

    // valori de test (k = immediate intentionat)
    reg [31:0] k;

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_imm_gen);
        $display("[IMM_GEN] pornire teste...");

        // ---------- I-type (addi/load/jalr) ----------
        // negativ: -4
        k = 32'hFFFFFFFC;
        instr = {k[11:0], 5'd2, 3'b000, 5'd1, `OPC_OP_IMM};
        sel = `IMM_I; #1; chk(1, imm, {{20{k[11]}}, k[11:0]});
        // pozitiv: +2047 (max I)
        k = 32'h000007FF;
        instr = {k[11:0], 5'd2, 3'b000, 5'd1, `OPC_OP_IMM};
        sel = `IMM_I; #1; chk(2, imm, {{20{k[11]}}, k[11:0]});

        // ---------- S-type (store) ----------
        // -8
        k = 32'hFFFFFFF8;
        instr = {k[11:5], 5'd3, 5'd2, `F3_SW, k[4:0], `OPC_STORE};
        sel = `IMM_S; #1; chk(3, imm, {{20{k[11]}}, k[11:0]});
        // +100
        k = 32'd100;
        instr = {k[11:5], 5'd3, 5'd2, `F3_SW, k[4:0], `OPC_STORE};
        sel = `IMM_S; #1; chk(4, imm, {{20{k[11]}}, k[11:0]});

        // ---------- B-type (branch, multiplu de 2, bit0=0) ----------
        // -4
        k = 32'hFFFFFFFC;
        instr = {k[12], k[10:5], 5'd3, 5'd2, `F3_BEQ, k[4:1], k[11], `OPC_BRANCH};
        sel = `IMM_B; #1; chk(5, imm, {{19{k[12]}}, k[12:0]});
        // +16
        k = 32'd16;
        instr = {k[12], k[10:5], 5'd3, 5'd2, `F3_BEQ, k[4:1], k[11], `OPC_BRANCH};
        sel = `IMM_B; #1; chk(6, imm, {{19{k[12]}}, k[12:0]});

        // ---------- U-type (lui/auipc) ----------
        k = 32'hABCDE000;
        instr = {k[31:12], 5'd1, `OPC_LUI};
        sel = `IMM_U; #1; chk(7, imm, {k[31:12], 12'b0});
        k = 32'h12345000;
        instr = {k[31:12], 5'd1, `OPC_LUI};
        sel = `IMM_U; #1; chk(8, imm, {k[31:12], 12'b0});

        // ---------- J-type (jal, multiplu de 2, bit0=0) ----------
        // -8
        k = 32'hFFFFFFF8;
        instr = {k[20], k[10:1], k[11], k[19:12], 5'd1, `OPC_JAL};
        sel = `IMM_J; #1; chk(9, imm, {{11{k[20]}}, k[20:0]});
        // +4096
        k = 32'h00001000;
        instr = {k[20], k[10:1], k[11], k[19:12], 5'd1, `OPC_JAL};
        sel = `IMM_J; #1; chk(10, imm, {{11{k[20]}}, k[20:0]});

        if (errors==0) $display("[IMM_GEN] >>> PASS <<< (toate formatele I/S/B/U/J corecte)");
        else           $display("[IMM_GEN] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
