set_param project.enableReportConfiguration 0
load_feature core
current_fileset
xsim {fifo_sim_snapshot} -wdb {fifo_sim_snapshot.wdb} -autoloadwcfg -tclbatch {xsim_gui.tcl}
