`ifndef RISCV_DEFS_VH
`define RISCV_DEFS_VH

// ------------------------------------------------------------
//  Parametri generali
// ------------------------------------------------------------
`define XLEN         32                 // latimea cuvantului
`define RV_NOP       32'h0000_0013      // addi x0, x0, 0  (bula in pipeline)
`define RESET_PC     32'h0000_0000      // adresa de start dupa reset

// ------------------------------------------------------------
//  Extractoare de campuri din instructiune (i = vector 32-bit)
//    Formate RISC-V:
//      R: funct7 | rs2 | rs1 | funct3 | rd | opcode
//      I: imm[11:0]       | rs1 | funct3 | rd | opcode
//      S: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
//      B: imm[12|10:5]|rs2|rs1|funct3| imm[4:1|11] | opcode
//      U: imm[31:12]                  | rd | opcode
//      J: imm[20|10:1|11|19:12]       | rd | opcode
// ------------------------------------------------------------
`define OPCODE(i)    (i[6:0])
`define RD(i)        (i[11:7])
`define RS1(i)       (i[19:15])
`define RS2(i)       (i[24:20])
`define FUNCT3(i)    (i[14:12])
`define FUNCT7(i)    (i[31:25])

// ------------------------------------------------------------
//  Opcode-uri (bitii [6:0])
// ------------------------------------------------------------
`define OPC_LUI      7'b0110111         // U  - load upper immediate
`define OPC_AUIPC    7'b0010111         // U  - add upper imm to PC
`define OPC_JAL      7'b1101111         // J  - jump and link
`define OPC_JALR     7'b1100111         // I  - jump and link register
`define OPC_BRANCH   7'b1100011         // B  - branch conditionat
`define OPC_LOAD     7'b0000011         // I  - load din memorie
`define OPC_STORE    7'b0100011         // S  - store in memorie
`define OPC_OP_IMM   7'b0010011         // I  - ALU cu immediate
`define OPC_OP       7'b0110011         // R  - ALU cu registre (+ extensia M)
`define OPC_MISC_MEM 7'b0001111         // I  - FENCE
`define OPC_SYSTEM   7'b1110011         // I  - ECALL/EBREAK/CSR

// ------------------------------------------------------------
//  funct3 pentru OP / OP-IMM (aritmetica/logica)
//    SUB vs ADD si SRA vs SRL se disting prin bitul funct7[5] (=i[30])
// ------------------------------------------------------------
`define F3_ADD_SUB   3'b000             // ADD/ADDI ; SUB (funct7[5]=1)
`define F3_SLL       3'b001             // shift left logic
`define F3_SLT       3'b010             // set less than (cu semn)
`define F3_SLTU      3'b011             // set less than (fara semn)
`define F3_XOR       3'b100
`define F3_SRL_SRA   3'b101             // SRL ; SRA (funct7[5]=1)
`define F3_OR        3'b110
`define F3_AND       3'b111

// ------------------------------------------------------------
//  funct3 pentru BRANCH
// ------------------------------------------------------------
`define F3_BEQ       3'b000
`define F3_BNE       3'b001
`define F3_BLT       3'b100
`define F3_BGE       3'b101
`define F3_BLTU      3'b110
`define F3_BGEU      3'b111

// ------------------------------------------------------------
//  funct3 pentru LOAD / STORE (dimensiunea accesului)
// ------------------------------------------------------------
`define F3_LB        3'b000             // load byte (cu semn)
`define F3_LH        3'b001             // load half (cu semn)
`define F3_LW        3'b010             // load word
`define F3_LBU       3'b100             // load byte (fara semn)
`define F3_LHU       3'b101             // load half (fara semn)

`define F3_SB        3'b000             // store byte
`define F3_SH        3'b001             // store half
`define F3_SW        3'b010             // store word

// ------------------------------------------------------------
//  funct7 relevante
// ------------------------------------------------------------
`define F7_BASE      7'b0000000         // ADD, SRL, AND, ...
`define F7_ALT       7'b0100000         // SUB, SRA  (bitul [5]=1)
`define F7_MULDIV    7'b0000001         // extensia M
`define F7_BIT5      30                 // pozitia bitului ALT in instructiune

