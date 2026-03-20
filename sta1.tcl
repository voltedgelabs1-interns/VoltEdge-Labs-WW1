set MLEF /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef
set LIB  /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_lef $MLEF
read_liberty $LIB
read_verilog clean_netlist1.v
link_design design1

create_clock -name clk -period 0.5 [get_ports clk]
set_input_delay  -clock clk -max 0.4 [get_ports {a b c d}]
set_output_delay -clock clk -max 0.1 [get_ports y]

report_checks -path_delay max -format full_clock_expanded > d1_setup.rpt
report_checks -path_delay min >> d1_setup.rpt
report_wns
report_tns

exit
