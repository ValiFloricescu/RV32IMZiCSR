`timescale 1ns / 1ps
`include "riscv_defs.vh"

module muldiv (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  op,
    output reg  [31:0] result,
    output wire        busy,
    output wire        done
);

    localparam IDLE = 2'd0, CALC = 2'd1, FIN = 2'd2;
    reg [1:0]  state;
    reg [63:0] acc;
    reg [31:0] divisor_q;
    reg [5:0]  cnt;
    reg        neg_q, neg_r;
    reg [2:0]  op_q;

    assign busy = (state == CALC);
    assign done = (state == FIN);

    wire is_mul = (op == `F3_MUL) || (op == `F3_MULH) ||
                  (op == `F3_MULHSU) || (op == `F3_MULHU);
    wire signed_div = (op == `F3_DIV) || (op == `F3_REM);

    wire signed [63:0] as = $signed({{32{a[31]}}, a});
    wire signed [63:0] bs = $signed({{32{b[31]}}, b});
    wire signed [63:0] au = $signed({32'b0, a});
    wire signed [63:0] bu = $signed({32'b0, b});
    wire [63:0] p_ss = as * bs;
    wire [63:0] p_uu = au * bu;
    wire [63:0] p_su = as * bu;
    reg  [31:0] mul_res;
    always @(*) begin
        case (op)
            `F3_MUL   : mul_res = p_uu[31:0];
            `F3_MULH  : mul_res = p_ss[63:32];
            `F3_MULHSU: mul_res = p_su[63:32];
            `F3_MULHU : mul_res = p_uu[63:32];
            default   : mul_res = p_uu[31:0];
        endcase
    end

    wire na = signed_div && a[31];
    wire nb = signed_div && b[31];
    wire [31:0] abs_a = na ? (~a + 32'd1) : a;
    wire [31:0] abs_b = nb ? (~b + 32'd1) : b;
    wire div_zero = (b == 32'd0);
    wire overflow = signed_div && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);

    wire [63:0] acc_sh = acc << 1;
    wire [31:0] rem_hi = acc_sh[63:32];
    wire [32:0] diff   = {1'b0, rem_hi} - {1'b0, divisor_q};
    wire        ge     = ~diff[32];
    wire [63:0] acc_nx = ge ? {diff[31:0], acc_sh[31:0] | 32'h1} : acc_sh;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; result <= 32'b0;
            acc <= 64'b0; divisor_q <= 32'b0; cnt <= 6'b0;
            neg_q <= 1'b0; neg_r <= 1'b0; op_q <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        op_q  <= op;
                        neg_q <= (na ^ nb);
                        neg_r <= na;
                        if (is_mul) begin
                            result <= mul_res; state <= FIN;
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
