# =====================================================================
#  prog6.s  -  Test Zicsr + trap prin pipeline (Faza 9)
# ---------------------------------------------------------------------
#  Verifica: scriere/citire CSR, setarea mtvec, ECALL -> handler,
#  citirea mcause/mepc, ajustarea mepc (+4) si revenirea cu MRET.
#
#  Rezultate asteptate:
#    x7  = 0x123        (csrr mscratch dupa csrw)
#    x8  = 0x40001100   (csrr misa = RV32IM)
#    x9  = 11           (mcause = ECALL din mod masina)
#    x20 = 42           (handler-ul a rulat)
#    x21 = 7            (s-a revenit din trap)
# =====================================================================
        .text
_start:
        addi  x5, x0, 64          # adresa handler-ului (byte 64)
        csrw  mtvec, x5           # vectorul de trap = handler
        addi  x6, x0, 0x123
        csrw  mscratch, x6        # mscratch = 0x123
        csrr  x7, mscratch        # x7 = 0x123
        csrr  x8, misa            # x8 = 0x40001100
        addi  x20, x0, 0          # marker handler = 0
        addi  x21, x0, 0          # marker revenire = 0
        ecall                     # -> trap la handler
back:
        addi  x21, x0, 7          # am revenit din trap
done:   jal   x0, done           # halt

        .org 64                   # handler la byte 64 (= mtvec)
handler:
        addi  x20, x0, 42         # handler-ul a rulat
        csrr  x9,  mcause         # x9 = 11
        csrr  x10, mepc           # x10 = PC-ul lui ecall
        addi  x10, x10, 4         # sari peste ecall
        csrw  mepc, x10
        mret                      # -> revine la 'back'
