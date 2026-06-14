# ============================================================
#  build_fpga.tcl  -  Construieste AUTOMAT proiectul Vivado
#                     pentru PYNQ-Z2 si genereaza bitstream-ul.
# ------------------------------------------------------------
#  Cum se ruleaza (din RADACINA repo-ului, unde se afla folderele
#  rtl/ si sw/):
#
#    A) din terminal:
#         vivado -mode batch -source build_fpga.tcl
#
#    B) din Vivado (GUI) -> fereastra "Tcl Console" de jos:
#         cd /calea/catre/LICENTA
#         source build_fpga.tcl
#
#  Rezultat final:
#    build/riscv_fpga.runs/impl_1/board_top.bit
# ============================================================

set ROOT [pwd]
set PROJ "build"
set PART "xc7z020clg400-1"   ;# PYNQ-Z2 (Zynq-7020, CLG400, speed -1)

# --- verificare minima: suntem in radacina corecta? ---
if {![file isdirectory "$ROOT/rtl"]} {
    error "Nu gasesc folderul rtl/ in $ROOT . Ruleaza scriptul din radacina repo-ului."
}

puts "==> Creez proiectul in $ROOT/$PROJ (part $PART)"
file delete -force "$ROOT/$PROJ"
create_project riscv_fpga "$ROOT/$PROJ" -part $PART

# ------------------------------------------------------------
# 1) Surse RTL: nucleul + wrapper-ele FPGA
# ------------------------------------------------------------
set rtl_files [list \
  "$ROOT/rtl/riscv_defs.vh" \
  "$ROOT/rtl/alu.v" \
  "$ROOT/rtl/control.v" \
  "$ROOT/rtl/csr.v" \
  "$ROOT/rtl/forwarding.v" \
  "$ROOT/rtl/hazard.v" \
  "$ROOT/rtl/imm_gen.v" \
  "$ROOT/rtl/muldiv.v" \
  "$ROOT/rtl/regfile.v" \
  "$ROOT/rtl/riscv_core_pipe.v" \
  "$ROOT/rtl/fpga_mem.v" \
  "$ROOT/rtl/fpga_top.v" \
  "$ROOT/rtl/board_top.v" \
]
add_files -fileset sources_1 $rtl_files

# riscv_defs.vh este fisier de tip "header" (include), nu modul de sine statator
set_property file_type {Verilog Header} [get_files "$ROOT/rtl/riscv_defs.vh"]

# ------------------------------------------------------------
# 2) Fisierul de initializare a memoriei (citit de $readmemh la sinteza)
#    Adaugarea lui face ca directorul sa intre in calea de cautare.
# ------------------------------------------------------------
add_files -fileset sources_1 "$ROOT/sw/fpga_demo.mem"
set_property file_type {Memory Initialization Files} [get_files "$ROOT/sw/fpga_demo.mem"]

# ------------------------------------------------------------
# 3) Clocking Wizard: MMCM 125 MHz -> 50 MHz
# ------------------------------------------------------------
puts "==> Creez IP-ul clk_wiz_0 (125 MHz -> 50 MHz)"
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {125.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
  CONFIG.USE_RESET {false} \
  CONFIG.USE_LOCKED {true} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]
# sintetizez IP-ul "out-of-context" (cu garda, pt diferente intre versiuni)
catch { create_ip_run [get_ips clk_wiz_0] }
catch { launch_runs clk_wiz_0_synth_1 -jobs 4 ; wait_on_run clk_wiz_0_synth_1 }

# ------------------------------------------------------------
# 4) Constrangeri (pini PYNQ-Z2 din master XDC oficial)
# ------------------------------------------------------------
puts "==> Scriu constrangerile (XDC)"
set xdc_path "$ROOT/$PROJ/pynqz2_pins.xdc"
set fh [open $xdc_path w]
puts $fh "## Ceas 125 MHz (pin H16)"
puts $fh "set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } \[get_ports { sysclk }\]"
puts $fh "create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4} \[get_ports { sysclk }\]"
puts $fh ""
puts $fh "## Buton BTN0 (pin D19) - apasat = reset"
puts $fh "set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } \[get_ports { btn }\]"
puts $fh ""
puts $fh "## LED-uri LD0..LD3"
puts $fh "set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } \[get_ports { led\[0\] }\]"
puts $fh "set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } \[get_ports { led\[1\] }\]"
puts $fh "set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } \[get_ports { led\[2\] }\]"
puts $fh "set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } \[get_ports { led\[3\] }\]"
close $fh
add_files -fileset constrs_1 $xdc_path

# ------------------------------------------------------------
# 5) Modulul de top + ordinea de compilare
# ------------------------------------------------------------
set_property top board_top [current_fileset]
update_compile_order -fileset sources_1

# ------------------------------------------------------------
# 6) Sinteza -> Implementare -> Bitstream
# ------------------------------------------------------------
puts "==> Pornesc SINTEZA"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Sinteza a esuat. Vezi mesajele de mai sus."
}

puts "==> Pornesc IMPLEMENTAREA + BITSTREAM"
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementarea/bitstream a esuat. Vezi mesajele de mai sus."
}

set BIT "$ROOT/$PROJ/riscv_fpga.runs/impl_1/board_top.bit"
puts "============================================================"
puts "  GATA. Bitstream generat:"
puts "  $BIT"
puts "============================================================"
puts "  Urmatorul pas: Open Hardware Manager -> Open Target ->"
puts "  Auto Connect -> Program Device -> selecteaza bitstream-ul."
puts "============================================================"
