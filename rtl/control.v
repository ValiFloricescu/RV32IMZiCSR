`timescale 1ns / 1ps
`include "riscv_defs.vh"

module control (
    input  wire [6:0]            opcode,
    input  wire [2:0]            funct3,
    input  wire                  funct7b5,    // instr[30]: distinge SUB/SRA
    input  wire                  funct7b0,    // instr[25]: distinge extensia M
    input  wire [11:0]           funct12,     // instr[31:20]: ECALL/EBREAK/MRET

    output reg                   reg_write,    // scriere in regfile
    output reg                   alu_a_src,    // 0=rs1, 1=PC      (AUIPC)
    output reg                   alu_b_src,    // 0=rs2, 1=immediate
    output reg  [`ALU_OP_W-1:0]  alu_op,
    output reg  [`IMM_SEL_W-1:0] imm_sel,
    output reg                   mem_read,
    output reg                   mem_write,
    output reg  [`WB_SEL_W-1:0]  wb_sel,       // sursa de writeback
    output reg                   branch,       // branch conditionat
    output reg                   jump,         // salt neconditionat (jal/jalr)
    output reg                   jalr,         // jalr: tinta = rs1+imm
    output reg                   is_muldiv,    // extensia M (rezultat din unitatea muldiv)
    output reg                   is_csr,       // instructiune CSR (Zicsr)
    output reg                   sys_ecall,    // ECALL  -> trap
    output reg                   sys_ebreak,   // EBREAK -> trap
    output reg                   sys_mret      // MRET   -> revenire din trap
);

    // --- decodarea operatiei ALU pentru R-type / OP-IMM ---
    reg [`ALU_OP_W-1:0] alu_arith;
    always @(*) begin
        case (funct3)
            `F3_ADD_SUB: alu_arith = funct7b5 ? `ALU_SUB : `ALU_ADD;
            `F3_SLL    : alu_arith = `ALU_SLL;
            `F3_SLT    : alu_arith = `ALU_SLT;
            `F3_SLTU   : alu_arith = `ALU_SLTU;
            `F3_XOR    : alu_arith = `ALU_XOR;
            `F3_SRL_SRA: alu_arith = funct7b5 ? `ALU_SRA : `ALU_SRL;
            `F3_OR     : alu_arith = `ALU_OR;
            `F3_AND    : alu_arith = `ALU_AND;
            default    : alu_arith = `ALU_ADD;
        endcase
    end

    always @(*) begin
        // ---- valori implicite (NOP sigur: nu scrie nimic) ----
        reg_write = 1'b0;
        alu_a_src = 1'b0;
        alu_b_src = 1'b0;
        alu_op    = `ALU_ADD;
        imm_sel   = `IMM_I;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = `WB_ALU;
        branch    = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;
        is_muldiv = 1'b0;
        is_csr    = 1'b0;
        sys_ecall = 1'b0;
        sys_ebreak= 1'b0;
        sys_mret  = 1'b0;

        case (opcode)
            // ---- R-type: rd = rs1 op rs2 (sau extensia M) ----
            `OPC_OP: begin
                reg_write = 1'b1;
                if (funct7b0) begin
                    is_muldiv = 1'b1;
                end else begin
                    alu_op = alu_arith;           // include SUB/SRA prin funct7b5
                end
            end

            // ---- OP-IMM: rd = rs1 op imm ----
            `OPC_OP_IMM: begin
                reg_write = 1'b1;
                alu_b_src = 1'b1;
                imm_sel   = `IMM_I;
                alu_op    = (funct3 == `F3_ADD_SUB) ? `ALU_ADD : alu_arith;
            end

            // ---- LOAD: rd = MEM[rs1 + imm] ----
            `OPC_LOAD: begin
                reg_write = 1'b1;
                alu_b_src = 1'b1;
                imm_sel   = `IMM_I;
                alu_op    = `ALU_ADD;
                mem_read  = 1'b1;
                wb_sel    = `WB_MEM;
            end

            // ---- STORE: MEM[rs1 + imm] = rs2 ----
            `OPC_STORE: begin
                alu_b_src = 1'b1;
                imm_sel   = `IMM_S;
                alu_op    = `ALU_ADD;
                mem_write = 1'b1;
            end

            // ---- BRANCH: decizia o ia comparatorul (foloseste funct3) ----
            `OPC_BRANCH: begin
                branch    = 1'b1;
                imm_sel   = `IMM_B;
            end

            // ---- JAL: rd = PC+4 ; PC = PC + imm ----
            `OPC_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                imm_sel   = `IMM_J;
                wb_sel    = `WB_PC4;
            end

            // ---- JALR: rd = PC+4 ; PC = (rs1 + imm) & ~1 ----
            `OPC_JALR: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;
                alu_b_src = 1'b1;
                imm_sel   = `IMM_I;
                wb_sel    = `WB_PC4;
            end

            // ---- LUI: rd = imm (trecut prin ALU cu COPY_B) ----
            `OPC_LUI: begin
                reg_write = 1'b1;
                alu_b_src = 1'b1;
                imm_sel   = `IMM_U;
                alu_op    = `ALU_COPY_B;
                wb_sel    = `WB_ALU;
            end

            // ---- AUIPC: rd = PC + imm ----
            `OPC_AUIPC: begin
                reg_write = 1'b1;
                alu_a_src = 1'b1;
                alu_b_src = 1'b1;
                imm_sel   = `IMM_U;
                alu_op    = `ALU_ADD;
                wb_sel    = `WB_ALU;
            end

            // ---- SYSTEM: CSR (Zicsr) sau ECALL/EBREAK/MRET ----
            `OPC_SYSTEM: begin
                if (funct3 == `F3_PRIV) begin
                    case (funct12)
                        `SYS_ECALL : sys_ecall  = 1'b1;
                        `SYS_EBREAK: sys_ebreak = 1'b1;
                        `SYS_MRET  : sys_mret   = 1'b1;
                        default    : ;
                    endcase
                end else begin
                    is_csr    = 1'b1;
                    reg_write = 1'b1;
                    wb_sel    = `WB_ALU;
                end
            end

            default: ;
        endcase
    end

endmodule
