open_checkpoint hardening_synth.dcp
create_generated_clock -name i2c_dri_clk -divide_by 50 \
    -source [get_pins u_ov5640_dri/u_i2c_dr/dri_clk_reg/C] \
    [get_pins u_ov5640_dri/u_i2c_dr/dri_clk_reg/Q]
set_clock_groups -asynchronous \
    -group [get_clocks cmos_pclk] \
    -group [get_clocks -include_generated_clocks sys_clk]
set pixel_clocks [get_clocks {clk_out3_clk_wiz_0 clk_out4_clk_wiz_0}]
set non_pixel_sys_clocks [get_clocks -filter \
    {NAME != cmos_pclk && NAME != clk_out3_clk_wiz_0 && NAME != clk_out4_clk_wiz_0}]
set_clock_groups -asynchronous -group $pixel_clocks -group $non_pixel_sys_clocks
write_checkpoint -force hardening_synth.dcp
report_utilization -file hardening_utilization_synth.rpt
report_cdc -details -file hardening_cdc_synth.rpt
report_methodology -file hardening_methodology_synth.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file hardening_timing_synth.rpt
