#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H
// ============================================================
//  model_test.h  -  Macrouri RVMODEL pentru DUT-ul pipe5 (RV32IM)
// ------------------------------------------------------------
//  RVMODEL_HALT  : scrie 1 la simbolul `tohost` -> harness-ul opreste
//                  simularea si exporta semnatura.
//  Regiunea de semnatura e delimitata de begin_signature / end_signature.
//
//  NOTA: RVMODEL_BOOT e gol aici (fara setup de trap/CSR). Pentru suita
//  completa riscv-arch-test, nucleul are nevoie de suport minim de masina
//  (Zicsr + mtvec/mepc/mcause + ECALL/illegal -> trap). Vezi faza urmatoare.
// ============================================================

#define RVMODEL_DATA_SECTION                                            \
        .pushsection .tohost,"aw",@progbits;                            \
        .align 8; .global tohost; tohost: .dword 0;                     \
        .align 8; .global fromhost; fromhost: .dword 0;                 \
        .popsection;

// oprire: scrie 1 la tohost, apoi bucla pe loc
#define RVMODEL_HALT                                                    \
    li x1, 1;                                                           \
    la x2, tohost;                                                      \
    sw x1, 0(x2);                                                       \
    rvmodel_halt_loop:                                                  \
    j rvmodel_halt_loop;

#define RVMODEL_BOOT

// inceputul / sfarsitul regiunii de semnatura
#define RVMODEL_DATA_BEGIN                                              \
  .align 4; .global begin_signature; begin_signature:

#define RVMODEL_DATA_END                                                \
  .align 4; .global end_signature; end_signature:                       \
  RVMODEL_DATA_SECTION

// fara I/O, fara intreruperi (DUT minimal)
#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)
#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT
#define RVMODEL_SET_SSW_INT
#define RVMODEL_CLEAR_SSW_INT
#define RVMODEL_CLEAR_STIMER_INT
#define RVMODEL_CLEAR_SEXT_INT

#endif // _COMPLIANCE_MODEL_H
