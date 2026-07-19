// Module: paddle_control
// Purpose: Tracks ONE paddle's vertical (Y) position on screen.
//          Moves the paddle up/down by one step per video frame
//          while the corresponding button is held, clamped so
//          the paddle never moves off-screen.
//          Instantiate this module ONCE PER PADDLE (twice total
//          for two-player) with different button inputs wired in.
module paddle_control #(
    parameter PADDLE_HEIGHT = 60,   // paddle height in pixels
    parameter SCREEN_HEIGHT = 480,  // total visible vertical pixels
    parameter STEP          = 4,    // pixels moved per frame
    parameter START_Y       = 210   // initial paddle top-Y
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       btn_up,     // active-high, move paddle up
    input  wire       btn_down,   // active-high, move paddle down
    input  wire       vsync,      // from vga_sync — used to derive one tick/frame
    output reg [9:0]  paddle_y    // top-of-paddle Y coord, 0 to (SCREEN_HEIGHT-PADDLE_HEIGHT)
);

    localparam MAX_Y = SCREEN_HEIGHT - PADDLE_HEIGHT; // lowest legal top-Y

    // Frame-tick generation via manual edge detection
    reg  vsync_prev;
    wire frame_tick;

    always @(posedge clk) begin
        if (reset)
            vsync_prev <= 1'b0;
        else
            vsync_prev <= vsync;
    end

    assign frame_tick = vsync & ~vsync_prev;  // 1-cycle pulse on vsync's rising edge

    // Paddle position register
    always @(posedge clk) begin
        if (reset) begin
            paddle_y <= START_Y;
        end else if (frame_tick) begin
            if (btn_up && !btn_down) begin
                if (paddle_y >= STEP)
                    paddle_y <= paddle_y - STEP;
                else
                    paddle_y <= 10'd0;              // clamp to top
            end else if (btn_down && !btn_up) begin
                if (paddle_y <= MAX_Y - STEP)
                    paddle_y <= paddle_y + STEP;
                else
                    paddle_y <= MAX_Y[9:0];          // clamp to bottom
            end
            // both or neither pressed -> hold position, no else needed
        end
    end

endmodule