# ModelSim testbenches

Run either test from the project root in the ModelSim Transcript:

```tcl
do Modelsim/run_fsm.do
# Or, for hit detection only:
do Modelsim/run_hitdetect.do
```

From inside this folder, use `do run_fsm.do` or `do run_hitdetect.do`.
Each script compiles `../MILESTONE1.v` and its testbench, runs the checks,
and leaves that test's waveform open. Success prints `PASS: tb_hit_detector`
or `PASS: tb_gameFSM`. Failed checks use `$fatal`.

- `tb_gameFSM.sv`: state transitions, ignored inputs, simultaneous Start/timeup,
  and asynchronous reset. States: 0 = BEGIN, 1 = PLAY, 2 = END.
- `tb_hit_detector.sv`: play/cue gating, first hits, held and repeated presses,
  note changes, LED behavior, clear, and asynchronous reset.
- `run_fsm.do`: FSM-only demonstration with named and numeric state waveforms.
- `run_hitdetect.do`: hit-detection-only checks and waveforms.
- `modelsim.ini`: simulator settings and library mappings.

For the FSM demonstration alone, run `do Modelsim/run_fsm.do` from the root
or `do run_fsm.do` from this folder.

For hit detection alone:

```tcl
do Modelsim/run_hitdetect.do
```

The hit test accepts `+CHECK_BOUNDARY` on the `vsim` command for an optional
regression. It currently fails when a press coincides with a note change:
the RTL does not remember that hit, potentially allowing another score for
the same note.

ModelSim generates `work/`, transcripts, and waveform files when running.
These generated files are ignored by Git.
