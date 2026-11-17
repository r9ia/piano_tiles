# Run with: do Modelsim/run_hitdetect.do (or do run_hitdetect.do inside Modelsim).
if {[file isfile Modelsim/tb_hit_detector.sv]} {cd Modelsim}
onerror {abort all}
if {![file isdirectory work]} {vlib work}
vmap piano_tests work
vlog -sv -work piano_tests ../MILESTONE1.v tb_hit_detector.sv
catch {quit -sim}
vsim -onfinish stop piano_tests.tb_hit_detector
catch {view wave}
delete wave *
add wave sim:/tb_hit_detector/*
delete wave sim:/tb_hit_detector/score
add wave -radix unsigned sim:/tb_hit_detector/score
run -all
wave zoom full
