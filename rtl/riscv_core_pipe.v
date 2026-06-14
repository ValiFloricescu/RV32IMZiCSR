`timescale 1ns / 1ps
`include "riscv_defs.vh"

module riscv_core_pipe #(
    parameter [31:0] RESET_PC = `RESET_PC   // vector de reset; implicit din riscv_defs.vh
) (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    output wire        dmem_we,
    input  wire [31:0] dmem_rdata
);

    // ============================================================
    //  DECLARATII (registri de stare)
    // ============================================================
    reg  [31:0] pc;
    reg  [31:0] ifid_pc, ifid_pc4, ifid_instr;
    // ID/EX
    reg                  idex_reg_write, idex_alu_a_src, idex_alu_b_src;
    reg [`ALU_OP_W-1:0]  idex_alu_op;
    reg                  idex_mem_read, idex_mem_write;
    reg [`WB_SEL_W-1:0]  idex_wb_sel;
    reg                  idex_branch, idex_jump, idex_jalr, idex_is_muldiv;
    reg                  idex_is_csr, idex_sys_ecall, idex_sys_ebreak, idex_sys_mret;
    reg [11:0]           idex_csr_addr;
    reg [31:0]           idex_rs1_data, idex_rs2_data, idex_imm, idex_pc, idex_pc4;
    reg [4:0]            idex_rd, idex_rs1, idex_rs2;
    reg [2:0]            idex_funct3;
    // EX/MEM
    reg                  exmem_reg_write, exmem_mem_read, exmem_mem_write;
    reg [`WB_SEL_W-1:0]  exmem_wb_sel;
    reg [31:0]           exmem_alu_result, exmem_rs2_data, exmem_pc4;
    reg [4:0]            exmem_rd;
    reg [2:0]            exmem_funct3;
    // MEM/WB
    reg [`WB_SEL_W-1:0]  memwb_wb_sel;
    reg [31:0]           memwb_alu_result, memwb_load_data, memwb_pc4;
    reg                  memwb_reg_write_r;
    reg [4:0]            memwb_rd_r;

    // semnale partajate
    wire [31:0] wb_data;
    wire        memwb_reg_write;
    wire [4:0]  memwb_rd;
    wire        load_use_stall;
    wire        ex_redirect;
    wire [31:0] ex_redirect_pc;
    wire [31:0] mul_result;
    wire        mul_busy, mul_done;

    wire mul_stall   = idex_is_muldiv & ~mul_done;
    
    wire stall_front = load_use_stall | mul_stall;

    // ============================================================
    //  ETAPA IF
    // ============================================================
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] next_pc  = ex_redirect ? ex_redirect_pc : pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)            pc <= RESET_PC;
        else if (!stall_front) pc <= next_pc;
    end

    assign imem_addr = pc;
    wire [31:0] if_instr = imem_rdata;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ifid_pc <= 32'b0; ifid_pc4 <= 32'b0; ifid_instr <= `RV_NOP;
        end else if (stall_front) begin
            // hold (load-use sau muldiv)
        end else if (ex_redirect) begin
            ifid_pc <= 32'b0; ifid_pc4 <= 32'b0; ifid_instr <= `RV_NOP;  // squash
        end else begin
            ifid_pc <= pc; ifid_pc4 <= pc_plus4; ifid_instr <= if_instr;
        end
    end

    // ============================================================
    //  ETAPA ID
    // ============================================================
    wire [6:0] id_opcode   = `OPCODE(ifid_instr);
    wire [4:0] id_rd       = `RD(ifid_instr);
    wire [4:0] id_rs1      = `RS1(ifid_instr);
    wire [4:0] id_rs2      = `RS2(ifid_instr);
    wire [2:0] id_funct3   = `FUNCT3(ifid_instr);
    wire       id_funct7b5 = ifid_instr[30];
    wire       id_funct7b0 = ifid_instr[25];

    wire                  id_reg_write, id_alu_a_src, id_alu_b_src;
    wire [`ALU_OP_W-1:0]  id_alu_op;
    wire [`IMM_SEL_W-1:0] id_imm_sel;
    wire                  id_mem_read, id_mem_write;
    wire [`WB_SEL_W-1:0]  id_wb_sel;
    wire                  id_branch, id_jump, id_jalr, id_is_muldiv;
    wire                  id_is_csr, id_sys_ecall, id_sys_ebreak, id_sys_mret;

    control u_ctrl (
        .opcode(id_opcode), .funct3(id_funct3),
        .funct7b5(id_funct7b5), .funct7b0(id_funct7b0),
        .funct12(ifid_instr[31:20]),
        .reg_write(id_reg_write), .alu_a_src(id_alu_a_src), .alu_b_src(id_alu_b_src),
        .alu_op(id_alu_op), .imm_sel(id_imm_sel),
        .mem_read(id_mem_read), .mem_write(id_mem_write), .wb_sel(id_wb_sel),
        .branch(id_branch), .jump(id_jump), .jalr(id_jalr), .is_muldiv(id_is_muldiv),
        .is_csr(id_is_csr), .sys_ecall(id_sys_ecall),
        .sys_ebreak(id_sys_ebreak), .sys_mret(id_sys_mret)
    );

    wire [31:0] id_rs1_data, id_rs2_data;
    regfile u_rf (
        .clk(clk),
        .we(memwb_reg_write), .rd_addr(memwb_rd), .rd_data(wb_data),
        .rs1_addr(id_rs1), .rs2_addr(id_rs2),
        .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );

    wire [31:0] id_imm;
    imm_gen u_imm (.instr(ifid_instr), .imm_sel(id_imm_sel), .imm(id_imm));

    // forward WB->ID (register file "write-first")
    wire wb2id_rs1 = memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == id_rs1);
    wire wb2id_rs2 = memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == id_rs2);
    wire [31:0] id_rs1_fwd = wb2id_rs1 ? wb_data : id_rs1_data;
    wire [31:0] id_rs2_fwd = wb2id_rs2 ? wb_data : id_rs2_data;

    hazard u_hazard (
        .idex_mem_read(idex_mem_read), .idex_rd(idex_rd),
        .ifid_rs1(id_rs1), .ifid_rs2(id_rs2), .stall(load_use_stall)
    );

    // registru ID/EX
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idex_reg_write <= 1'b0; idex_mem_read <= 1'b0; idex_mem_write <= 1'b0;
            idex_branch <= 1'b0; idex_jump <= 1'b0; idex_jalr <= 1'b0; idex_is_muldiv <= 1'b0;
            idex_alu_a_src <= 1'b0; idex_alu_b_src <= 1'b0;
            idex_alu_op <= `ALU_ADD; idex_wb_sel <= `WB_ALU;
            idex_rs1_data <= 32'b0; idex_rs2_data <= 32'b0; idex_imm <= 32'b0;
            idex_pc <= 32'b0; idex_pc4 <= 32'b0;
            idex_rd <= 5'b0; idex_rs1 <= 5'b0; idex_rs2 <= 5'b0; idex_funct3 <= 3'b0;
            idex_is_csr <= 1'b0; idex_sys_ecall <= 1'b0; idex_sys_ebreak <= 1'b0; idex_sys_mret <= 1'b0; idex_csr_addr <= 12'b0;
        end else if (mul_stall) begin
        end else if (load_use_stall || ex_redirect) begin
            idex_reg_write <= 1'b0; idex_mem_read <= 1'b0; idex_mem_write <= 1'b0;
            idex_branch <= 1'b0; idex_jump <= 1'b0; idex_jalr <= 1'b0; idex_is_muldiv <= 1'b0;
            idex_alu_a_src <= 1'b0; idex_alu_b_src <= 1'b0;
            idex_alu_op <= `ALU_ADD; idex_wb_sel <= `WB_ALU;
            idex_rs1_data <= 32'b0; idex_rs2_data <= 32'b0; idex_imm <= 32'b0;
            idex_pc <= 32'b0; idex_pc4 <= 32'b0;
            idex_rd <= 5'b0; idex_rs1 <= 5'b0; idex_rs2 <= 5'b0; idex_funct3 <= 3'b0;
            idex_is_csr <= 1'b0; idex_sys_ecall <= 1'b0; idex_sys_ebreak <= 1'b0; idex_sys_mret <= 1'b0; idex_csr_addr <= 12'b0;
        end else begin
            idex_reg_write <= id_reg_write; idex_mem_read <= id_mem_read;
            idex_mem_write <= id_mem_write; idex_branch <= id_branch;
            idex_jump <= id_jump; idex_jalr <= id_jalr; idex_is_muldiv <= id_is_muldiv;
            idex_alu_a_src <= id_alu_a_src; idex_alu_b_src <= id_alu_b_src;
            idex_alu_op <= id_alu_op; idex_wb_sel <= id_wb_sel;
            idex_rs1_data <= id_rs1_fwd; idex_rs2_data <= id_rs2_fwd;
            idex_imm <= id_imm; idex_pc <= ifid_pc; idex_pc4 <= ifid_pc4;
            idex_rd <= id_rd; idex_rs1 <= id_rs1; idex_rs2 <= id_rs2;
            idex_funct3 <= id_funct3;
            idex_is_csr <= id_is_csr; idex_sys_ecall <= id_sys_ecall; idex_sys_ebreak <= id_sys_ebreak; idex_sys_mret <= id_sys_mret; idex_csr_addr <= ifid_instr[31:20];
        end
    end

    // ============================================================
    //  ETAPA EX
    // ============================================================
    wire [1:0] forward_a, forward_b;
    forwarding u_fwd (
        .idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
        .exmem_rd(exmem_rd), .exmem_reg_write(exmem_reg_write),
        .memwb_rd(memwb_rd), .memwb_reg_write(memwb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    wire [31:0] exmem_fwd_val = (exmem_wb_sel == `WB_PC4) ? exmem_pc4
                                                          : exmem_alu_result;

    reg [31:0] ex_rs1_fwd, ex_rs2_fwd;
    always @(*) begin
        case (forward_a)
            `FWD_EXMEM: ex_rs1_fwd = exmem_fwd_val;
            `FWD_MEMWB: ex_rs1_fwd = wb_data;
            default:    ex_rs1_fwd = idex_rs1_data;
        endcase
        case (forward_b)
            `FWD_EXMEM: ex_rs2_fwd = exmem_fwd_val;
            `FWD_MEMWB: ex_rs2_fwd = wb_data;
            default:    ex_rs2_fwd = idex_rs2_data;
        endcase
    end

    wire [31:0] ex_alu_a = idex_alu_a_src ? idex_pc  : ex_rs1_fwd;
    wire [31:0] ex_alu_b = idex_alu_b_src ? idex_imm : ex_rs2_fwd;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;

    alu u_alu (.a(ex_alu_a), .b(ex_alu_b), .alu_op(idex_alu_op),
               .result(ex_alu_result), .zero(ex_alu_zero));

    // unitatea de inmultire/impartire (extensia M)
    muldiv u_muldiv (
        .clk(clk), .rst_n(rst_n),
        .start(idex_is_muldiv), .op(idex_funct3),
        .a(ex_rs1_fwd), .b(ex_rs2_fwd),
        .result(mul_result), .busy(mul_busy), .done(mul_done)
    );

    // ============================================================
    //  CSR (Zicsr) + trap, rezolvate in EX
    // ============================================================
    wire [31:0] csr_rdata, csr_mtvec, csr_mepc;
    wire        csr_addr_valid;

    // sursa pentru scriere: registru (rs1) sau imediat (zimm = campul rs1)
    wire [31:0] csr_src   = idex_funct3[2] ? {27'b0, idex_rs1} : ex_rs1_fwd;
    wire [1:0]  csr_op    = idex_funct3[1:0];           // 01=RW 10=RS 11=RC
    wire [31:0] csr_wval  = (csr_op == 2'b01) ? csr_src
                          : (csr_op == 2'b10) ? (csr_rdata |  csr_src)
                          :                     (csr_rdata & ~csr_src);

    wire        csr_wr    = idex_is_csr & ((csr_op == 2'b01) | (idex_rs1 != 5'b0));

    // detectare trap / mret (gate cu ~mul_stall: o singura instr in EX)
    wire        csr_illegal = idex_is_csr & ~csr_addr_valid;
    wire        ex_trap = (idex_sys_ecall | idex_sys_ebreak | csr_illegal) & ~mul_stall;
    wire        ex_mret =  idex_sys_mret & ~mul_stall;
    wire [31:0] ex_trap_cause = idex_sys_ecall  ? `CAUSE_ECALL_M
                              : idex_sys_ebreak  ? `CAUSE_BREAKPOINT
                              :                    `CAUSE_ILLEGAL;

    csr u_csr (
        .clk(clk), .rst_n(rst_n),
        .rd_en(idex_is_csr), .wr_en(csr_wr & ~ex_trap),
        .addr(idex_csr_addr), .wdata(csr_wval),
        .rdata(csr_rdata), .addr_valid(csr_addr_valid),
        .trap_en(ex_trap), .trap_cause(ex_trap_cause),
        .trap_epc(idex_pc), .trap_val(32'b0), .mret_en(ex_mret),
        .mtvec_o(csr_mtvec), .mepc_o(csr_mepc)
    );

    wire [31:0] ex_result = idex_is_csr    ? csr_rdata
                          : idex_is_muldiv ? mul_result
                          :                  ex_alu_result;

    reg ex_branch_cond;
    always @(*) begin
        case (idex_funct3)
            `F3_BEQ : ex_branch_cond = (ex_rs1_fwd == ex_rs2_fwd);
            `F3_BNE : ex_branch_cond = (ex_rs1_fwd != ex_rs2_fwd);
            `F3_BLT : ex_branch_cond = ($signed(ex_rs1_fwd) <  $signed(ex_rs2_fwd));
            `F3_BGE : ex_branch_cond = ($signed(ex_rs1_fwd) >= $signed(ex_rs2_fwd));
            `F3_BLTU: ex_branch_cond = (ex_rs1_fwd <  ex_rs2_fwd);
            `F3_BGEU: ex_branch_cond = (ex_rs1_fwd >= ex_rs2_fwd);
            default : ex_branch_cond = 1'b0;
        endcase
    end

    wire        ex_branch_taken = idex_branch & ex_branch_cond;
    wire [31:0] ex_pc_target    = idex_pc + idex_imm;
    wire [31:0] ex_jalr_target  = (ex_rs1_fwd + idex_imm) & ~32'b1;

    assign ex_redirect    = (ex_branch_taken | idex_jump | ex_trap | ex_mret) & ~mul_stall;
    assign ex_redirect_pc = ex_trap ? csr_mtvec
                          : ex_mret ? csr_mepc
                          : (idex_jump && idex_jalr) ? ex_jalr_target
                          :                            ex_pc_target;

    // registru EX/MEM (bula la mul_stall sau cand instructiunea ia trap)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exmem_reg_write <= 1'b0; exmem_mem_read <= 1'b0; exmem_mem_write <= 1'b0;
            exmem_wb_sel <= `WB_ALU; exmem_alu_result <= 32'b0; exmem_rs2_data <= 32'b0;
            exmem_pc4 <= 32'b0; exmem_rd <= 5'b0; exmem_funct3 <= 3'b0;
        end else if (mul_stall || ex_trap) begin
            exmem_reg_write <= 1'b0; exmem_mem_read <= 1'b0; exmem_mem_write <= 1'b0;
            exmem_wb_sel <= `WB_ALU; exmem_alu_result <= 32'b0; exmem_rs2_data <= 32'b0;
            exmem_pc4 <= 32'b0; exmem_rd <= 5'b0; exmem_funct3 <= 3'b0;
        end else begin
            exmem_reg_write <= idex_reg_write; exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write; exmem_wb_sel <= idex_wb_sel;
            exmem_alu_result <= ex_result;        // ALU sau muldiv
            exmem_rs2_data <= ex_rs2_fwd;
            exmem_pc4 <= idex_pc4; exmem_rd <= idex_rd; exmem_funct3 <= idex_funct3;
        end
    end

    // ============================================================
    //  ETAPA MEM
    // ============================================================
    wire [1:0] mem_off = exmem_alu_result[1:0];

    reg  [31:0] mem_store_data;
    reg  [3:0]  mem_store_strb;
    always @(*) begin
        case (exmem_funct3)
            `F3_SB: begin
                mem_store_data = {24'b0, exmem_rs2_data[7:0]}  << (8*mem_off);
                mem_store_strb = 4'b0001 << mem_off;
            end
            `F3_SH: begin
                mem_store_data = {16'b0, exmem_rs2_data[15:0]} << (8*mem_off);
                mem_store_strb = 4'b0011 << mem_off;
            end
            `F3_SW: begin
                mem_store_data = exmem_rs2_data;
                mem_store_strb = 4'b1111;
            end
            default: begin
                mem_store_data = exmem_rs2_data;
                mem_store_strb = 4'b0000;
            end
        endcase
    end

    assign dmem_addr  = exmem_alu_result;
    assign dmem_wdata = mem_store_data;
    assign dmem_we    = exmem_mem_write;
    assign dmem_wstrb = exmem_mem_write ? mem_store_strb : 4'b0000;

    wire [7:0]  mem_ld_byte = dmem_rdata[8*mem_off +: 8];
    wire [15:0] mem_ld_half = dmem_rdata[8*mem_off +: 16];
    reg  [31:0] mem_load_data;
    always @(*) begin
        case (exmem_funct3)
            `F3_LB : mem_load_data = {{24{mem_ld_byte[7]}},  mem_ld_byte};
            `F3_LH : mem_load_data = {{16{mem_ld_half[15]}}, mem_ld_half};
            `F3_LW : mem_load_data = dmem_rdata;
            `F3_LBU: mem_load_data = {24'b0, mem_ld_byte};
            `F3_LHU: mem_load_data = {16'b0, mem_ld_half};
            default: mem_load_data = dmem_rdata;
        endcase
    end

    // registru MEM/WB
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            memwb_reg_write_r <= 1'b0; memwb_wb_sel <= `WB_ALU;
            memwb_alu_result <= 32'b0; memwb_load_data <= 32'b0; memwb_pc4 <= 32'b0;
            memwb_rd_r <= 5'b0;
        end else begin
            memwb_reg_write_r <= exmem_reg_write; memwb_wb_sel <= exmem_wb_sel;
            memwb_alu_result <= exmem_alu_result; memwb_load_data <= mem_load_data;
            memwb_pc4 <= exmem_pc4; memwb_rd_r <= exmem_rd;
        end
    end

    assign memwb_reg_write = memwb_reg_write_r;
    assign memwb_rd        = memwb_rd_r;

    // ============================================================
    //  ETAPA WB
    // ============================================================
    reg [31:0] wb_mux;
    always @(*) begin
        case (memwb_wb_sel)
            `WB_ALU: wb_mux = memwb_alu_result;
            `WB_MEM: wb_mux = memwb_load_data;
            `WB_PC4: wb_mux = memwb_pc4;
            default: wb_mux = memwb_alu_result;
        endcase
    end
    assign wb_data = wb_mux;

endmodule