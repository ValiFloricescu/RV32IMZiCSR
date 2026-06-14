cd ~/Desktop/LICENTA
mkdir -p scheme_rtl
for m in regfile alu imm_gen control forwarding hazard muldiv csr; do
  yosys -q -p "read_verilog -I rtl rtl/$m.v; hierarchy -top $m; proc; opt_clean; show -format dot -prefix /tmp/$m"
  dot -Tpdf /tmp/$m.dot -o scheme_rtl/rtl_$m.pdf
  echo "gata: rtl_$m.pdf"
done
