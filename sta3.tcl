set MLEF /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef
set LIB  /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_lef $MLEF
read_liberty $LIB
read_verilog clean_netlist3.v
link_design design3

create_clock -name clk -period 1.0 [get_ports clk]
set_input_delay  -clock clk -max 0.6 [get_ports {a b}]
set_input_delay  -clock clk -min 0.1 [get_ports {a b}]
set_output_delay -clock clk -max 0.4 [get_ports y]

report_checks -path_delay max -format full_clock_expanded > d3_setup.rpt
report_checks -path_delay min >> d3_setup.rpt
report_wns
report_tns

exit
