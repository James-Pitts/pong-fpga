// Module: ball_control
// Purpose: Tracks ball (X,Y) position. Moves diagonally by STEP
//          pixels once per frame_tick. Top/bottom wall contact is
//          a permanent bounce (unchanged since Milestone 4).
//          Left/right wall contact NO LONGER bounces (placeholder
//          removed) -- it freezes the ball at the edge and emits
//          a one-cycle wall_hit_left/wall_hit_right pulse for
//          score_fsm.v, which responds with a game_reset pulse
//          telling this module to re-center and re-serve.
//          Paddle contact (from collision.v) is now what flips
//          x_dir, replacing the old self-bounce logic.
//
// Known limitations / deferred scope:
//   - Serve direction after a score is a simple deterministic rule
//     (serves toward whichever side didn't just concede the point)
//     -- not italicized as "correct" Pong convention, just a
//       documented design choice, easy to flip if preferred.
//   - y_dir on re-serve always resets to a fixed default (moving
//     down) rather than preserving pre-score momentum -- simplest
//     option, cosmetic only.
module ball_control #(
    parameter BALL_SIZE     = 8,
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter STEP          = 4,
    parameter START_X       = 316,
    parameter START_Y       = 236
)(
    input  wire       clk,
    input  wire       reset,             // synchronous active-high, global
    input  wire       vsync,             // from vga_sync -- frame_tick source
    input  wire       paddle_hit_left,   // 1-cycle pulse from collision.v: touched LEFT paddle
    input  wire       paddle_hit_right,  // 1-cycle pulse from collision.v: touched RIGHT paddle
    input  wire       game_reset,        // 1-cycle pulse from score_fsm.v: re-center & re-serve
    output reg [9:0]  ball_x,
    output reg [9:0]  ball_y,
    output reg        wall_hit_left,     // 1-cycle pulse: ball reached LEFT screen edge -> score_fsm
    output reg        wall_hit_right     // 1-cycle pulse: ball reached RIGHT screen edge -> score_fsm
);

    localparam MAX_X = SCREEN_WIDTH  - BALL_SIZE;
    localparam MAX_Y = SCREEN_HEIGHT - BALL_SIZE;

    // ---- frame_tick (identical technique to paddle_control / Milestone 3) ----
    reg vsync_prev;
    wire frame_tick = vsync & ~vsync_prev;

    // ---- direction flags ----
    reg x_dir; // 0 = moving left, 1 = moving right
    reg y_dir; // 0 = moving up,   1 = moving down

    // ---- edge-of-screen level signals (X axis only -- Y still bounces) ----
    wire at_left  = (ball_x == 10'd0);
    wire at_right = (ball_x == MAX_X[9:0]);

    // ---- edge detection on at_left/at_right, same technique as frame_tick ----
    reg at_left_prev, at_right_prev;

    // ---- latch: which wall was hit last, so a re-serve knows which way to go ----
    reg last_hit_was_left;

    always @(posedge clk) begin
        if (reset) begin
            ball_x            <= START_X[9:0];
            ball_y            <= START_Y[9:0];
            x_dir             <= 1'b1;
            y_dir             <= 1'b1;
            vsync_prev        <= 1'b0;
            at_left_prev      <= 1'b0;
            at_right_prev     <= 1'b0;
            last_hit_was_left <= 1'b0;
            wall_hit_left     <= 1'b0;
            wall_hit_right    <= 1'b0;
        end else begin
            vsync_prev    <= vsync;
            at_left_prev  <= at_left;
            at_right_prev <= at_right;

            // default every cycle; only the branches below override
            wall_hit_left  <= 1'b0;
            wall_hit_right <= 1'b0;

            if (at_left  && !at_left_prev)  wall_hit_left  <= 1'b1;
            if (at_right && !at_right_prev) wall_hit_right <= 1'b1;

            if (wall_hit_left)  last_hit_was_left <= 1'b1;
            if (wall_hit_right) last_hit_was_left <= 1'b0;

            // paddle contact flips X direction (replaces old self-bounce)
            if (paddle_hit_left)  x_dir <= 1'b1; // was moving left, now bounce right
            if (paddle_hit_right) x_dir <= 1'b0; // was moving right, now bounce left

            // game_reset takes priority over ordinary frame_tick movement
            if (game_reset) begin
                ball_x <= START_X[9:0];
                ball_y <= START_Y[9:0];
                x_dir  <= last_hit_was_left ? 1'b1 : 1'b0; // serve toward the side that didn't concede
                y_dir  <= 1'b1;
            end else if (frame_tick) begin
                // ---- X axis: look-ahead clamp, freeze at edge instead of bouncing ----
                if (!at_left && !at_right) begin
                    if (x_dir) begin // moving right
                        if (ball_x + STEP[9:0] >= MAX_X[9:0])
                            ball_x <= MAX_X[9:0];
                        else
                            ball_x <= ball_x + STEP[9:0];
                    end else begin // moving left
                        if (ball_x <= STEP[9:0])
                            ball_x <= 10'd0;
                        else
                            ball_x <= ball_x - STEP[9:0];
                    end
                end
                // else: frozen at a wall, holding position until game_reset arrives

                // ---- Y axis: permanent top/bottom bounce, unchanged since Milestone 4 ----
                if (y_dir) begin // moving down
                    if (ball_y + STEP[9:0] >= MAX_Y[9:0]) begin
                        ball_y <= MAX_Y[9:0];
                        y_dir  <= 1'b0;
                    end else begin
                        ball_y <= ball_y + STEP[9:0];
                    end
                end else begin // moving up
                    if (ball_y <= STEP[9:0]) begin
                        ball_y <= 10'd0;
                        y_dir  <= 1'b1;
                    end else begin
                        ball_y <= ball_y - STEP[9:0];
                    end
                end
            end
        end
    end

endmodule