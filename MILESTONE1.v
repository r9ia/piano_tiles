module gameManager(CLOCK_50, SW, KEY, LEDR);
    input CLOCK_50; // Actual timer for htis
    input [3:0] KEY;

    output [9:0]LEDR;

    wire clock = CLOCK_50;
    wire Resetn = KEY[0];
    wire Start = KEY[1];

    wire [3:0] press;
    wire [2:0] lenght;
    wire tick, shift;




endmodule


module hex7(input wire [3:0] value, output reg [6:0] seg);
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


module buttonPulse #();

    parameter DEBOUNCE = 500000
    input Clock, Resetn, key, pulse
    reg sync1, sync2, 

endmodule




module countdown(Clock, Resetn);
    parameter MAX = 25_000_000_000   
endmodule



module gameFSM(Clock, Resetn, Start, timeup, state);

    input Clock, Resetn, Start, timeup;
    output reg [1:0] state;

    localparam [1:0]
        BEGIN_STATE = 2'd0,
        PLAY_STATE = 2'd1,
        END_STATE= 2'd2;

    always @(posedge Clock or negedge Resetn) 
    begin
        if (!Resetn)
            state <= BEGIN_STATE;
        else 
        begin
            case (state)
                BEGIN_STATE:
                    if (Start)
                        state <= PLAY_STATE;

                PLAY_STATE:
                    if (timeup)
                        state <= END_STATE;

                END_STATE:
                    if (Start)
                        state <= BEGIN_STATE;

                default:
                    state <= BEGIN_STATE;
            endcase
        end
    end

endmodule
