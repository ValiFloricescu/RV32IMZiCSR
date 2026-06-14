## Ceas 125 MHz (pin H16)
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { sysclk }]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports { sysclk }]

## Buton BTN0 (pin D19) - apasat = reset
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports { btn }]

## LED-uri LD0..LD3
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports { led[3] }]
