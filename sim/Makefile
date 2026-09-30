# =============================================================================
# Asynchronous FIFO Verification & Build Makefile (Vivado XSIM)
# =============================================================================

# Project Variables
FILELIST    := list.f
RTL_TOP     := async_fifo
TB_TOP	    := async_fifo_tb
SNAPSHOT    := fifo_sim_snapshot
WDB_FILE    := $(SNAPSHOT).wdb
VCD_FILE    := async_fifo_tb.vcd
FPGA_PART   := xc7a35tcpg236-1

# Tool Flags
XVLOG_FLAGS := -sv -f $(FILELIST) --relax
XELAB_FLAGS := -debug typical --mt auto -L work

# Default target: Compile, Elaborate, and Run Simulation in Terminal
.PHONY: all compile elaborate sim wave vcd schematic clean help

all: compile elaborate sim

# -----------------------------------------------------------------------------
# 1. Compile SystemVerilog RTL & Testbench using list.f
# -----------------------------------------------------------------------------
compile:
	@echo ">>> [1/3] Compiling SystemVerilog sources from $(FILELIST)..."
	xvlog $(XVLOG_FLAGS) -log xvlog.log

# -----------------------------------------------------------------------------
# 2. Elaborate Design & Generate Simulation Snapshot
# -----------------------------------------------------------------------------
elaborate: compile
	@echo ">>> [2/3] Elaborating top module $(TB_TOP)..."
	xelab $(XELAB_FLAGS) $(TB_TOP) -s $(SNAPSHOT) -log xelab.log

# -----------------------------------------------------------------------------
# 3. Run Batch Simulation in Terminal (Also dumps async_fifo_tb.vcd)
# -----------------------------------------------------------------------------
sim: elaborate
	@echo ">>> [3/3] Running self-checking simulation in batch mode..."
	xsim $(SNAPSHOT) -R -log xsim.log

# -----------------------------------------------------------------------------
# 4. Launch Vivado GUI Waveform Debugger (Auto-loads signals & runs)
# -----------------------------------------------------------------------------
wave: elaborate
	@echo ">>> Launching Vivado XSIM GUI and logging all waveforms..."
	@echo "log_wave -recursive *" > xsim_gui.tcl
	@echo "add_wave /$(TB_TOP)/test_case_name" >> xsim_gui.tcl
	@echo "add_wave_divider \"Write Domain\"" >> xsim_gui.tcl
	@echo "add_wave /$(TB_TOP)/dut/wr_clk /$(TB_TOP)/dut/w_arst_n /$(TB_TOP)/dut/wr_en /$(TB_TOP)/dut/wr_data /$(TB_TOP)/dut/wbin /$(TB_TOP)/dut/wgray /$(TB_TOP)/dut/wq2_rgray /$(TB_TOP)/dut/full" >> xsim_gui.tcl
	@echo "add_wave_divider \"Read Domain\"" >> xsim_gui.tcl
	@echo "add_wave /$(TB_TOP)/dut/rd_clk /$(TB_TOP)/dut/r_arst_n /$(TB_TOP)/dut/rd_en /$(TB_TOP)/dut/rd_data /$(TB_TOP)/dut/rbin /$(TB_TOP)/dut/rgray /$(TB_TOP)/dut/rq2_wgray /$(TB_TOP)/dut/empty" >> xsim_gui.tcl
	@echo "run all" >> xsim_gui.tcl
	xsim $(SNAPSHOT) -gui -tclbatch xsim_gui.tcl -wdb $(WDB_FILE)

# -----------------------------------------------------------------------------
# 5. Open VCD Waveform in GTKWave (Optional lightweight Linux viewer)
# -----------------------------------------------------------------------------
vcd: sim
	@echo ">>> Opening $(VCD_FILE) in GTKWave..."
	gtkwave $(VCD_FILE) &

# -----------------------------------------------------------------------------
# 6. Open Vivado Project GUI for RTL Elaborated Schematic & Synthesis
# -----------------------------------------------------------------------------
schematic:
	@echo ">>> Generating Vivado project and opening Elaborated RTL Schematic..."
	@echo "create_project async_fifo_proj ./vivado_proj -part $(FPGA_PART) -force" > build_vivado.tcl
	@echo "add_files -fileset sources_1 ../rtl/async_fifo.sv" >> build_vivado.tcl
	@echo "add_files -fileset sim_1 ../tb/async_fifo_tb.sv" >> build_vivado.tcl
	@echo "set_property top $(RTL_TOP) [current_fileset]" >> build_vivado.tcl
	@echo "set_property top $(TB_TOP) [get_filesets sim_1]" >> build_vivado.tcl
	@echo "synth_design -rtl -name rtl_1" >> build_vivado.tcl
	@echo "show_schematic [get_cells -hierarchical]" >> build_vivado.tcl
	vivado -mode gui -source build_vivado.tcl
# -----------------------------------------------------------------------------
# 7. Clean All Generated Simulation & Synthesis Artifacts
# -----------------------------------------------------------------------------
clean:
	@echo ">>> Cleaning up simulation binaries, logs, waveforms, and temp directories..."
	rm -rf xsim.dir .Xil vivado_proj
	rm -f *.log *.jou *.pb *.wdb *.vcd *.str xsim_gui.tcl build_vivado.tcl

# -----------------------------------------------------------------------------
# 8. Help Menu
# -----------------------------------------------------------------------------
help:
	@echo "======================================================================"
	@echo " Asynchronous FIFO Makefile Targets:"
	@echo "   make		 : Compile, elaborate, and run self-checking testbench"
	@echo "   make compile	 : Only compile RTL and testbench via list.f (xvlog)"
	@echo "   make elaborate : Elaborate snapshot with debug visibility (xelab)"
	@echo "   make sim	 : Run batch simulation in terminal (xsim -R)"
	@echo "   make wave	 : Open Vivado GUI with signals grouped & pre-run"
	@echo "   make vcd	 : Open generated VCD waveform in GTKWave"
	@echo "   make schematic : Open Vivado IDE & generate RTL hardware schematic"
	@echo "   make clean	 : Remove all generated logs, waveforms, and build dirs"
	@echo "======================================================================"
