// Module: ball_control
// Purpose: Tracks the ball's (X, Y) position on screen. Moves
//          diagonally by STEP pixels once per video frame,
//          reversing X direction on left/right wall contact and
//          Y direction on top/bottom wall contact, independently.
//          NOTE: left/right bounce is a placeholder for now —
//          Milestone 6 (scoring) will replace it with a score
//          event + ball reset instead of a simple bounce.

module ball_control #(
    parameter BALL_SIZE     = 8,    // ball width/height in pixels (square ball)
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter STEP          = 4,    // pixels moved per frame, per axis
    parameter START_X       = 316,  // roughly screen center
    parameter START_Y       = 236
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       vsync,      // from vga_sync — same frame_tick technique as paddle_control
    output reg [9:0]  ball_x,     // top-left X of ball
    output reg [9:0]  ball_y      // top-left Y of ball
);

    localparam MAX_X = SCREEN_WIDTH  - BALL_SIZE; // rightmost legal X
    localparam MAX_Y = SCREEN_HEIGHT - BALL_SIZE; // bottommost legal Y


    // Frame-tick generation (identical technique to paddle_control)
    reg  vsync_prev;
    wire frame_tick;

    always @(posedge clk) begin
        if (reset)
            vsync_prev <= 1'b0;
        else
            vsync_prev <= vsync;
    end

    assign frame_tick = vsync & ~vsync_prev;

    // Direction flags: 0 = moving right/down, 1 = moving left/up
    reg x_dir, y_dir;

    // Position + direction update, once per frame_tick
    always @(posedge clk) begin
        if (reset) begin
            ball_x <= START_X;
            ball_y <= START_Y;
            x_dir  <= 1'b0;   // start moving right
            y_dir  <= 1'b0;   // start moving down
        end else if (frame_tick) begin

            // --- X axis: move, then check for wall contact ---
            if (x_dir == 1'b0) begin              // moving right
                if (ball_x >= MAX_X - STEP) begin
                    ball_x <= MAX_X[9:0];
                    x_dir  <= 1'b1;                // bounce: now move left
                end else begin
                    ball_x <= ball_x + STEP;
                end
            end else begin                        // moving left
                if (ball_x <= STEP) begin
                    ball_x <= 10'd0;
                    x_dir  <= 1'b0;                // bounce: now move right
                end else begin
                    ball_x <= ball_x - STEP;
                end
            end

            // --- Y axis: identical structure, fully independent ---
            if (y_dir == 1'b0) begin              // moving down
                if (ball_y >= MAX_Y - STEP) begin
                    ball_y <= MAX_Y[9:0];
                    y_dir  <= 1'b1;                // bounce: now move up
                end else begin
                    ball_y <= ball_y + STEP;
                end
            end else begin                        // moving up
                if (ball_y <= STEP) begin
                    ball_y <= 10'd0;
                    y_dir  <= 1'b0;                // bounce: now move down
                end else begin
                    ball_y <= ball_y - STEP;
                end
            end

        end
    end

endmodule