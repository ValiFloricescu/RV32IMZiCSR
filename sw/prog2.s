# ============================================================
#  prog2.s  -  Program FARA HAZARDURI pentru pipeline-ul naiv
# ------------------------------------------------------------
#  Verifica mecanica pipeline-ului pe 5 etaje INAINTE de a avea
#  forwarding/hazard. Dependentele sunt separate cu cate 3 NOP-uri:
#  un producator scrie in WB (ciclul p+4), deci consumatorul trebuie
#  sa citeasca in ID abia in ciclul >= p+5 (regfile scrie pe front,
#  citeste combinational => 3 instructiuni distanta).
#
#  Fara branch-uri (hazardul de control il tratam in Faza 5).
#
#  Rezultate asteptate (tb_core_pipe.v):
#    x1=5, x2=7, x3=12, x4=12, x5=17, MEM[0]=12
# ============================================================

_start:
    addi x1, x0, 5       # x1 = 5
    addi x2, x0, 7       # x2 = 7
    nop
    nop
    nop
    add  x3, x1, x2      # x3 = 12  (x1, x2 sunt gata: 3 NOP-uri distanta)
    nop
    nop
    nop
    sw   x3, 0(x0)       # MEM[0] = 12
    nop
    nop
    nop
    lw   x4, 0(x0)       # x4 = MEM[0] = 12
    nop
    nop
    nop
    add  x5, x4, x1      # x5 = 17
    nop
    nop
    nop
