# =====================================================================
#  compliance_demo.s  -  Test fabricat manual pentru harness-ul de
#  conformitate (fara toolchain). Demonstreaza mecanismul tohost +
#  export de semnatura, identic cu modelul riscv-arch-test.
#
#    SIG_BEGIN = 0x200, SIG_END = 0x208, TOHOST = 0x300
#    semnatura asteptata:  0000002a (42),  000000b9 (185)
# =====================================================================
        addi  x1,  x0, 5
        addi  x2,  x0, 37
        add   x3,  x1, x2        # 42
        mul   x4,  x1, x2        # 185 (extensia M)
        addi  x10, x0, 0x200     # baza semnaturii
        sw    x3,  0(x10)        # signature[0] = 42
        sw    x4,  4(x10)        # signature[1] = 185
        addi  x11, x0, 0x300     # adresa tohost
        addi  x12, x0, 1         # 1 = trecut
        sw    x12, 0(x11)        # tohost = 1 -> halt + dump
done:   jal   x0,  done          # bucla pe loc
