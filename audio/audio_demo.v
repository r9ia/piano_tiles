// 4800 Hz, signed 8-bit mono PCM, 4 samples per 32-bit word.
// KEY[0]: reset. KEY[1]: start/restart (release to begin).
module audio_demo (
    input CLOCK_50,
    input [3:0] KEY,
    input [3:0] SW,
    input AUD_ADCDAT,
    inout AUD_BCLK,
    inout AUD_ADCLRCK,
    inout AUD_DACLRCK,
    inout FPGA_I2C_SDAT,
    output AUD_XCK,
    output AUD_DACDAT,
    output FPGA_I2C_SCLK
);
    // Set this to the actual sample count printed by wav_to_mif.py.
    // Default plays all 262144 samples, including any silence padding.
    parameter integer SONG_SAMPLES = 262144;

    wire reset = ~KEY[0];
    wire audio_out_allowed;
    wire [31:0] q_data;
    reg playback;
    reg [17:0] sample_index;
    reg [3:0] repeat_cnt;
    reg [1:0] memory_wait;
    reg [7:0] current_sample;

    wire [15:0] addr_cnt = sample_index[17:2];
    wire [1:0] sample_sel = sample_index[1:0];
    wire write_audio_out = playback && KEY[1] && !reset &&
                           audio_out_allowed && (memory_wait == 0);

    always @(posedge CLOCK_50) begin
        if (reset) begin
            playback <= 0;
            sample_index <= 0;
            repeat_cnt <= 0;
            memory_wait <= 0;
        end else if (!KEY[1]) begin
            playback <= 1;
            sample_index <= 0;
            repeat_cnt <= 0;
            memory_wait <= 3;
        end else if (playback) begin
            if (memory_wait != 0) begin
                memory_wait <= memory_wait - 1'b1;
            end else if (write_audio_out) begin
                // Repeat each stored sample ten times at 48 kHz.
                if (repeat_cnt == 9) begin
                    repeat_cnt <= 0;
                    if (sample_index == SONG_SAMPLES - 1) begin
                        playback <= 0;
                    end else begin
                        sample_index <= sample_index + 1'b1;
                        // The RAM has registered address and output.
                        if (sample_sel == 3)
                            memory_wait <= 3;
                    end
                end else begin
                    repeat_cnt <= repeat_cnt + 1'b1;
                end
            end
        end
    end

    always @(*) begin
        case (sample_sel)
            2'd0: current_sample = q_data[31:24];
            2'd1: current_sample = q_data[23:16];
            2'd2: current_sample = q_data[15:8];
            2'd3: current_sample = q_data[7:0];
            default: current_sample = 8'd0;
        endcase
    end

    // Scale signed 8-bit PCM to signed 32-bit PCM.
    wire [31:0] audio_sample = {current_sample, 24'b0};

    intel_sound intel_sound_inst (
        .address(addr_cnt), .clock(CLOCK_50),
        .data(32'b0), .wren(1'b0), .q(q_data)
    );

    Audio_Controller Audio_Controller (
        .CLOCK_50(CLOCK_50), .reset(reset),
        .clear_audio_in_memory(1'b0), .read_audio_in(1'b0),
        .clear_audio_out_memory(!KEY[1]),
        .left_channel_audio_out(audio_sample),
        .right_channel_audio_out(audio_sample),
        .write_audio_out(write_audio_out),
        .AUD_ADCDAT(AUD_ADCDAT), .AUD_BCLK(AUD_BCLK),
        .AUD_ADCLRCK(AUD_ADCLRCK), .AUD_DACLRCK(AUD_DACLRCK),
        .audio_in_available(), .left_channel_audio_in(),
        .right_channel_audio_in(), .audio_out_allowed(audio_out_allowed),
        .AUD_XCK(AUD_XCK), .AUD_DACDAT(AUD_DACDAT)
    );

    avconf #(.USE_MIC_INPUT(1)) avc (
        .FPGA_I2C_SCLK(FPGA_I2C_SCLK),
        .FPGA_I2C_SDAT(FPGA_I2C_SDAT),
        .CLOCK_50(CLOCK_50), .reset(reset)
    );
endmodule
