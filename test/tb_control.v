`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_control.v  -  Testbench pentru unitatea de control
// ------------------------------------------------------------
//  Pentru fiecare tip de instructiune, comparam vectorul de
//  control produs cu unul construit manual din campuri numite
//  (functia pack), ca sa fie usor de citit ce ne asteptam.
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_control.vcd"
`endif

module tb_control;

    reg  [6:0] opcode;
    reg  [2:0] funct3;
    reg        funct7b5;

    wire                   reg_write, alu_a_src, alu_b_src;
    wire [`ALU_OP_W-1:0]   alu_op;
    wire [`IMM_SEL_W-1:0]  imm_sel;
    wire                   mem_read, mem_write;
    wire [`WB_SEL_W-1:0]   wb_sel;
    wire                   branch, jump, jalr;
    integer                errors = 0;

    control dut (
        .opcode(opcode), .funct3(funct3), .funct7b5(funct7b5),
        .reg_write(reg_write), .alu_a_src(alu_a_src), .alu_b_src(alu_b_src),
        .alu_op(alu_op), .imm_sel(imm_sel),
        .mem_read(mem_read), .mem_write(mem_write), .wb_sel(wb_sel),
        .branch(branch), .jump(jump), .jalr(jalr)
    );

    // vectorul de control efectiv (ordinea conteaza, vezi pack)
    wire [16:0] ctrl = {reg_write, alu_a_src, alu_b_src, alu_op,
                        imm_sel, mem_read, mem_write, wb_sel,
                        branch, jump, jalr};

    // construieste vectorul asteptat din campuri numite
    function [16:0] pack;
        input                  rw, aa, ab;
        input [`ALU_OP_W-1:0]  op;
        input [`IMM_SEL_W-1:0] is;
        input                  mr, mw;
        input [`WB_SEL_W-1:0]  wb;
        input                  br, jp, jr;
        begin
            pack = {rw, aa, ab, op, is, mr, mw, wb, br, jp, jr};
        end
    endfunction

    task chk;
        input integer    id;
        input [16:0]     got;
        input [16:0]     exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL test %0d: got=%b exp=%b", id, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_control);
        $display("[CONTROL] pornire teste...");

        //                                rw aa ab  op           is        mr mw wb         br jp jr
        // ADD (R)
        opcode=`OPC_OP;     funct3=`F3_ADD_SUB; funct7b5=0; #1;
        chk(1,  ctrl, pack(1, 0,0, `ALU_ADD,  `IMM_I, 0,0, `WB_ALU, 0,0,0));
        // SUB (R)
        opcode=`OPC_OP;     funct3=`F3_ADD_SUB; funct7b5=1; #1;
        chk(2,  ctrl, pack(1, 0,0, `ALU_SUB,  `IMM_I, 0,0, `WB_ALU, 0,0,0));
        // SLT (R)
        opcode=`OPC_OP;     funct3=`F3_SLT;     funct7b5=0; #1;
        chk(3,  ctrl, pack(1, 0,0, `ALU_SLT,  `IMM_I, 0,0, `WB_ALU, 0,0,0));
        // SRA (R)
        opcode=`OPC_OP;     funct3=`F3_SRL_SRA; funct7b5=1; #1;
        chk(4,  ctrl, pack(1, 0,0, `ALU_SRA,  `IMM_I, 0,0, `WB_ALU, 0,0,0));

        // ADDI (OP-IMM)
        opcode=`OPC_OP_IMM; funct3=`F3_ADD_SUB; funct7b5=0; #1;
        chk(5,  ctrl, pack(1, 0,1, `ALU_ADD,  `IMM_I, 0,0, `WB_ALU, 0,0,0));
        // ADDI cu funct7b5=1 -> tot ADD (nu exista SUBI)
        opcode=`OPC_OP_IMM; funct3=`F3_ADD_SUB; funct7b5=1; #1;
        chk(6,  ctrl, pack(1, 0,1, `ALU_ADD,  `IMM_I, 0,0, `WB_ALU, 0,0,0));
        // SRAI (OP-IMM)
        opcode=`OPC_OP_IMM; funct3=`F3_SRL_SRA; funct7b5=1; #1;
        chk(7,  ctrl, pack(1, 0,1, `ALU_SRA,  `IMM_I, 0,0, `WB_ALU, 0,0,0));

        // LW (LOAD)
        opcode=`OPC_LOAD;   funct3=`F3_LW;      funct7b5=0; #1;
        chk(8,  ctrl, pack(1, 0,1, `ALU_ADD,  `IMM_I, 1,0, `WB_MEM, 0,0,0));
        // SW (STORE)
        opcode=`OPC_STORE;  funct3=`F3_SW;      funct7b5=0; #1;
        chk(9,  ctrl, pack(0, 0,1, `ALU_ADD,  `IMM_S, 0,1, `WB_ALU, 0,0,0));

        // BEQ (BRANCH)
        opcode=`OPC_BRANCH; funct3=`F3_BEQ;     funct7b5=0; #1;
        chk(10, ctrl, pack(0, 0,0, `ALU_ADD,  `IMM_B, 0,0, `WB_ALU, 1,0,0));

        // JAL
        opcode=`OPC_JAL;    funct3=0;           funct7b5=0; #1;
        chk(11, ctrl, pack(1, 0,0, `ALU_ADD,  `IMM_J, 0,0, `WB_PC4, 0,1,0));
        // JALR
        opcode=`OPC_JALR;   funct3=0;           funct7b5=0; #1;
        chk(12, ctrl, pack(1, 0,1, `ALU_ADD,  `IMM_I, 0,0, `WB_PC4, 0,1,1));

        // LUI
        opcode=`OPC_LUI;    funct3=0;           funct7b5=0; #1;
        chk(13, ctrl, pack(1, 0,1, `ALU_COPY_B,`IMM_U, 0,0, `WB_ALU, 0,0,0));
        // AUIPC
        opcode=`OPC_AUIPC;  funct3=0;           funct7b5=0; #1;
        chk(14, ctrl, pack(1, 1,1, `ALU_ADD,  `IMM_U, 0,0, `WB_ALU, 0,0,0));

        // opcode ilegal -> NOP, niciun efect (rw=0, mw=0)
        opcode=7'b0000000;  funct3=0;           funct7b5=0; #1;
        chk(15, ctrl, pack(0, 0,0, `ALU_ADD,  `IMM_I, 0,0, `WB_ALU, 0,0,0));

        if (errors==0) $display("[CONTROL] >>> PASS <<< (toate instructiunile decodate corect)");
        else           $display("[CONTROL] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
