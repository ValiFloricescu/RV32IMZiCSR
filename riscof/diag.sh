#!/usr/bin/env bash
# ============================================================
#  diag_riscof.sh  -  Centralizeaza rezultatele RISCOF
# ------------------------------------------------------------
#  Compara, pentru fiecare test, semnatura produsa de DUT cu
#  semnatura modelului de referinta si raporteaza MATCH/DIFERIT,
#  cu un sumar grupat pe familii de teste (I, M, privilege, pmp...).
#
#  Utilizare:
#     ./diag_riscof.sh [cale_riscof_work]      # implicit: riscof/riscof_work
#     ./diag_riscof.sh -d [cale]               # listeaza DOAR diferentele
#
#  Asumptii de layout (standard RISCOF):
#     <work>/<familie>/src/<test>.S/dut/*.signature   (DUT)
#     <work>/<familie>/src/<test>.S/ref/*.signature   (referinta)
# ============================================================
set -u

ONLY_DIFF=0
if [ "${1:-}" = "-d" ]; then ONLY_DIFF=1; shift; fi
WORK="${1:-riscof/riscof_work}"

if [ ! -d "$WORK" ]; then
  echo "Nu gasesc directorul de lucru RISCOF: $WORK"
  echo "Utilizare: $0 [-d] [cale_catre_riscof_work]"
  exit 1
fi

match=0; diff=0; missing=0
declare -A diff_by_fam
declare -A tot_by_fam

if [ "$ONLY_DIFF" -eq 0 ]; then
  printf "%-46s %-10s %s\n" "TEST" "FAMILIE" "REZULTAT"
  printf '%.0s-' {1..72}; echo
fi

# fiecare test are un subdirector dut/ cu o semnatura
while IFS= read -r dutsig; do
  testdir="$(dirname "$(dirname "$dutsig")")"          # .../<test>.S
  name="$(basename "$testdir")"
  refsig="$(ls "$testdir"/ref/*.signature 2>/dev/null | head -1)"
  fam="$(echo "$testdir" | sed -E 's#.*/riscof_work/##; s#/.*##')"
  tot_by_fam[$fam]=$(( ${tot_by_fam[$fam]:-0} + 1 ))

  if [ -z "$refsig" ] || [ ! -f "$refsig" ]; then
    [ "$ONLY_DIFF" -eq 0 ] && printf "%-46s %-10s %s\n" "$name" "$fam" "LIPSA-REF"
    missing=$((missing+1)); continue
  fi

  if diff -q "$dutsig" "$refsig" >/dev/null 2>&1; then
    [ "$ONLY_DIFF" -eq 0 ] && printf "%-46s %-10s %s\n" "$name" "$fam" "MATCH"
    match=$((match+1))
  else
    printf "%-46s %-10s %s\n" "$name" "$fam" "DIFERIT"
    diff=$((diff+1)); diff_by_fam[$fam]=$(( ${diff_by_fam[$fam]:-0} + 1 ))
  fi
done < <(find "$WORK" -type f -path '*/dut/*.signature' | sort)

echo
printf '%.0s=' {1..72}; echo
echo "  TOTAL:  MATCH=$match   DIFERIT=$diff   LIPSA-REF=$missing   ($((match+diff+missing)) teste)"
printf '%.0s-' {1..72}; echo
echo "  Pe familie (diferite / total):"
for fam in $(printf "%s\n" "${!tot_by_fam[@]}" | sort); do
  printf "    %-14s %3d / %-3d\n" "$fam" "${diff_by_fam[$fam]:-0}" "${tot_by_fam[$fam]}"
done
printf '%.0s=' {1..72}; echo