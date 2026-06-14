# ============================================================
#  prog1.s  -  Program de bring-up pentru nucleul single-cycle
# ------------------------------------------------------------
#  Calculeaza suma 1+2+...+10 = 55, o salveaza la adresa 0 in
#  memoria de date, o reincarca, apoi cateva operatii de acoperire.
#
#  Rezultate asteptate (verificate de tb_core_sc.v):
#    x1 = 55          (suma)
#    x2 = 11          (i final)
#    x3 = 11          (limita)
#    x4 = 55          (reincarcat din MEM[0])
#    x5 = 0           (11 - 11)
#    x6 = 0xABCDE000  (lui)
#    x7 = 44          (11 << 2)
#    MEM[0] = 55
#
#  NOTA: in Faza 8 acest fisier va fi asamblat cu riscv64-unknown-elf-gcc.
#  Pentru bring-up, .hex-ul a fost generat cu un mini-asamblor.
#  Adresele (octeti) si encodarile sunt in comentarii.
# ============================================================

_start:
    addi x1, x0, 0       # 0x00: 00000093   x1 = sum = 0
    addi x2, x0, 1       # 0x04: 00100113   x2 = i = 1
    addi x3, x0, 11      # 0x08: 00b00193   x3 = limita = 11

loop:
    add  x1, x1, x2      # 0x0c: 002080b3   sum += i
    addi x2, x2, 1       # 0x10: 00110113   i++
    blt  x2, x3, loop    # 0x14: fe314ce3   daca i < 11, reia bucla

    sw   x1, 0(x0)       # 0x18: 00102023   MEM[0] = sum
    lw   x4, 0(x0)       # 0x1c: 00002203   x4 = MEM[0]
    sub  x5, x3, x2      # 0x20: 402182b3   x5 = 11 - 11 = 0
    lui  x6, 0xABCDE     # 0x24: abcde337   x6 = 0xABCDE000
    slli x7, x2, 2       # 0x28: 00211393   x7 = 11 << 2 = 44

done:
    jal  x0, done        # 0x2c: 0000006f   bucla infinita (halt)
