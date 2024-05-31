## This file is a general .xdc for the Nexys4 DDR Rev. C
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { sys_clock }]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {sys_clock}];
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {reset}]

#compress bit file
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

#QSPI signals

#USB-UART signals
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {usb_uart_0_txd}]
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports {usb_uart_0_rxd}]

#DDR2 Memory signals\\
set_property -dict {PACKAGE_PIN R7 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[0]}]
set_property -dict {PACKAGE_PIN V6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[1]}]
set_property -dict {PACKAGE_PIN R8 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[2]}]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[3]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[4]}]
set_property -dict {PACKAGE_PIN R6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[5]}]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[6]}]
set_property -dict {PACKAGE_PIN R5 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[7]}]
set_property -dict {PACKAGE_PIN T5 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[8]}]
set_property -dict {PACKAGE_PIN U3 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[9]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[10]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[11]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[12]}]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[13]}]
set_property -dict {PACKAGE_PIN V1 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[14]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dq[15]}]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dm[0]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_dm[1]}]

set_property -dict {PACKAGE_PIN U9 IOSTANDARD DIFF_SSTL18_II} [get_ports {ddr2_sdram_dqs_p[0]}]
set_property -dict {PACKAGE_PIN V9 IOSTANDARD DIFF_SSTL18_II} [get_ports {ddr2_sdram_dqs_n[0]}]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD DIFF_SSTL18_II} [get_ports {ddr2_sdram_dqs_p[1]}]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD DIFF_SSTL18_II} [get_ports {ddr2_sdram_dqs_n[1]}]

set_property -dict {PACKAGE_PIN N6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[12]}]
set_property -dict {PACKAGE_PIN K5 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[11]}]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[10]}]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[9]}]
set_property -dict {PACKAGE_PIN L4 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[8]}]
set_property -dict {PACKAGE_PIN N1 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[7]}]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[6]}]
set_property -dict {PACKAGE_PIN P5 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[5]}]
set_property -dict {PACKAGE_PIN L3 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[4]}]
set_property -dict {PACKAGE_PIN T1 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[3]}]
set_property -dict {PACKAGE_PIN M6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[2]}]
set_property -dict {PACKAGE_PIN P4 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[1]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_addr[0]}]

set_property -dict {PACKAGE_PIN R1 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_ba[2]}]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_ba[1]}]
set_property -dict {PACKAGE_PIN P2 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_ba[0]}]

set_property -dict {PACKAGE_PIN L6 IOSTANDARD DIFF_SSTL18_II} [get_ports {ddr2_sdram_ck_p[0]}]
set_property -dict {PACKAGE_PIN L5 IOSTANDARD DIFF_SSTL18_II} [get_ports {ddr2_sdram_ck_n[0]}]

set_property -dict {PACKAGE_PIN N4 IOSTANDARD SSTL18_II} [get_ports ddr2_sdram_ras_n]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD SSTL18_II} [get_ports ddr2_sdram_cas_n]
set_property -dict {PACKAGE_PIN N2 IOSTANDARD SSTL18_II} [get_ports ddr2_sdram_we_n]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_cke[0]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_odt[0]}]
set_property -dict {PACKAGE_PIN K6 IOSTANDARD SSTL18_II} [get_ports {ddr2_sdram_cs_n[0]}]