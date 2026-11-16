//KEY0 HIT
//KEY1 RESET - ALL TO BEGIN
//KEY2 START - BEGIN TO PLAY

//led0 = note cue
//led9 successful hit indicator  - flashes after valid press
//HEX5 state 0, 1 2 (begin play end)
//HEX4-3 COUNTDONW form 6-0
//HEX0 final score (shwon in END)




module MILESTONE1 #(
    parameter [31:0] HALF_SEC_CYCLES = 32'd25000000,
    parameter [31:0] DEBOUNCE_CYCLES = 32'd500000,
    parameter [7:0] GAME_HALF_STEPS = 8'd12
)(
    input  wire       CLOCK_50,
    input  wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    //audio ports
    input  wire AUD_ADCDAT,
    inout  wire AUD_BCLK,
    inout  wire AUD_ADCLRCK,
    inout  wire AUD_DACLRCK,
    inout  wire FPGA_I2C_SDAT,
    output wire AUD_XCK,
    output wire AUD_DACDAT,
    output wire FPGA_I2C_SCLK
);
    wire Resetn;
    wire StartPulse, PressPulse;
    wire [1:0] state;
    wire begin_state, playing, time_up;
    wire [7:0] half_step;
    wire [1:0] note_number;
    wire cue_on, scored_led, hit_event;
    wire [3:0] score;
    assign Resetn = KEY[1];
    assign begin_state = (state == 2'd0);
    assign playing = (state == 2'd1);


    input_controller #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) INPUTS (
    .Clock(CLOCK_50), .Resetn(Resetn),
    .StartKeyn(KEY[2]), .Hitkeyn(KEY[0]),
    .StartPulse(StartPulse), .PressPulse(PressPulse)
    );

    gameFSM FSM (
        .Clock(CLOCK_50), .Resetn(Resetn),
        .Start(StartPulse), .timeup(time_up), .state(state)
    );

    game_timer #(
        .HALF_SEC_CYCLES(HALF_SEC_CYCLES),
        .HALFSTEP(GAME_HALF_STEPS)
    ) TIMER (
        .Clock(CLOCK_50), .Resetn(Resetn),
        .Clear(begin_state), .Playing(playing),
        .halfstep(half_step), .timeup(time_up)
    );

    note_scheduler SCHEDULER (
        .Playing(playing), .halfstep(half_step),
        .note_num(note_number), .cueon(cue_on)
    );

    hit_detector DETECTOR (
        .Clock(CLOCK_50), .Resetn(Resetn),
        .Clear(begin_state), .Playing(playing),
        .PressPulse(PressPulse), .cueon(cue_on),
        .note(note_number),
        .hit(hit_event), .score_led(scored_led)
    );

    score_register SCORE (
        .Clock(CLOCK_50), .Resetn(Resetn),
        .Clear(begin_state), .hit(hit_event), .score(score)
    );

    audio_demo AUDIO (
    .CLOCK_50(CLOCK_50),

    // KEY[3:2] unused; KEY[1] enables playback;
    // KEY[0] -> reset
    .KEY({2'b11, playing, Resetn}),
    .SW(4'b0000),

    .AUD_ADCDAT(AUD_ADCDAT),
    .AUD_BCLK(AUD_BCLK),
    .AUD_ADCLRCK(AUD_ADCLRCK),
    .AUD_DACLRCK(AUD_DACLRCK),
    .FPGA_I2C_SDAT(FPGA_I2C_SDAT),
    .AUD_XCK(AUD_XCK),
    .AUD_DACDAT(AUD_DACDAT),
    .FPGA_I2C_SCLK(FPGA_I2C_SCLK)
);

    assign LEDR = {scored_led, 8'b00000000, cue_on};

    wire [7:0] seconds_left;
    wire [3:0] seconds_tens, seconds_ones;
    assign seconds_left = (half_step >= GAME_HALF_STEPS) ? 8'd0 :
                          ((GAME_HALF_STEPS - half_step + 8'd1) >> 1);
    assign seconds_tens = seconds_left / 8'd10;
    assign seconds_ones = seconds_left % 8'd10;

    hex7 STATE_HEX (.value({2'b00, state}), .seg(HEX5));
    hex7 TENS_HEX  (.value(playing ? seconds_tens : 4'hF), .seg(HEX4));
    hex7 ONES_HEX  (.value(playing ? seconds_ones : 4'hF), .seg(HEX3));
    hex7 SCORE_HEX (.value((state == 2'd2) ? score : 4'hF), .seg(HEX0));
    assign HEX2 = 7'b1111111;
    assign HEX1 = 7'b1111111;
endmodule











module hex7 (
    input wire [3:0] value,
    output reg [6:0] seg
);
    always @(*) begin
        case (value)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;
        endcase
    end
endmodule





//=====================================================================================


module gameFSM(

    input Clock, Resetn, Start, timeup,
    output reg [1:0] state
);
    localparam [1:0] BEGIN_STATE = 2'd0,
                    PLAY_STATE = 2'd1,
                    END_STATE= 2'd2;

    always @(posedge Clock or negedge Resetn)
    begin
        if (!Resetn)
            state <= BEGIN_STATE;
        else
        begin
            case (state)
                BEGIN_STATE: if (Start) state <= PLAY_STATE;

                PLAY_STATE: if (timeup) state <= END_STATE;

                END_STATE:if (Start) state <= BEGIN_STATE;

                default: state <= BEGIN_STATE;
            endcase
        end
    end

endmodule

//=====================================================================================


module button_pulse #(parameter [31:0] DEBOUNCE_CYCLES = 32'd500000)(
    input wire Clock, Resetn, Keyn,
    output reg Pulse
);
    reg sync1, sync2, stable;
    reg[31:0] debounce;

    always @(posedge Clock or negedge Resetn) begin
        if(!Resetn) begin
            sync1 <= 1'b1;
            sync2 <= 1'b1;
            stable <= 1'b1;
            debounce <= 32'd0;
            Pulse <= 1'b0;
        end else begin
            sync1 <= Keyn;
            sync2 <= sync1;
            Pulse <= 1'b0;
            if (sync2 == stable) begin
                debounce <= 32'd0;
            end else if (debounce == DEBOUNCE_CYCLES - 32'd1) begin
                stable <= sync2;
                debounce <= 32'd0;
                if (!sync2)
                    Pulse <= 1'b1;
            end else begin
                    debounce <= debounce + 32'd1;
            end
        end

    end
endmodule



//=====================================================================================

module hit_detector(
    input wire Clock, Resetn, Clear, Playing, PressPulse, cueon,
    input wire [1:0] note,
    output wire hit, score_led
);
    reg[1:0] previous_note;
    reg hit_this;
    assign hit = Playing && cueon && PressPulse && !hit_this;
    assign score_led = Playing && cueon && hit_this;

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            previous_note <= 2'd0;
            hit_this <= 1'b0;

        end else if (Clear) begin
            previous_note <= 2'd0;
            hit_this <= 1'b0;
        end else if (Playing )begin
            if (note != previous_note)begin
                previous_note <= note;
                hit_this <= 1'b0;
               
            end else if (hit )begin
                hit_this <= 1'b1;
            end
        end
    end

endmodule


//=====================================================================================

module score_register(
    input wire Clock, Resetn, Clear, hit,
    output reg [3:0] score

);
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            score <= 4'd0;
        else if (Clear)
            score <= 4'd0;
        else if (hit && score < 4'd3)
            score <= score + 4'd1;
    end
endmodule




//=====================================================================================


module game_timer #(
    parameter [31:0] HALF_SEC_CYCLES = 32'd25000000,
    parameter [7:0] HALFSTEP = 8'd12
)(
    input wire Clock, Resetn, Clear, Playing,
    output reg [7:0] halfstep,
    output wire timeup
);
    reg [31:0] count;

    assign timeup = (halfstep >= HALFSTEP);

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            count <= 32'd0;
            halfstep <= 8'd0;
        end
        else if (Clear) begin
            count <= 32'd0;
            halfstep <= 8'd0;
        end
        else if (Playing && !timeup) begin
            if (count == HALF_SEC_CYCLES - 32'd1) begin
                count <= 32'd0;
                halfstep <= halfstep + 8'd1;
            end
            else begin
                count <= count + 32'd1;
            end
        end
    end
endmodule

//=====================================================================================


module note_scheduler(
    input wire Playing,
    input wire [7:0] halfstep,
    output wire [1:0] note_num,
    output wire cueon

);
    assign note_num = halfstep[3:2];
    assign cueon = Playing && (halfstep < 8'd12) && ((halfstep[1:0] == 2'd1) || (halfstep[1:0] == 2'd2));
endmodule


//=====================================================================================

module input_controller #(
    parameter [31:0] DEBOUNCE_CYCLES = 32'd500000
)(
    input wire Clock, Resetn, StartKeyn, Hitkeyn,
    output wire StartPulse, PressPulse
);

    button_pulse #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) START_BUTTON (
        .Clock(Clock),
        .Resetn(Resetn),
        .Keyn(StartKeyn),
        .Pulse(StartPulse)
    );

    button_pulse #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) HIT_BUTTON (
        .Clock(Clock),
        .Resetn(Resetn),
        .Keyn(Hitkeyn),
        .Pulse(PressPulse)
    );

endmodule
