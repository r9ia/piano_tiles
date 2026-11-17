# Run with: do Modelsim/run_fsm.do (or do run_fsm.do inside Modelsim).
if {[file isfile Modelsim/tb_gameFSM.sv]} {cd Modelsim}
onerror {abort all}
if {![file isdirectory work]} {vlib work}
vmap piano_tests work
vlog -sv -work piano_tests ../MILESTONE1.v tb_gameFSM.sv
catch {quit -sim}
vsim -onfinish stop piano_tests.tb_gameFSM
catch {view wave}
add wave sim:/tb_gameFSM/Clock
add wave sim:/tb_gameFSM/Resetn
add wave sim:/tb_gameFSM/Start
add wave sim:/tb_gameFSM/timeup
virtual type { {0 BEGIN} {1 PLAY} {2 END} } fsm_state_type
virtual function {(fsm_state_type) /tb_gameFSM/state} state_name
add wave sim:/tb_gameFSM/state_name
add wave -radix unsigned sim:/tb_gameFSM/state
run -all
wave zoom full
