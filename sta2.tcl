set MLEF /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef
set LIB  /home/vboxuser/projects/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_lef $MLEF
read_liberty $LIB
read_verilog clean_netlist2.v
link_design design2

create_clock -name clk -period 2.0 [get_ports clk]
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold  0.3 [get_clocks clk]

set_input_delay -clock clk -max 1.8 [get_ports d]
set_input_delay -clock clk -min 1.8 [get_ports d]
set_output_delay -clock clk -max 0.1 [get_ports {q1 q2}]

report_checks -path_delay min -format full_clock_expanded > d2_hold.rpt
report_checks -path_delay max >> d2_hold.rpt
report_wns
report_tns

exit
