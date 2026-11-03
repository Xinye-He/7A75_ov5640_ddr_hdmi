create_project -in_memory -part xc7a75tfgg484-2
set root_dir [file normalize [file join [file dirname [info script]] ..]]
set rtl_dir [file join $root_dir prj ov5640_hdmi.srcs sources_1 new]
set ip_stub_dir [file join $root_dir prj ov5640_hdmi.ip_user_files ip]

read_verilog [glob [file join $rtl_dir *.v]]
read_verilog [list [file join $ip_stub_dir clk_wiz_0 clk_wiz_0_stub.v]]
read_verilog [list [file join $ip_stub_dir rd_fifo rd_fifo_stub.v]]
read_verilog [list [file join $ip_stub_dir wr_fifo wr_fifo_stub.v]]
read_verilog [list [file join [file dirname [info script]] mig_7series_0_stub.v]]
synth_design -rtl -top ov5640_hdmi -part xc7a75tfgg484-2
