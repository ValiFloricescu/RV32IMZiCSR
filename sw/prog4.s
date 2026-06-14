# =====================================================================
#  prog4.s  -  Test extensia M (RV32IM) prin pipeline
# ---------------------------------------------------------------------
#  Verifica MUL / DIV / REM cu:
#    - dependenta de date pe rezultatul unei operatii M (stall multi-cycle)
#    - operatii M consecutive (div urmat imediat de rem pe aceiasi operanzi)
#
#  Rezultate asteptate:
#    x3 = 42   (6 * 7)
#    x4 = 43   (x3 + 1)        <- depinde de rezultatul MUL (testeaza stall-ul)
#    x7 = 14   (100 / 7)
#    x8 = 2    (100 % 7)       <- imediat dupa div (testeaza done combinational)
#    x9 = 28   (x7 * x8 = 14*2)
# =====================================================================

        addi  x1, x0, 6         # x1 = 6
        addi  x2, x0, 7         # x2 = 7
        mul   x3, x1, x2        # x3 = 42      (operatie M multi-cycle)
        addi  x4, x3, 1         # x4 = 43      consumatorul asteapta dupa MUL

        addi  x5, x0, 100       # x5 = 100
        addi  x6, x0, 7         # x6 = 7
        div   x7, x5, x6        # x7 = 14
        rem   x8, x5, x6        # x8 = 2       a doua op M consecutiva
        mul   x9, x7, x8        # x9 = 28      depinde de ambele rezultate M
