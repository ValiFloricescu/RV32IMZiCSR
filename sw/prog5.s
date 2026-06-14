# =====================================================================
#  prog5.s  -  Program demo pentru bring-up SoC (incarcat de PS prin AXI)
# ---------------------------------------------------------------------
#  Calculeaza suma 1..10 = 55 si o scrie la adresa de date 0x100
#  (separata de zona de cod), apoi intra in self-loop (halt).
#  PS-ul citeste apoi 0x100 prin AXI4-Lite si verifica = 55.
# =====================================================================

        addi  x2, x0, 1         # i = 1
        addi  x3, x0, 11        # limita = 11
        addi  x1, x0, 0         # suma = 0
loop:   add   x1, x1, x2        # suma += i
        addi  x2, x2, 1         # i++
        blt   x2, x3, loop      # cat timp i < 11
        addi  x5, x0, 0x100     # x5 = adresa de date (256)
        sw    x1, 0(x5)         # MEM[0x100] = suma
done:   jal   x0, done          # halt (bucla pe loc)