// ------------------------------------------------------------
//  Extensia M (opcode OPC_OP, funct7 = F7_MULDIV), prin funct3
// ------------------------------------------------------------
`define F3_MUL       3'b000             // produs, 32 bitii inferiori
`define F3_MULH      3'b001             // produs sup., semnat x semnat
`define F3_MULHSU    3'b010             // produs sup., semnat x nesemnat
`define F3_MULHU     3'b011             // produs sup., nesemnat x nesemnat
`define F3_DIV       3'b100             // impartire cu semn
`define F3_DIVU      3'b101             // impartire fara semn
`define F3_REM       3'b110             // rest cu semn
`define F3_REMU      3'b111             // rest fara semn

// ------------------------------------------------------------
//  funct3 pentru SYSTEM (ECALL/EBREAK + CSR)
// ------------------------------------------------------------
`define F3_PRIV      3'b000             // ECALL/EBREAK (dupa funct12)
`define F3_CSRRW     3'b001
`define F3_CSRRS     3'b010
`define F3_CSRRC     3'b011
`define F3_CSRRWI    3'b101
`define F3_CSRRSI    3'b110
`define F3_CSRRCI    3'b111

// ------------------------------------------------------------
//  funct12 (instr[31:20]) pentru SYSTEM cu funct3=000
// ------------------------------------------------------------
`define SYS_ECALL    12'h000
`define SYS_EBREAK   12'h001
`define SYS_MRET     12'h302

// ------------------------------------------------------------
//  Adrese CSR (mod masina) - subset minim pentru Zicsr + trap
// ------------------------------------------------------------
`define CSR_MSTATUS  12'h300
`define CSR_MISA     12'h301
`define CSR_MIE      12'h304
`define CSR_MTVEC    12'h305
`define CSR_MSCRATCH 12'h340
`define CSR_MEPC     12'h341
`define CSR_MCAUSE   12'h342
`define CSR_MTVAL    12'h343
`define CSR_MIP      12'h344
`define CSR_MVENDORID 12'hF11
`define CSR_MARCHID   12'hF12
`define CSR_MIMPID    12'hF13
`define CSR_MHARTID   12'hF14

//  misa pentru RV32IM: MXL=01 (32b) | I (bit8) | M (bit12)
`define MISA_RV32IM  32'h40001100

// ------------------------------------------------------------
//  Cauze de trap (mcause, bitul de interrupt = 0 pentru exceptii)
// ------------------------------------------------------------
`define CAUSE_ILLEGAL    32'd2
`define CAUSE_BREAKPOINT 32'd3
`define CAUSE_ECALL_M    32'd11

// ------------------------------------------------------------
//  Encodarea interna a operatiei ALU (semnal de control, 4 biti)
//    Nu face parte din ISA - e conventia noastra interna.
// ------------------------------------------------------------
`define ALU_OP_W     4
`define ALU_ADD      4'b0000
`define ALU_SUB      4'b0001
`define ALU_SLL      4'b0010
`define ALU_SLT      4'b0011            // set-less-than cu semn
`define ALU_SLTU     4'b0100            // set-less-than fara semn
`define ALU_XOR      4'b0101
`define ALU_SRL      4'b0110
`define ALU_SRA      4'b0111
`define ALU_OR       4'b1000
`define ALU_AND      4'b1001
`define ALU_COPY_B   4'b1010            // trece operandul B (pentru LUI)
`define ALU_NOP      4'b1111            // fara efect (bula)

// ------------------------------------------------------------
//  Selectorul de tip immediate (semnal de control, intern)
//    Spune lui imm_gen din ce format sa extraga immediate-ul.
// ------------------------------------------------------------
`define IMM_SEL_W    3
`define IMM_I        3'd0               // OP-IMM, LOAD, JALR
`define IMM_S        3'd1               // STORE
`define IMM_B        3'd2               // BRANCH
`define IMM_U        3'd3               // LUI, AUIPC
`define IMM_J        3'd4               // JAL

// ------------------------------------------------------------
//  Selectorul sursei de writeback (ce se scrie in registrul rd)
// ------------------------------------------------------------
`define WB_SEL_W     2
`define WB_ALU       2'd0               // rezultatul ALU
`define WB_MEM       2'd1               // data citita din memorie (load)
`define WB_PC4       2'd2               // PC+4 (adresa de retur, jal/jalr)

// ------------------------------------------------------------
//  Coduri pentru unitatea de forwarding (Faza 4)
//    Selecteaza sursa operandului ALU in etapa EX.
// ------------------------------------------------------------
`define FWD_NONE     2'b00              // din ID/EX (register file)
`define FWD_EXMEM    2'b10              // din EX/MEM (instr. precedenta)
`define FWD_MEMWB    2'b01              // din MEM/WB (cu 2 instr. inainte)

`endif  // RISCV_DEFS_VH
