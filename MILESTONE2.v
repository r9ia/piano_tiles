// ============================================================================
// ECE241 MILESTONE 2 -- engine-driven H/J/K/L rhythm game, 3 lives
// All gameplay and song_rom modules are in THIS ONE SOURCE FILE.
// Do NOT add a separate song_rom.v or any older MILESTONE2 variant.
// External dependencies: vga_adapter, intel_sound, Audio_Controller, avconf,
// audio memory initialization assets, and correct DE1-SoC pin assignments.
// Game states: BEGIN=0 PLAYING=1 END=2 GAME_OVER=3.
// Valid hits: tile rectangle must overlap the hit line + matching H/J/K/L.
// A 51-pixel tile falls 1 logical pixel / 10ms: 0.5s hit window.
// Success: freeze tile in place as white for 150ms, then remove.
// Miss: lose one life after passing the line; continue falling off-screen.
// 46-second Miku WAV; the note chart is ILLUSTRATIVE, not transcribed.
// VGA framebuffer: 320x240, COLOR_DEPTH=3, original 160x120 art scaled 2x.
// ============================================================================

// -------------------- MILESTONE2 --------------------
// DE1-SoC top-level. Requires course VGA adapter and external audio IP.
// KEY[1] active-low reset; KEY[2] active-low start; keyboard H/J/K/L.
module MILESTONE2 #(
    parameter [31:0] CYCLES_PER_TICK = 32'd500000, // 10ms at 50MHz
    parameter [15:0] SONG_TICKS = 16'd4600,       // 46 seconds
    parameter USE_AUDIO_TIME = 0,                // enable ONLY after audio sync verification
    parameter [6:0] TILE_H = 7'd51,
    parameter [6:0] HIT_LINE_Y = 7'd96,
    parameter [15:0] HIT_FREEZE_TICKS = 16'd15
)(
    input wire CLOCK_50,
    input wire [3:0] KEY,
    inout wire PS2_CLK, PS2_DAT,
    output wire [9:0] LEDR,
    output wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    output wire [7:0] VGA_R, VGA_G, VGA_B,
    output wire VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK,
    input wire AUD_ADCDAT,
    inout wire AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, FPGA_I2C_SDAT,
    output wire AUD_XCK, AUD_DACDAT, FPGA_I2C_SCLK
);
    wire Resetn = KEY[1];
    wire start_pulse;
    button_pulse START_KEY (.Clock(CLOCK_50), .Resetn(Resetn),
                            .Keyn(KEY[2]), .Pulse(start_pulse));

    wire [7:0] scan_code;
    wire scan_valid;
    ps2_receiver PS2 (
        .Clock(CLOCK_50), .Resetn(Resetn),
        .ps2_clk(PS2_CLK), .ps2_data(PS2_DAT),
        .scan_code(scan_code), .scan_valid(scan_valid)
    );

    wire [17:0] audio_sample_index;
    wire [1:0] game_state, lives;
    wire [15:0] song_tick;
    wire [3:0] lane_press, hit_flash;
    wire [7:0] tile_visible, tile_hittable, tile_white;
    wire [8:0] next_note_index;
    wire [15:0] tile_lanes;
    wire [55:0] tile_ys;
    wire [127:0] tile_targets;
    wire [11:0] score;
    wire miss_event, invalid_press_event;

    MILESTONE2_CORE #(
        .CYCLES_PER_TICK(CYCLES_PER_TICK),
        .SONG_TICKS(SONG_TICKS),
        .USE_AUDIO_TIME(USE_AUDIO_TIME),
        .TILE_H(TILE_H), .HIT_LINE_Y(HIT_LINE_Y),
        .HIT_FREEZE_TICKS(HIT_FREEZE_TICKS)
    ) GAME (
        .CLOCK_50(CLOCK_50), .Resetn(Resetn), .StartPulse(start_pulse),
        .scan_code(scan_code), .scan_valid(scan_valid),
        .audio_sample_index(audio_sample_index),
        .game_state(game_state), .song_tick(song_tick),
        .lane_press(lane_press), .tile_visible(tile_visible),
        .tile_hittable(tile_hittable), .tile_white(tile_white),
        .tile_lanes(tile_lanes), .tile_ys(tile_ys),
        .tile_targets(tile_targets), .score(score),
        .lives(lives), .invalid_press_event(invalid_press_event),
        .hit_flash(hit_flash), .miss_event(miss_event),
        .next_note_index(next_note_index)
    );

    wire [8:0] pixel_x;
    wire [7:0] pixel_y;
    wire [2:0] pixel_colour;
    wire pixel_plot;
    graphics_renderer #(.TILE_H(TILE_H), .HIT_LINE_Y(HIT_LINE_Y)) GRAPHICS (
        .Clock(CLOCK_50), .Resetn(Resetn), .state(game_state), .lives(lives),
        .tile_visible(tile_visible), .tile_white(tile_white),
        .tile_lanes(tile_lanes), .tile_ys(tile_ys), .hit_flash(hit_flash),
        .x(pixel_x), .y(pixel_y), .colour(pixel_colour), .plot(pixel_plot)
    );
    // Verified against the Quercus vga_adapter.v supplied by the student.
    // Port write is the input; writeEn is an INTERNAL signal in the adapter.
    vga_adapter VGA (
        .resetn(Resetn), .clock(CLOCK_50),
        .color(pixel_colour), .x(pixel_x), .y(pixel_y), .write(pixel_plot),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );
    defparam VGA.RESOLUTION = "320x240";
    defparam VGA.COLOR_DEPTH = 3;
    defparam VGA.BACKGROUND_IMAGE = "vga_adapter/black.mif";

    audio_miku #(.SONG_SAMPLES(220800)) AUDIO_PLAYER (
        .CLOCK_50(CLOCK_50), .Resetn(Resetn),
        .StartPulse(start_pulse && (game_state == 2'd0)),
        .Playing(game_state == 2'd1),
        .AUD_ADCDAT(AUD_ADCDAT), .AUD_BCLK(AUD_BCLK),
        .AUD_ADCLRCK(AUD_ADCLRCK), .AUD_DACLRCK(AUD_DACLRCK),
        .FPGA_I2C_SDAT(FPGA_I2C_SDAT), .AUD_XCK(AUD_XCK),
        .AUD_DACDAT(AUD_DACDAT), .FPGA_I2C_SCLK(FPGA_I2C_SCLK),
        .sample_index(audio_sample_index)
    );

    wire [15:0] remain_ticks = (song_tick >= SONG_TICKS) ? 16'd0 : SONG_TICKS-song_tick;
    wire [7:0] remaining_seconds = (remain_ticks + 16'd99) / 16'd100;
    wire [3:0] second_tens = remaining_seconds / 8'd10;
    wire [3:0] second_ones = remaining_seconds % 8'd10;
    hex7 S (.value({2'b00, game_state}), .seg(HEX5));
    hex7 T (.value((game_state == 2'd1) ? second_tens : 4'hF), .seg(HEX4));
    hex7 O (.value((game_state == 2'd1) ? second_ones : 4'hF), .seg(HEX3));
    wire [11:0] score_display = (score > 12'd999) ? 12'd999 : score;
    wire [3:0] score_hundreds = score_display / 12'd100;
    wire [3:0] score_tens = (score_display / 12'd10) % 12'd10;
    wire [3:0] score_ones = score_display % 12'd10;
    hex7 SH (.value(score_hundreds), .seg(HEX2));
    hex7 SL (.value(score_tens), .seg(HEX1));
    hex7 SO (.value(score_ones), .seg(HEX0));

    // LEDR[9]=hit, [8]=bad press, [7]=miss, [6:3]=H/J/K/L, [2:0]=lives
    assign LEDR = {(|hit_flash), invalid_press_event, miss_event,
                   lane_press, (lives >= 2'd1), (lives >= 2'd2), (lives >= 2'd3)};
endmodule

// -------------------- MILESTONE2_CORE --------------------
// Complete gameplay engine. Can be simulated without VGA or audio vendor IP.
// Hit detector uses the same tile top + height as the VGA renderer.
// It checks engine geometry, not framebuffer pixels. No duplicate timing window.
module MILESTONE2_CORE #(
    parameter [31:0] CYCLES_PER_TICK = 32'd500000,
    parameter [15:0] SONG_TICKS = 16'd5000,
    parameter USE_AUDIO_TIME = 0,
    parameter [6:0] TILE_H = 7'd51,
    parameter [6:0] HIT_LINE_Y = 7'd96,
    parameter [15:0] HIT_FREEZE_TICKS = 16'd15,
    parameter PENALIZE_INVALID_PRESSES = 1,
    parameter PENALIZE_MISSES = 1
)(
    input wire CLOCK_50, Resetn, StartPulse,
    input wire [7:0] scan_code,
    input wire scan_valid,
    input wire [17:0] audio_sample_index,
    output wire [1:0] game_state,
    output wire [15:0] song_tick,
    output wire [3:0] lane_press,
    output wire [7:0] tile_visible,
    output wire [7:0] tile_hittable, tile_white,
    output wire [15:0] tile_lanes,
    output wire [55:0] tile_ys,
    output wire [127:0] tile_targets,
    output wire [11:0] score,
    output wire [1:0] lives,
    output wire [3:0] hit_flash,
    output wire miss_event,
    output wire invalid_press_event,
    output wire [8:0] next_note_index
);
    wire begin_state = (game_state == 2'd0);
    wire playing = (game_state == 2'd1);
    wire [15:0] local_tick;
    wire local_tick_pulse, local_timeup;
    wire [3:0] held;
    wire [7:0] hit_mask;
    wire [2:0] hit_count;
    wire [3:0] successful_lanes;
    wire [15:0] external_tick = audio_sample_index / 18'd48;
    wire actual_time_up = (USE_AUDIO_TIME != 0) ?
        (audio_sample_index >= (SONG_TICKS * 32'd48 - 32'd1)) : local_timeup;
    assign song_tick = (USE_AUDIO_TIME != 0) ? external_tick : local_tick;

    // Wait for on-screen tiles to finish falling/fading before leaving PLAY:
    // both normal song END and GAME_OVER keep the final miss visible.
    wire no_lives = (lives == 2'd0);
    gameFSM FSM (.Clock(CLOCK_50), .Resetn(Resetn),
                 .Start(StartPulse),
                 .timeup(actual_time_up && !no_lives &&
                         (tile_visible == 8'd0)),
                 .lives_zero(no_lives && (tile_visible == 8'd0)),
                 .state(game_state));
    song_timebase #(.CYCLES_PER_TICK(CYCLES_PER_TICK), .SONG_TICKS(SONG_TICKS)) TIMER (
        .Clock(CLOCK_50), .Resetn(Resetn), .Clear(begin_state), .Playing(playing),
        .ContinueAfterTimeup(no_lives || (tile_visible != 8'd0)),
        .song_tick(local_tick), .tick_pulse(local_tick_pulse), .timeup(local_timeup)
    );
    keyboard_decoder KEYBOARD (
        .Clock(CLOCK_50), .Resetn(Resetn), .scan_code(scan_code),
        .scan_valid(scan_valid), .lane_press(lane_press), .held(held)
    );
    tile_manager #(.TILE_H(TILE_H), .HIT_LINE_Y(HIT_LINE_Y),
                   .HIT_FREEZE_TICKS(HIT_FREEZE_TICKS)) TILES (
        .Clock(CLOCK_50), .Resetn(Resetn), .Clear(begin_state), .Playing(playing),
        .song_tick(song_tick), .hit_mask(hit_mask),
        .SpawnEnable(!no_lives && !actual_time_up),
        .tile_visible(tile_visible), .tile_hittable(tile_hittable),
        .tile_white(tile_white), .tile_lanes(tile_lanes),
        .tile_ys(tile_ys), .tile_targets(tile_targets),
        .miss_event(miss_event), .next_note_index(next_note_index)
    );
    hit_detector #(.TILE_H(TILE_H), .HIT_LINE_Y(HIT_LINE_Y)) HITS (
        .Playing(playing && !no_lives), .song_tick(song_tick),
        .lane_press(lane_press), .tile_hittable(tile_hittable),
        .tile_lanes(tile_lanes), .tile_ys(tile_ys), .tile_targets(tile_targets),
        .hit_mask(hit_mask), .hit_count(hit_count),
        .successful_lanes(successful_lanes)
    );
    assign invalid_press_event = playing && !no_lives &&
                                 (|(lane_press & ~successful_lanes));
    wire penalty_event = playing &&
        (((PENALIZE_INVALID_PRESSES != 0) && invalid_press_event) ||
         ((PENALIZE_MISSES != 0) && miss_event));

    life_register LIVES (.Clock(CLOCK_50), .Resetn(Resetn), .Clear(begin_state),
                         .Penalty(penalty_event), .lives(lives));
    score_register SCORES (
        .Clock(CLOCK_50), .Resetn(Resetn), .Clear(begin_state),
        .hit_count(hit_count), .score(score)
    );

    // VGA feedback only; use the SAME song clock source as gameplay.
    reg [15:0] last_visual_tick;
    wire visual_tick_pulse = (song_tick != last_visual_tick);
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) last_visual_tick <= 16'd0;
        else if (begin_state) last_visual_tick <= 16'd0;
        else last_visual_tick <= song_tick;
    end

    reg [3:0] flash_counter [0:3];
    genvar g;
    generate for (g=0; g<4; g=g+1) begin: HIT_FEEDBACK
        assign hit_flash[g] = (flash_counter[g] != 0);
        always @(posedge CLOCK_50 or negedge Resetn) begin
            if (!Resetn) flash_counter[g] <= 4'd0;
            else if (begin_state) flash_counter[g] <= 4'd0;
            else if (successful_lanes[g]) flash_counter[g] <= 4'd10;
            else if (visual_tick_pulse && flash_counter[g] != 0)
                flash_counter[g] <= flash_counter[g] - 1'b1;
        end
    end endgenerate
endmodule

// -------------------- gameFSM --------------------
// 4-state FSM: start, play, finish, game over (three lives lost).
// START from END or GAME_OVER returns to BEGIN; next START begins another game.
module gameFSM (
    input wire Clock, Resetn, Start, timeup, lives_zero,
    output reg [1:0] state
);
    localparam [1:0] BEGIN_STATE = 2'd0,
                     PLAY_STATE = 2'd1,
                     END_STATE = 2'd2,
                     GAME_OVER_STATE = 2'd3;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) state <= BEGIN_STATE;
        else case (state)
            BEGIN_STATE: if (Start) state <= PLAY_STATE;
            PLAY_STATE: if (lives_zero) state <= GAME_OVER_STATE;
                        else if (timeup) state <= END_STATE;
            END_STATE: if (Start) state <= BEGIN_STATE;
            GAME_OVER_STATE: if (Start) state <= BEGIN_STATE;
            default: state <= BEGIN_STATE;
        endcase
    end
endmodule

// -------------------- button_pulse --------------------
module button_pulse #(
    parameter [31:0] DEBOUNCE_CYCLES = 32'd500000
)(
    input wire Clock, Resetn, Keyn,
    output reg Pulse
);
    reg sync1, sync2, stable;
    reg [31:0] debounce;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            sync1 <= 1'b1; sync2 <= 1'b1; stable <= 1'b1;
            debounce <= 32'd0; Pulse <= 1'b0;
        end else begin
            sync1 <= Keyn; sync2 <= sync1; Pulse <= 1'b0;
            if (sync2 == stable) debounce <= 32'd0;
            else if (debounce == DEBOUNCE_CYCLES - 1'b1) begin
                stable <= sync2; debounce <= 32'd0;
                if (!sync2) Pulse <= 1'b1;
            end else debounce <= debounce + 1'b1;
        end
    end
endmodule

// -------------------- ps2_receiver --------------------
module ps2_receiver (
    input wire Clock, Resetn,
    input wire ps2_clk, ps2_data,
    output reg [7:0] scan_code,
    output reg scan_valid
);
    reg [7:0] clk_history;
    reg filtered_clk, filtered_clk_d;
    reg data_sync1, data_sync2;
    reg [3:0] bit_count;
    reg [7:0] data_bits;
    reg parity_bit;
    reg [19:0] idle_count;
    wire negedge_ps2 = filtered_clk_d && !filtered_clk;

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            clk_history <= 8'hFF; filtered_clk <= 1'b1;
            filtered_clk_d <= 1'b1; data_sync1 <= 1'b1;
            data_sync2 <= 1'b1; bit_count <= 0;
            data_bits <= 0; parity_bit <= 0;
            scan_code <= 0; scan_valid <= 0; idle_count <= 0;
        end else begin
            data_sync1 <= ps2_data;
            data_sync2 <= data_sync1;
            clk_history <= {clk_history[6:0], ps2_clk};
            if (clk_history == 8'hFF) filtered_clk <= 1'b1;
            else if (clk_history == 8'h00) filtered_clk <= 1'b0;
            filtered_clk_d <= filtered_clk;
            scan_valid <= 0;
            if (negedge_ps2) begin
                idle_count <= 0;
                case (bit_count)
                    4'd0: if (!data_sync2) bit_count <= 1;
                    4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,4'd8: begin
                        data_bits[bit_count-1'b1] <= data_sync2;
                        bit_count <= bit_count + 1'b1;
                    end
                    4'd9: begin parity_bit <= data_sync2; bit_count <= 10; end
                    4'd10: begin
                        if (data_sync2 && ((^data_bits) ^ parity_bit)) begin
                            scan_code <= data_bits;
                            scan_valid <= 1;
                        end
                        bit_count <= 0;
                    end
                    default: bit_count <= 0;
                endcase
            end else if (idle_count == 20'd999999) begin
                idle_count <= 0; bit_count <= 0; // incomplete PS/2 packet timeout
            end else idle_count <= idle_count + 1'b1;
        end
    end
endmodule

// -------------------- keyboard_decoder --------------------
module keyboard_decoder (
    input wire Clock, Resetn,
    input wire [7:0] scan_code,
    input wire scan_valid,
    output reg [3:0] lane_press,
    output reg [3:0] held
);
    reg break_prefix;
    reg extended_prefix;
    reg [3:0] decoded;
    always @(*) begin
        case (scan_code)
            8'h33: decoded = 4'b0001; // H
            8'h3B: decoded = 4'b0010; // J
            8'h42: decoded = 4'b0100; // K
            8'h4B: decoded = 4'b1000; // L
            default: decoded = 4'b0000;
        endcase
    end
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            lane_press <= 0; held <= 0;
            break_prefix <= 0; extended_prefix <= 0;
        end else begin
            lane_press <= 0;
            if (scan_valid) begin
                if (scan_code == 8'hE0) extended_prefix <= 1;
                else if (scan_code == 8'hF0) break_prefix <= 1;
                else begin
                    if (!extended_prefix && decoded != 0) begin
                        if (break_prefix) held <= held & ~decoded;
                        else if ((held & decoded) == 0) begin
                            lane_press <= decoded;
                            held <= held | decoded;
                        end
                    end
                    break_prefix <= 0;
                    extended_prefix <= 0;
                end
            end
        end
    end
endmodule

// -------------------- song_timebase --------------------
module song_timebase #(
    parameter [31:0] CYCLES_PER_TICK = 32'd500000,
    parameter [15:0] SONG_TICKS = 16'd5000
)(
    input wire Clock, Resetn, Clear, Playing, ContinueAfterTimeup,
    output reg [15:0] song_tick,
    output reg tick_pulse,
    output wire timeup
);
    reg [31:0] divider;
    assign timeup = song_tick >= SONG_TICKS;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            divider <= 0; song_tick <= 0; tick_pulse <= 0;
        end else if (Clear) begin
            divider <= 0; song_tick <= 0; tick_pulse <= 0;
        end else begin
            tick_pulse <= 0;
            if (Playing && (!timeup || ContinueAfterTimeup)) begin
                if (divider == CYCLES_PER_TICK - 1'b1) begin
                    divider <= 0;
                    song_tick <= song_tick + 1'b1;
                    tick_pulse <= 1'b1;
                end else divider <= divider + 1'b1;
            end
        end
    end
endmodule

// -------------------- tile_manager --------------------
// Each slot has 3 visual/game phases:
// 1. ACTIVE: falling colored tile, hittable while its rectangle intersects
//    the horizontal hit line (the hit_detector checks the same geometry).
// 2a. HIT: freeze at the exact hit position, turn WHITE, retain dimensions,
//     then disappear after HIT_FREEZE_TICKS.
// 2b. MISSED: no longer hittable and penalty sent ONCE; keep falling until
//     the tile's TOP is past the bottom edge of the 120-pixel logical screen.
// tile_visible means occupying/rendering a slot, not necessarily hittable.
module tile_manager #(
    parameter [6:0] SPAWN_Y = 7'd8,
    parameter [6:0] HIT_LINE_Y = 7'd96,
    parameter [6:0] TILE_H = 7'd51,
    parameter [15:0] HIT_FREEZE_TICKS = 16'd15, // 150 ms
    parameter [6:0] TARGET_Y = HIT_LINE_Y - TILE_H / 7'd2,
    parameter [15:0] FALL_TICKS = TARGET_Y - SPAWN_Y
)(
    input wire Clock, Resetn, Clear, Playing, SpawnEnable,
    input wire [15:0] song_tick,
    input wire [7:0] hit_mask,
    output reg [7:0] tile_visible,
    output wire [7:0] tile_hittable,
    output wire [7:0] tile_white,
    output reg [15:0] tile_lanes,
    output reg [55:0] tile_ys,
    output reg [127:0] tile_targets,
    output reg miss_event,
    output reg [8:0] next_note_index
);
    localparam [6:0] LOGICAL_SCREEN_H = 7'd120;
    reg [7:0] was_hit, was_missed;
    reg [6:0] hit_y [0:7];
    reg [15:0] hit_at_tick [0:7];
    reg [15:0] saved_target [0:7];
    reg [1:0] saved_lane [0:7];
    assign tile_hittable = tile_visible & ~was_hit & ~was_missed;
    assign tile_white = tile_visible & was_hit;

    wire [15:0] next_target;
    wire [1:0] next_lane;
    wire next_valid;
    wire [8:0] note_count;
    song_rom SONG (
        .note_index(next_note_index),
        .target_tick(next_target), .lane(next_lane),
        .valid(next_valid), .note_count(note_count)
    );

    reg free_found;
    reg [2:0] free_slot;
    integer i;
    always @(*) begin
        free_found = 1'b0;
        free_slot = 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!free_found && !tile_visible[i]) begin
                free_found = 1'b1;
                free_slot = i[2:0];
            end
        end
    end

    wire [15:0] next_spawn = (next_target > FALL_TICKS) ?
                            (next_target - FALL_TICKS) : 16'd0;

    // Unhit tiles continue moving even AFTER the note is missed.
    // Compute in 17 bits to avoid wrap at the bottom; 120 means off-screen.
    integer j;
    reg [16:0] advanced_pixels;
    reg [16:0] full_top;
    always @(*) begin
        tile_lanes = 16'd0;
        tile_ys = 56'd0;
        tile_targets = 128'd0;
        advanced_pixels = 17'd0;
        full_top = 17'd0;
        for (j = 0; j < 8; j = j + 1) begin
            tile_lanes[j*2 +: 2] = saved_lane[j];
            tile_targets[j*16 +: 16] = saved_target[j];
            if (tile_visible[j]) begin
                if (was_hit[j]) begin
                    tile_ys[j*7 +: 7] = hit_y[j];
                end else if ({1'b0, song_tick} + {1'b0, FALL_TICKS}
                             <= {1'b0, saved_target[j]}) begin
                    tile_ys[j*7 +: 7] = SPAWN_Y;
                end else begin
                    advanced_pixels = ({1'b0, song_tick} + {1'b0, FALL_TICKS})
                                      - {1'b0, saved_target[j]};
                    full_top = {10'd0, SPAWN_Y} + advanced_pixels;
                    if (full_top >= {10'd0, LOGICAL_SCREEN_H})
                        tile_ys[j*7 +: 7] = LOGICAL_SCREEN_H;
                    else
                        tile_ys[j*7 +: 7] = full_top[6:0];
                end
            end
        end
    end

    integer k;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            tile_visible <= 8'd0;
            was_hit <= 8'd0;
            was_missed <= 8'd0;
            next_note_index <= 9'd0;
            miss_event <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                saved_target[k] <= 16'd0;
                saved_lane[k] <= 2'd0;
                hit_y[k] <= 7'd0;
                hit_at_tick[k] <= 16'd0;
            end
        end else if (Clear) begin
            tile_visible <= 8'd0;
            was_hit <= 8'd0;
            was_missed <= 8'd0;
            next_note_index <= 9'd0;
            miss_event <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                saved_target[k] <= 16'd0;
                saved_lane[k] <= 2'd0;
                hit_y[k] <= 7'd0;
                hit_at_tick[k] <= 16'd0;
            end
        end else begin
            miss_event <= 1'b0;
            if (Playing) begin
                for (k = 0; k < 8; k = k + 1) begin
                    if (tile_visible[k]) begin
                        if (was_hit[k]) begin
                            if ({1'b0, song_tick} >=
                                ({1'b0, hit_at_tick[k]} + {1'b0, HIT_FREEZE_TICKS})) begin
                                tile_visible[k] <= 1'b0;
                                was_hit[k] <= 1'b0;
                            end
                        end else if (hit_mask[k]) begin
                            // Latch current top; pixel dimensions remain unchanged.
                            was_hit[k] <= 1'b1;
                            hit_y[k] <= tile_ys[k*7 +: 7];
                            hit_at_tick[k] <= song_tick;
                        end else if (!was_missed[k] &&
                                     tile_ys[k*7 +: 7] > HIT_LINE_Y) begin
                            // The top has passed the hit line; all overlap is gone.
                            was_missed[k] <= 1'b1;
                            miss_event <= 1'b1;
                        end else if (was_missed[k] &&
                                     tile_ys[k*7 +: 7] >= LOGICAL_SCREEN_H) begin
                            // Last visible pixel has fallen beyond the screen.
                            was_missed[k] <= 1'b0;
                            tile_visible[k] <= 1'b0;
                        end
                    end
                end
                // ROM entries are assigned to free slots as they reach spawn time.
                if (SpawnEnable && next_valid && free_found &&
                    song_tick >= next_spawn) begin
                    tile_visible[free_slot] <= 1'b1;
                    was_hit[free_slot] <= 1'b0;
                    was_missed[free_slot] <= 1'b0;
                    saved_lane[free_slot] <= next_lane;
                    saved_target[free_slot] <= next_target;
                    hit_y[free_slot] <= 7'd0;
                    hit_at_tick[free_slot] <= 16'd0;
                    next_note_index <= next_note_index + 1'b1;
                end
            end
        end
    end
endmodule

// -------------------- hit_detector --------------------
// Collision is defined from the SAME top coordinate + height rendered on VGA.
// A tile can be scored any time its body overlaps the hit line, including its
// first/last overlapping pixels. Tile position comes from the game engine,
// never from sampling framebuffer output.
module hit_detector #(
    parameter [6:0] TILE_H = 7'd51,
    parameter [6:0] HIT_LINE_Y = 7'd96
)(
    input wire Playing,
    input wire [15:0] song_tick,  // retained for interface/debugging
    input wire [3:0] lane_press,
    input wire [7:0] tile_hittable,
    input wire [15:0] tile_lanes,
    input wire [55:0] tile_ys,
    input wire [127:0] tile_targets, // retained for interface/debugging
    output reg [7:0] hit_mask,
    output reg [2:0] hit_count,
    output reg [3:0] successful_lanes
);
    integer i;
    reg [1:0] current_lane;
    reg [6:0] tile_top;
    reg [7:0] tile_bottom_exclusive;
    reg line_overlaps;
    always @(*) begin
        hit_mask = 8'd0;
        hit_count = 3'd0;
        successful_lanes = 4'd0;
        current_lane = 2'd0;
        tile_top = 7'd0;
        tile_bottom_exclusive = 8'd0;
        line_overlaps = 1'b0;
        if (Playing) begin
            for (i = 0; i < 8; i = i + 1) begin
                current_lane = tile_lanes[i*2 +: 2];
                tile_top = tile_ys[i*7 +: 7];
                tile_bottom_exclusive = {1'b0, tile_top} + {1'b0, TILE_H};
                line_overlaps = (tile_top <= HIT_LINE_Y) &&
                                (tile_bottom_exclusive > {1'b0, HIT_LINE_Y});
                if (tile_hittable[i] && line_overlaps &&
                    lane_press[current_lane] && !successful_lanes[current_lane]) begin
                    hit_mask[i] = 1'b1;
                    successful_lanes[current_lane] = 1'b1;
                    hit_count = hit_count + 3'd1;
                end
            end
        end
    end
endmodule

// -------------------- life_register --------------------
// One penalty event costs one life. Reset/BEGIN restores 3 lives.
// Simultaneous invalid presses or missed notes cost at most one life per clock.
module life_register (
    input wire Clock, Resetn, Clear, Penalty,
    output reg [1:0] lives
);
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) lives <= 2'd3;
        else if (Clear) lives <= 2'd3;
        else if (Penalty && lives != 2'd0) lives <= lives - 1'b1;
    end
endmodule

// -------------------- score_register --------------------
module score_register (
    input wire Clock, Resetn, Clear,
    input wire [2:0] hit_count,
    output reg [11:0] score
);
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) score <= 0;
        else if (Clear) score <= 0;
        else if (hit_count != 0) score <= score + hit_count;
    end
endmodule

// -------------------- graphics_renderer --------------------
module graphics_renderer #(
    parameter [6:0] TILE_H = 7'd51,
    parameter [6:0] HIT_LINE_Y = 7'd96
) (
    input wire Clock, Resetn,
    input wire [1:0] state, lives,
    input wire [7:0] tile_visible, tile_white,
    input wire [15:0] tile_lanes,
    input wire [55:0] tile_ys,
    input wire [3:0] hit_flash,
    output reg [8:0] x,
    output reg [7:0] y,
    output reg [2:0] colour,
    output wire plot
);
    localparam [8:0] SCREEN_W = 9'd320;
    localparam [7:0] SCREEN_H = 8'd240;
    localparam [7:0] LANE_W = 8'd40;
    localparam [7:0] TILE_W = 8'd32;
    assign plot = 1'b1;

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin x <= 0; y <= 0; end
        else if (x == SCREEN_W-1'b1) begin
            x <= 0;
            if (y == SCREEN_H-1'b1) y <= 0;
            else y <= y + 1'b1;
        end else x <= x + 1'b1;
    end

    // VGA framebuffer is 320x240; draw the original game at 2x scale.
    // This preserves the tile falling time and all original hit timing.
    wire [7:0] draw_x = x[8:1];
    wire [6:0] draw_y = y[7:1];

    integer i;
    reg [1:0] lane;
    reg [6:0] tile_top;
    reg [7:0] tile_bottom_exclusive;
    reg [7:0] left_edge;
    always @(*) begin
        // 3-bit RGB: 100 red, 010 green, 001 blue, 111 white
        colour = 3'b000;
        lane = 0;
        tile_top = 0;
        tile_bottom_exclusive = 0;
        left_edge = 0;
        case (state)
            2'd0: begin // BEGIN: graphic panel, start with KEY2
                colour = (draw_x[4] ^ draw_y[4]) ? 3'b001 : 3'b000;
                if (draw_x>=8'd36 && draw_x<8'd124 && draw_y>=7'd38 && draw_y<7'd82)
                    colour = 3'b011;
                if (draw_x>=8'd40 && draw_x<8'd120 && draw_y>=7'd42 && draw_y<7'd78)
                    colour = 3'b000;
                if (draw_x>=8'd57 && draw_x<8'd103 && draw_y>=7'd56 && draw_y<7'd64)
                    colour = 3'b110; // yellow start graphic (HEX5 indicates state)
            end
            2'd1: begin // PLAYING
                // Alternating lanes + edges (only 3-bit colour available)
                colour = draw_x[5] ? 3'b001 : 3'b000;
                if (draw_x>=8'd40 && draw_x<8'd80) colour = 3'b000;
                if (draw_x>=8'd80 && draw_x<8'd120) colour = 3'b001;
                if (draw_x>=8'd120) colour = 3'b000;
                if (draw_x==8'd39 || draw_x==8'd79 || draw_x==8'd119)
                    colour = 3'b111;
                if (draw_y==HIT_LINE_Y)
                    colour = 3'b110;
                // No extra hit bar: the tile ITSELF turns white and freezes.
                // Three life markers in the top-right (visual only).
                if (draw_y >= 7'd2 && draw_y < 7'd7) begin
                    if (draw_x >= 8'd127 && draw_x < 8'd135 && lives >= 2'd1) colour = 3'b100;
                    if (draw_x >= 8'd137 && draw_x < 8'd145 && lives >= 2'd2) colour = 3'b100;
                    if (draw_x >= 8'd147 && draw_x < 8'd155 && lives >= 2'd3) colour = 3'b100;
                end
                // Foreground tiles: slot 7 on top if rectangles overlap.
                for (i=0; i<8; i=i+1) begin
                    lane = tile_lanes[i*2 +: 2];
                    tile_top = tile_ys[i*7 +: 7];
                    // 8-bit sum avoids overflowing when a missed tile exits.
                    tile_bottom_exclusive = {1'b0, tile_top} + {1'b0, TILE_H};
                    left_edge = (lane * LANE_W) + 8'd4;
                    if (tile_visible[i] && draw_x>=left_edge && draw_x<left_edge+TILE_W &&
                        draw_y>=tile_top &&
                        {1'b0, draw_y}<tile_bottom_exclusive) begin
                        if (tile_white[i]) colour = 3'b111; // HIT: same shape, white
                        else case (lane)
                            2'd0: colour = 3'b101; // H, magenta
                            2'd1: colour = 3'b011; // J, cyan
                            2'd2: colour = 3'b010; // K, green
                            2'd3: colour = 3'b110; // L, yellow
                        endcase
                    end
                end
            end
            2'd2: begin // END: screen panel (numeric score on HEX)
                colour = 3'b001;
                if (draw_x>=8'd22 && draw_x<8'd138 && draw_y>=7'd34 && draw_y<7'd86)
                    colour = 3'b111;
                if (draw_x>=8'd26 && draw_x<8'd134 && draw_y>=7'd38 && draw_y<7'd82)
                    colour = 3'b000;
                if (draw_x>=8'd40 && draw_x<8'd120 && draw_y>=7'd57 && draw_y<7'd63)
                    colour = 3'b010;
            end
            2'd3: begin // GAME_OVER: red frame / bar (numeric state on HEX5)
                colour = 3'b100;
                if (draw_x >= 8'd7 && draw_x < 8'd153 && draw_y >= 7'd8 && draw_y < 7'd112)
                    colour = 3'b000;
                if (draw_x >= 8'd33 && draw_x < 8'd127 && draw_y >= 7'd45 && draw_y < 7'd75)
                    colour = 3'b100;
            end
            default: colour = 3'b000;
        endcase
    end
endmodule

// -------------------- audio_miku --------------------
module audio_miku #(
    parameter integer SONG_SAMPLES = 220800 // 46 seconds at 4800 Hz
)(
    input wire CLOCK_50, Resetn, StartPulse, Playing,
    input wire AUD_ADCDAT,
    inout wire AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, FPGA_I2C_SDAT,
    output wire AUD_XCK, AUD_DACDAT, FPGA_I2C_SCLK,
    output reg [17:0] sample_index
);
    wire reset = ~Resetn;
    wire audio_out_allowed;
    wire [31:0] q_data;
    reg playback;
    reg [3:0] repeat_cnt;
    reg [1:0] memory_wait;
    reg [7:0] current_sample;
    wire [15:0] addr_cnt = sample_index[17:2];
    wire [1:0] sample_sel = sample_index[1:0];
    wire write_audio_out = playback && Playing && !reset &&
                         audio_out_allowed && (memory_wait == 0);
    always @(posedge CLOCK_50) begin
        if (reset) begin
            playback <= 0; sample_index <= 0;
            repeat_cnt <= 0; memory_wait <= 0;
        end else if (StartPulse) begin
            playback <= 1; sample_index <= 0;
            repeat_cnt <= 0; memory_wait <= 3;
        end else if (!Playing) begin
            playback <= 0;
        end else if (playback) begin
            if (memory_wait != 0) memory_wait <= memory_wait - 1'b1;
            else if (write_audio_out) begin
                if (repeat_cnt == 9) begin
                    repeat_cnt <= 0;
                    if (sample_index == SONG_SAMPLES - 1) playback <= 0;
                    else begin
                        sample_index <= sample_index + 1'b1;
                        if (sample_sel == 3) memory_wait <= 3;
                    end
                end else repeat_cnt <= repeat_cnt + 1'b1;
            end
        end
    end
    always @(*) begin
        case (sample_sel)
            2'd0: current_sample = q_data[31:24];
            2'd1: current_sample = q_data[23:16];
            2'd2: current_sample = q_data[15:8];
            2'd3: current_sample = q_data[7:0];
            default: current_sample = 0;
        endcase
    end
    wire [31:0] audio_sample = {current_sample, 24'b0};
    intel_sound SOUND_ROM (
        .address(addr_cnt), .clock(CLOCK_50), .data(32'd0),
        .wren(1'b0), .q(q_data)
    );
    Audio_Controller AUDIO (
        .CLOCK_50(CLOCK_50), .reset(reset),
        .clear_audio_in_memory(1'b0), .read_audio_in(1'b0),
        .clear_audio_out_memory(StartPulse),
        .left_channel_audio_out(audio_sample),
        .right_channel_audio_out(audio_sample),
        .write_audio_out(write_audio_out),
        .AUD_ADCDAT(AUD_ADCDAT), .AUD_BCLK(AUD_BCLK),
        .AUD_ADCLRCK(AUD_ADCLRCK), .AUD_DACLRCK(AUD_DACLRCK),
        .audio_in_available(), .left_channel_audio_in(),
        .right_channel_audio_in(), .audio_out_allowed(audio_out_allowed),
        .AUD_XCK(AUD_XCK), .AUD_DACDAT(AUD_DACDAT)
    );
    avconf #(.USE_MIC_INPUT(1)) CONFIG (
        .FPGA_I2C_SCLK(FPGA_I2C_SCLK),
        .FPGA_I2C_SDAT(FPGA_I2C_SDAT),
        .CLOCK_50(CLOCK_50), .reset(reset)
    );
endmodule

// -------------------- hex7 --------------------
module hex7 (input wire [3:0] value, output reg [6:0] seg);
    always @(*) case(value)
        4'd0: seg=7'b1000000; 4'd1: seg=7'b1111001;
        4'd2: seg=7'b0100100; 4'd3: seg=7'b0110000;
        4'd4: seg=7'b0011001; 4'd5: seg=7'b0010010;
        4'd6: seg=7'b0000010; 4'd7: seg=7'b1111000;
        4'd8: seg=7'b0000000; 4'd9: seg=7'b0010000;
        4'd10:seg=7'b0001000; 4'd11:seg=7'b0000011;
        4'd12:seg=7'b1000110; 4'd13:seg=7'b0100001;
        4'd14:seg=7'b0000110; 4'd15:seg=7'b0001110;
        default: seg=7'b1111111;
    endcase
endmodule


// NOTE CHART BUILT INTO MILESTONE2.v (run update_note_chart.py to refresh)
// AUTO-GENERATED by update_note_chart.py from notes.csv. Do not edit directly.
// time_ms is when TILE CENTRE reaches hit line (not spawn time).
module song_rom (
    input wire [8:0] note_index,
    output reg [15:0] target_tick,
    output reg [1:0] lane,
    output reg valid,
    output wire [8:0] note_count
);
    assign note_count = 9'd21;
    always @(*) begin
        target_tick = 16'd0;
        lane = 2'd0;
        valid = 1'b0;
        case (note_index)
            9'd0: begin target_tick = 16'd100; lane = 2'd0; valid = 1'b1; end // 1000 ms, H
            9'd1: begin target_tick = 16'd145; lane = 2'd1; valid = 1'b1; end // 1450 ms, J
            9'd2: begin target_tick = 16'd185; lane = 2'd2; valid = 1'b1; end // 1850 ms, K
            9'd3: begin target_tick = 16'd230; lane = 2'd3; valid = 1'b1; end // 2300 ms, L
            9'd4: begin target_tick = 16'd265; lane = 2'd0; valid = 1'b1; end // 2650 ms, H
            9'd5: begin target_tick = 16'd300; lane = 2'd2; valid = 1'b1; end // 3000 ms, K
            9'd6: begin target_tick = 16'd330; lane = 2'd1; valid = 1'b1; end // 3300 ms, J
            9'd7: begin target_tick = 16'd330; lane = 2'd3; valid = 1'b1; end // 3300 ms, L
            9'd8: begin target_tick = 16'd385; lane = 2'd0; valid = 1'b1; end // 3850 ms, H
            9'd9: begin target_tick = 16'd420; lane = 2'd1; valid = 1'b1; end // 4200 ms, J
            9'd10: begin target_tick = 16'd470; lane = 2'd2; valid = 1'b1; end // 4700 ms, K
            9'd11: begin target_tick = 16'd510; lane = 2'd3; valid = 1'b1; end // 5100 ms, L
            9'd12: begin target_tick = 16'd580; lane = 2'd1; valid = 1'b1; end // 5800 ms, J
            9'd13: begin target_tick = 16'd650; lane = 2'd0; valid = 1'b1; end // 6500 ms, H
            9'd14: begin target_tick = 16'd720; lane = 2'd3; valid = 1'b1; end // 7200 ms, L
            9'd15: begin target_tick = 16'd900; lane = 2'd2; valid = 1'b1; end // 9000 ms, K
            9'd16: begin target_tick = 16'd1250; lane = 2'd0; valid = 1'b1; end // 12500 ms, H
            9'd17: begin target_tick = 16'd1800; lane = 2'd1; valid = 1'b1; end // 18000 ms, J
            9'd18: begin target_tick = 16'd2500; lane = 2'd2; valid = 1'b1; end // 25000 ms, K
            9'd19: begin target_tick = 16'd3200; lane = 2'd3; valid = 1'b1; end // 32000 ms, L
            9'd20: begin target_tick = 16'd4000; lane = 2'd1; valid = 1'b1; end // 40000 ms, J
            default: begin end
        endcase
    end
endmodule