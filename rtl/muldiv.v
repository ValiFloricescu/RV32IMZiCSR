`timescale 1ns / 1ps
`include "riscv_defs.vh"

// muldiv: extensia M.
// - INMULTIRE: un singur inmultitor semnat 33x33, pipeline-at (operanzi
//   inregistrati -> produs inregistrat -> selectie), ca sa fie impachetat in
//   regiitrii interni ai DSP48 si scos de pe calea critica. Acopera MUL/MULH/
//   MULHU/MULHSU prin extinderea de semn aleasa dupa operatie.
// - IMPARTIRE: iterativa, restoring (neschimbata fata de varianta verificata).
module muldiv (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,      // ingheata FSM (tranzactie AXI in curs)
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  op,
    output reg  [31:0] result,
    output wire        busy,
    output wire        done
);

    localparam [2:0] IDLE = 3'd0, MUL1 = 3'd1, MUL2 = 3'd2,
                     CALC = 3'd3, FIN  = 3'd4;
    reg [2:0]  state;

    // ---- registre inmultire (pipeline) ----
    reg signed [32:0] areg, breg;     // operanzi extinsi pe 33 biti, inregistrati
    reg signed [65:0] preg;           // produsul inregistrat (66 biti)
    reg               take_high_q;    // 1 = MULH*, 0 = MUL (jumatatea inferioara)

    // ---- registre impartire ----
    reg [63:0] acc;
    reg [31:0] divisor_q;
    reg [5:0]  cnt;
    reg        neg_q, neg_r;
    reg [2:0]  op_q;

    assign busy = (state == MUL1) || (state == MUL2) || (state == CALC);
    assign done = (state == FIN);

    wire is_mul = (op == `F3_MUL) || (op == `F3_MULH) ||
                  (op == `F3_MULHSU) || (op == `F3_MULHU);
    wire signed_div = (op == `F3_DIV) || (op == `F3_REM);

    // extindere de semn per operatie: a semnat la MUL/MULH/MULHSU; b semnat la MUL/MULH
    wire a_s = (op != `F3_MULHU);
    wire b_s = (op == `F3_MUL) || (op == `F3_MULH);
    wire signed [32:0] a_ext = $signed({a_s & a[31], a});
    wire signed [32:0] b_ext = $signed({b_s & b[31], b});
    wire take_high = (op != `F3_MUL);

    // pregatire impartire (valori absolute, cazuri speciale ISA)
    wire na = signed_div && a[31];
    wire nb = signed_div && b[31];
    wire [31:0] abs_a = na ? (~a + 32'd1) : a;
    wire [31:0] abs_b = nb ? (~b + 32'd1) : b;
    wire div_zero = (b == 32'd0);
    wire overflow = signed_div && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);

    // pas impartire (restoring, 1 bit/ciclu)
    wire [63:0] acc_sh = acc << 1;
    wire [31:0] rem_hi = acc_sh[63:32];
    wire [32:0] diff   = {1'b0, rem_hi} - {1'b0, divisor_q};
    wire        ge     = ~diff[32];
    wire [63:0] acc_nx = ge ? {diff[31:0], acc_sh[31:0] | 32'h1} : acc_sh;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; result <= 32'b0;
            areg <= 33'b0; breg <= 33'b0; preg <= 66'b0; take_high_q <= 1'b0;
            acc <= 64'b0; divisor_q <= 32'b0; cnt <= 6'b0;
            neg_q <= 1'b0; neg_r <= 1'b0; op_q <= 3'b0;
        end else if (stall) begin
            // tranzactie AXI in curs: inghetam FSM-ul (nu avansam pasii)
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        op_q  <= op;
                        neg_q <= (na ^ nb);
                        neg_r <= na;
                        if (is_mul) begin
                            areg <= a_ext; breg <= b_ext; take_high_q <= take_high;
                            state <= MUL1;
                        end else if (div_zero) begin
                            case (op)
                                `F3_DIV, `F3_DIVU: result <= 32'hFFFF_FFFF;
                                default:           result <= a;
                            endcase
                            state <= FIN;
                        end else if (overflow) begin
                            result <= (op == `F3_DIV) ? 32'h8000_0000 : 32'b0;
                            state  <= FIN;
                        end else begin
                            acc       <= {32'b0, abs_a};
                            divisor_q <= abs_b;
                            cnt       <= 6'd32;
                            state     <= CALC;
                        end
                    end
                end

                // inmultire pipeline: produsul intre doua registre -> DSP rapid
                MUL1: begin
                    preg  <= areg * breg;
                    state <= MUL2;
                end
                MUL2: begin
                    result <= take_high_q ? preg[63:32] : preg[31:0];
                    state  <= FIN;
                end

                CALC: begin
                    acc <= acc_nx;
                    cnt <= cnt - 6'd1;
                    if (cnt == 6'd1) begin
                        if (op_q == `F3_DIV || op_q == `F3_DIVU)
                            result <= neg_q ? (~acc_nx[31:0]  + 32'd1) : acc_nx[31:0];
                        else
                            result <= neg_r ? (~acc_nx[63:32] + 32'd1) : acc_nx[63:32];
                        state <= FIN;
                    end
                end

                FIN: state <= IDLE;

                default: state <= IDLE;
            endcase
        end
    end

endmodule