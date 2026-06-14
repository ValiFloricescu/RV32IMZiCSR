# ============================================================
#  prog3.s  -  Test pentru forwarding + load-use (Faza 4)
# ------------------------------------------------------------
#  Dependente RAW inlantuite si un hazard load-use, FARA NICIUN NOP.
#  Daca ruleaza corect, forwarding-ul (EX/MEM si MEM/WB) si stall-ul
#  load-use functioneaza. Fara branch-uri (hazardul de control = Faza 5).
#
#  Rezultate asteptate (tb_core_pipe_fwd.v):
#    x1=5, x2=8, x3=13, x4=5, x5=13, x6=18, x7=19, MEM[0]=13
# ============================================================

_start:
    addi x1, x0, 5       # x1 = 5
    addi x2, x1, 3       # x2 = 8   -> RAW pe x1 (forward EX/MEM)
    add  x3, x2, x1      # x3 = 13  -> RAW pe x2 (EX/MEM) si x1 (MEM/WB)
    sub  x4, x3, x2      # x4 = 5   -> RAW pe x3, x2
    sw   x3, 0(x0)       # MEM[0]=13 (datele de store = x3 forwardat)
    lw   x5, 0(x0)       # x5 = 13
    add  x6, x5, x1      # x6 = 18  -> LOAD-USE: stall 1 ciclu + forward MEM/WB
    addi x7, x6, 1       # x7 = 19  -> RAW pe x6
