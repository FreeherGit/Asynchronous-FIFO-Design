log_wave -recursive *
add_wave /async_fifo_tb/test_case_name
add_wave_divider "Write Domain"
add_wave /async_fifo_tb/dut/wr_clk /async_fifo_tb/dut/w_arst_n /async_fifo_tb/dut/wr_en /async_fifo_tb/dut/wr_data /async_fifo_tb/dut/wbin /async_fifo_tb/dut/wgray /async_fifo_tb/dut/wq2_rgray /async_fifo_tb/dut/full
add_wave_divider "Read Domain"
add_wave /async_fifo_tb/dut/rd_clk /async_fifo_tb/dut/r_arst_n /async_fifo_tb/dut/rd_en /async_fifo_tb/dut/rd_data /async_fifo_tb/dut/rbin /async_fifo_tb/dut/rgray /async_fifo_tb/dut/rq2_wgray /async_fifo_tb/dut/empty
run all
