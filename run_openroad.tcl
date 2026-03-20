set MLEF /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef
set LIB  /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_lef $MLEF
read_liberty $LIB
read_verilog clean_netlist.v
link_design design_seq

create_clock -name clk -period 2.0 [get_ports clk]
set_input_delay  -clock clk -max 0.5 [get_ports {a b c}]
set_output_delay -clock clk -max 0.3 [get_ports y]

report_checks -path_delay max -format full_clock_expanded > report_setup.rpt
report_checks -path_delay min > report_hold.rpt
report_wns
report_tns

exit
