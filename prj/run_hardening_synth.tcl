open_project [file normalize "ov5640_hdmi.xpr"]
update_compile_order -fileset sources_1
synth_design -top ov5640_hdmi -part xc7a75tfgg484-2 -flatten_hierarchy rebuilt
write_checkpoint -force hardening_synth.dcp
report_utilization -file hardening_utilization_synth.rpt
report_cdc -details -file hardening_cdc_synth.rpt
report_methodology -file hardening_methodology_synth.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file hardening_timing_synth.rpt
close_project
