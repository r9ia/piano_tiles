`timescale 1ns/1ps

module tb_gameFSM;
    reg Clock = 0;
    reg Resetn = 1;
    reg Start = 0;
    reg timeup = 0;
    wire [1:0] state;
    localparam [1:0] BEGIN_STATE = 0, PLAY_STATE = 1, END_STATE = 2;

    always #10 Clock = ~Clock; // 50 MHz

    gameFSM dut (
        .Clock(Clock), .Resetn(Resetn), .Start(Start),
        .timeup(timeup), .state(state)
    );

    task automatic check_state(input [1:0] expected, input string label_text);
        if (state !== expected)
            $fatal(1, "%s: expected state %0d, got %0d", label_text, expected, state);
        $display("%0t PASS: %s (state=%0d)", $time, label_text, state);
    endtask

    // Change inputs at falling edges, then check after registered updates.
    task automatic step(input bit start_value, input bit timeup_value,
                        input [1:0] expected, input string label_text);
        @(negedge Clock);
        Start = start_value;
        timeup = timeup_value;
        @(posedge Clock);
        #1;
        check_state(expected, label_text);
    endtask

    task automatic reset_fsm;
        @(negedge Clock);
        Start = 0;
        timeup = 0;
        #2 Resetn = 0;
        #1;
        check_state(BEGIN_STATE, "Asynchronous reset before next clock edge");
        @(posedge Clock);
        #1;
        check_state(BEGIN_STATE, "Hold reset");
        @(negedge Clock);
        Resetn = 1;
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 8);
        reset_fsm();
        repeat (3) step(0, 0, BEGIN_STATE, "Wait in BEGIN");
        step(0, 1, BEGIN_STATE, "BEGIN ignores timeup");
        step(1, 0, PLAY_STATE, "Start: BEGIN -> PLAY");
        repeat (3) step(0, 0, PLAY_STATE, "Stay in PLAY before timeout");
        step(1, 0, PLAY_STATE, "PLAY ignores Start");
        step(0, 1, END_STATE, "Timeout: PLAY -> END");
        repeat (3) step(0, 0, END_STATE, "Wait in END");
        step(0, 1, END_STATE, "END holds with timeup high");
        step(1, 1, BEGIN_STATE, "Start: END -> BEGIN even with timeup high");
        step(0, 0, BEGIN_STATE, "Wait for another Start");
        step(1, 1, PLAY_STATE, "BEGIN uses Start even with timeup high");
        step(1, 1, END_STATE, "PLAY uses timeup even with Start high");
        reset_fsm(); // Reset from END.
        step(1, 0, PLAY_STATE, "Start another game");
        reset_fsm(); // Reset from PLAY.
        step(0, 0, BEGIN_STATE, "Remain in BEGIN after reset");
        $display("PASS: tb_gameFSM");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout: tb_gameFSM");
    end
endmodule
