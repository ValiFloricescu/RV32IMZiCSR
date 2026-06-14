#!/usr/bin/env bash
# ============================================================
#  run_dut.sh  -  Ruleaza un test compilat pe DUT-ul pipe5 si
#                 produce fisierul de semnatura pentru riscof.
# ------------------------------------------------------------
#  Argumente:
#    $1 = ELF-ul testului (deja compilat de riscof cu toolchain-ul)
#    $2 = directorul de lucru al testului
#    $3 = fisierul de semnatura de produs
#  Mediu:
#    PIPE5_ROOT = radacina proiectului (unde e rtl/ si test/)
#
#  Pasi: ELF -> binar -> hex pe cuvinte (little-endian) pentru $readmemh;
#  extrage begin_signature/end_signature/tohost din simboluri; compileaza
#  harness-ul tb_compliance cu adresele respective; ruleaza si scrie semnatura.
# ============================================================
set -e
ELF="$1"; WORK="$2"; SIG="$3"
ROOT="${PIPE5_ROOT:?seteaza PIPE5_ROOT spre radacina proiectului}"
PREFIX="${RISCV_PREFIX:-riscv32-unknown-elf-}"

HEX="$WORK/dut.hex"

# 1) ELF -> binar -> hex pe cuvinte de 32 biti (little-endian)
"${PREFIX}objcopy" -O binary "$ELF" "$WORK/dut.bin"
python3 - "$WORK/dut.bin" "$HEX" <<'PY'
import sys, struct
data = open(sys.argv[1],'rb').read()
data += b'\x00'*((-len(data)) % 4)
with open(sys.argv[2],'w') as f:
    for i in range(0, len(data), 4):
        f.write('%08x\n' % struct.unpack('<I', data[i:i+4])[0])
PY

# 2) adrese simboluri
get_sym() { "${PREFIX}nm" "$ELF" | awk -v s="$1" '$3==s {print "32\x27h"$1}'; }
SIG_BEGIN=$(get_sym begin_signature)
SIG_END=$(get_sym end_signature)
TOHOST=$(get_sym tohost)

# entry point-ul ELF -> vector de reset (testele arch-test sunt linkate la 0x80000000)
ENTRY=$("${PREFIX}readelf" -h "$ELF" | awk '/Entry point/ {print $NF}')
RESET_PC="32'h${ENTRY#0x}"

# dimensioneaza memoria dupa binar: nr cuvinte rotunjit la putere de 2, minim 65536
BYTES=$(stat -c%s "$WORK/dut.bin")
NEED=$(( (BYTES + 3) / 4 ))
WORDS=65536
while [ "$WORDS" -lt "$NEED" ]; do WORDS=$(( WORDS * 2 )); done

# 3) compileaza harness-ul cu adresele testului
OUT="$WORK/dut_sim.out"
iverilog -g2012 -I "$ROOT/rtl" -s tb_compliance -o "$OUT" \
  -DPROG_HEX="\"$HEX\"" -DSIG_FILE="\"$SIG\"" \
  -DSIG_BEGIN="$SIG_BEGIN" -DSIG_END="$SIG_END" -DTOHOST="$TOHOST" \
  -DRESET_PC_TB="$RESET_PC" -DWORDS_TB="$WORDS" \
  -DDUMP_FILE="\"$WORK/dut.vcd\"" \
  "$ROOT"/rtl/*.v "$ROOT/test/tb_compliance.v"

# 4) ruleaza -> produce $SIG
vvp "$OUT" > "$WORK/dut_sim.log" 2>&1
echo "[run_dut] semnatura: $SIG"