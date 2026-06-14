`timescale 1ns / 1ps
`include "riscv_defs.vh"

module riscv_core_sc (
    input  wire        clk,
    input  wire        rst_n,

    // --- port memorie instructiuni (citire asincrona) ---
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // --- port memorie date (citire asincrona, scriere sincrona) ---
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    output wire        dmem_we,
    input  wire [31:0] dmem_rdata
);

    // ============================================================
    //  1. PC + FETCH
    // ============================================================
    reg  [31:0] pc;
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] next_pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= `RESET_PC;
        else        pc <= next_pc;
    end

    assign imem_addr = pc;
    wire [31:0] instr = imem_rdata;

    // ============================================================
    //  2. DECODE
    // ============================================================
    wire [6:0] opcode   = `OPCODE(instr);
    wire [4:0] rd_addr  = `RD(instr);
    wire [4:0] rs1_addr = `RS1(instr);
    wire [4:0] rs2_addr = `RS2(instr);
    wire [2:0] funct3   = `FUNCT3(instr);
    wire       funct7b5 = instr[30];

    wire                  reg_write, alu_a_src, alu_b_src;
    wire [`ALU_OP_W-1:0]  alu_op;
    wire [`IMM_SEL_W-1:0] imm_sel;
    wire                  mem_read, mem_write;
    wire [`WB_SEL_W-1:0]  wb_sel;
    wire                  branch, jump, jalr;

    control u_ctrl (
        .opcode(opcode), .funct3(funct3), .funct7b5(funct7b5), .funct7b0(instr[25]),
        .funct12(instr[31:20]),
        .reg_write(reg_write), .alu_a_src(alu_a_src), .alu_b_src(alu_b_src),
        .alu_op(alu_op), .imm_sel(imm_sel),
        .mem_read(mem_read), .mem_write(mem_write), .wb_sel(wb_sel),
        .branch(branch), .jump(jump), .jalr(jalr)
    );

    // ============================================================
    //  3. REGFILE + IMMEDIATE
    // ============================================================
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] wb_data;

    regfile u_rf (
        .clk(clk),
        .we(reg_write), .rd_addr(rd_addr), .rd_data(wb_data),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    wire [31:0] imm;
    imm_gen u_imm (.instr(instr), .imm_sel(imm_sel), .imm(imm));

    // ============================================================
    //  4. EXECUTE (ALU + comparator de branch)
    // ============================================================
    wire [31:0] alu_a = alu_a_src ? pc  : rs1_data;   // AUIPC foloseste PC
    wire [31:0] alu_b = alu_b_src ? imm : rs2_data;   // immediate vs rs2
    wire [31:0] alu_result;
    wire        alu_zero;

    alu u_alu (.a(alu_a), .b(alu_b), .alu_op(alu_op),
               .result(alu_result), .zero(alu_zero));

    reg branch_cond;
    always @(*) begin
        case (funct3)
            `F3_BEQ : branch_cond = (rs1_data == rs2_data);
            `F3_BNE : branch_cond = (rs1_data != rs2_data);
            `F3_BLT : branch_cond = ($signed(rs1_data) <  $signed(rs2_data));
            `F3_BGE : branch_cond = ($signed(rs1_data) >= $signed(rs2_data));
            `F3_BLTU: branch_cond = (rs1_data <  rs2_data);
            `F3_BGEU: branch_cond = (rs1_data >= rs2_data);
            default : branch_cond = 1'b0;
        endcase
    end
    wire branch_taken = branch & branch_cond;

    // ============================================================
    //  5. MEMORY (load/store unit cu aliniere si extindere)
    // ============================================================
    wire [31:0] mem_addr = alu_result;     // adresa = rs1 + imm
    wire [1:0]  off       = mem_addr[1:0];  // offset in cuvant

    reg  [31:0] store_data;
    reg  [3:0]  store_strb;
    always @(*) begin
        store_data = rs2_data;
        store_strb = 4'b0000;
        case (funct3)
            `F3_SB: begin
                store_data = {24'b0, rs2_data[7:0]}  << (8*off);
                store_strb = 4'b0001 << off;
            end
            `F3_SH: begin
                store_data = {16'b0, rs2_data[15:0]} << (8*off);
                store_strb = 4'b0011 << off;
            end
            `F3_SW: begin
                store_data = rs2_data;
                store_strb = 4'b1111;
            end
            default: begin
                store_data = rs2_data;
                store_strb = 4'b0000;
            end
        endcase
    end

    assign dmem_addr  = mem_addr;
    assign dmem_wdata = store_data;
    assign dmem_we    = mem_write;
    assign dmem_wstrb = mem_write ? store_strb : 4'b0000;

    wire [7:0]  ld_byte = dmem_rdata[8*off  +: 8];
    wire [15:0] ld_half = dmem_rdata[8*off  +: 16];
    reg  [31:0] load_data;
    always @(*) begin
        case (funct3)
            `F3_LB : load_data = {{24{ld_byte[7]}},  ld_byte};
            `F3_LH : load_data = {{16{ld_half[15]}}, ld_half};
            `F3_LW : load_data = dmem_rdata;
            `F3_LBU: load_data = {24'b0, ld_byte};
            `F3_LHU: load_data = {16'b0, ld_half};
            default: load_data = dmem_rdata;
        endcase
    end

    // ============================================================
    //  6. WRITE-BACK
    // ============================================================
    reg [31:0] wb_mux;
    always @(*) begin
        case (wb_sel)
            `WB_ALU: wb_mux = alu_result;
            `WB_MEM: wb_mux = load_data;
            `WB_PC4: wb_mux = pc_plus4;
            default: wb_mux = alu_result;
        endcase
    end
    assign wb_data = wb_mux;

    // ============================================================
    //  7. NEXT PC
    // ============================================================
    wire [31:0] pc_target   = pc + imm;                    // branch / jal (PC-relativ)
    wire [31:0] jalr_target = (rs1_data + imm) & ~32'b1;   // jalr (bitul 0 fortat la 0)

    assign next_pc = (jump && jalr) ? jalr_target :
                     (jump)         ? pc_target   :   // jal
                     (branch_taken) ? pc_target   :   // branch luat
                                      pc_plus4;

endmodule