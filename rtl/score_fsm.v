// Module: score_fsm
// Purpose: Game state machine (RESET -> PLAY -> SCORE -> GAME_OVER).
//          Tracks left/right player scores from ball wall-contact
//          pulses and issues a one-cycle ball_reset pulse after
//          each point, ending the game once a player reaches
//          WIN_SCORE points.
//
// Known limitations / deferred scope:
//   - hit_left / hit_right are expected as single-cycle pulses,
//     in the same style as collision.v's hit_left/hit_right
//     outputs. In this milestone they are driven directly by the
//     testbench; wiring them from the real ball_control.v wall-
//     contact logic (replacing its placeholder left/right bounce)
//     is Milestone 7 (top-level integration) work.
//   - If hit_left and hit_right both pulse on the exact same
//     cycle, hit_left takes priority. This should never happen in
//     the real design (the ball can only touch one wall at a
//     time) -- it's a defensive default, not expected behavior.
module score_fsm #(
    parameter WIN_SCORE = 5   // first player to reach this score wins
)(
    input  wire       clk,
    input  wire       reset,        // synchronous active-high
    input  wire       hit_left,     // 1-cycle pulse: ball touched LEFT wall  -> RIGHT player scores
    input  wire       hit_right,    // 1-cycle pulse: ball touched RIGHT wall -> LEFT player scores
    output reg  [3:0] score_left,
    output reg  [3:0] score_right,
    output reg        ball_reset,   // 1-cycle pulse telling ball_control to re-center/re-launch
    output reg        game_over,    // level signal, high once a player reaches WIN_SCORE
    output reg  [1:0] state         // exposed for rgb_mux / debug
);

    // ---- State encoding (VHDL: type state_t is (RESET, PLAY, SCORE, GAME_OVER)) ----
    localparam S_RESET     = 2'd0;
    localparam S_PLAY      = 2'd1;
    localparam S_SCORE     = 2'd2;
    localparam S_GAME_OVER = 2'd3;

    always @(posedge clk) begin
        if (reset) begin
            state       <= S_RESET;
            score_left  <= 4'd0;
            score_right <= 4'd0;
            ball_reset  <= 1'b0;
            game_over   <= 1'b0;
        end else begin
            // Default every cycle; only the SCORE state overrides this.
            ball_reset <= 1'b0;

            case (state)

                S_RESET: begin
                    score_left  <= 4'd0;
                    score_right <= 4'd0;
                    game_over   <= 1'b0;
                    state       <= S_PLAY;
                end

                S_PLAY: begin
                    if (hit_left) begin
                        score_right <= score_right + 1'b1; // ball got past the left wall
                        state       <= S_SCORE;
                    end else if (hit_right) begin
                        score_left  <= score_left + 1'b1;  // ball got past the right wall
                        state       <= S_SCORE;
                    end
                    // else: no scoring event this cycle, stay in S_PLAY
                end

                S_SCORE: begin
                    ball_reset <= 1'b1; // exactly one cycle high
                    if ((score_left == WIN_SCORE) || (score_right == WIN_SCORE)) begin
                        game_over <= 1'b1;
                        state     <= S_GAME_OVER;
                    end else begin
                        state <= S_PLAY;
                    end
                end

                S_GAME_OVER: begin
                    state <= S_GAME_OVER; // hold here; only reset can leave
                end

                default: state <= S_RESET; // unreachable, defensive
            endcase
        end
    end

endmodule