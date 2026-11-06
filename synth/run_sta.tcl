# ==============================================================================
# OpenSTA Static Timing & Power Analysis for Neuromorphic BCI Top
# ==============================================================================

read_liberty synth/nangate45.lib
read_verilog synth/neuromorphic_bci_nangate45_netlist.v
link_design neuromorphic_bci_top

create_clock -name clk -period 10.0 [get_ports clk]
set_input_delay -clock clk 1.0 [all_inputs]
set_output_delay -clock clk 1.0 [all_outputs]

puts "=========================================================="
puts "  SETUP TIMING REPORT (Worst Negative Slack)"
puts "=========================================================="
report_checks -path_delay max -fields {slew cap input nets fanout} -digits 3

puts "=========================================================="
puts "  HOLD TIMING REPORT"
puts "=========================================================="
report_checks -path_delay min -fields {slew cap input nets fanout} -digits 3

puts "=========================================================="
puts "  POWER DISSIPATION REPORT (Nangate 45nm @ 100MHz)"
puts "=========================================================="
report_power -digits 4

exit
