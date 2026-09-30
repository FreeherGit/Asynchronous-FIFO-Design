create_project async_fifo_proj ./vivado_proj -part xc7a35tcpg236-1 -force
add_files -fileset sources_1 ../rtl/async_fifo.sv
add_files -fileset sim_1 ../tb/async_fifo_tb.sv
set_property top async_fifo [current_fileset]
set_property top async_fifo_tb [get_filesets sim_1]
synth_design -rtl -name rtl_1
show_schematic [get_cells -hierarchical]
