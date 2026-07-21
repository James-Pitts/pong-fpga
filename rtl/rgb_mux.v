// Module: rgb_mux
// Purpose: Combinational-then-registered pixel painter. For the
//          pixel currently addressed by pixel_x/pixel_y, decides
//          whether it falls inside the ball's or either paddle's
//          "stencil" and outputs white; otherwise black. Blanked
//          to black entirely during retrace (video_on low).
//
// Known limitations / deferred scope:
//   - Solid white-on-black only -- no color variation, no
//     score/HUD rendering on screen (scores are register values
//     only at this stage, not yet drawn as digits -- optional
//     post-Milestone-8 polish item).
//   - COLOR_WIDTH defaults to 4 bits/channel, a guess pending
//     confirmation of the real board's VGA DAC width once
//     hardware is available.
module rgb_mux #(
    parameter COLOR_WIDTH    = 4,
    parameter BALL_SIZE      = 8,
    parameter PADDLE_WIDTH   = 10,
    parameter PADDLE_HEIGHT  = 60,
    parameter PADDLE_X_LEFT  = 20,
    parameter PADDLE_X_RIGHT = 610
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    video_on,
    input  wire [9:0]              pixel_x,
    input  wire [9:0]              pixel_y,
    input  wire [9:0]              ball_x,
    input  wire [9:0]              ball_y,
    input  wire [9:0]              paddle_y_left,
    input  wire [9:0]              paddle_y_right,
    output reg  [COLOR_WIDTH-1:0]  red,
    output reg  [COLOR_WIDTH-1:0]  green,
    output reg  [COLOR_WIDTH-1:0]  blue
);

    // ---- combinational stencils (off-by-one convention from collision.v) ----
    wire ball_on = (pixel_x >= ball_x) && (pixel_x <= ball_x + BALL_SIZE - 1) &&
                   (pixel_y >= ball_y) && (pixel_y <= ball_y + BALL_SIZE - 1);

    wire paddle_left_on  = (pixel_x >= PADDLE_X_LEFT[9:0]) &&
                           (pixel_x <= PADDLE_X_LEFT[9:0] + PADDLE_WIDTH - 1) &&
                           (pixel_y >= paddle_y_left) &&
                           (pixel_y <= paddle_y_left + PADDLE_HEIGHT - 1);

    wire paddle_right_on = (pixel_x >= PADDLE_X_RIGHT[9:0]) &&
                           (pixel_x <= PADDLE_X_RIGHT[9:0] + PADDLE_WIDTH - 1) &&
                           (pixel_y >= paddle_y_right) &&
                           (pixel_y <= paddle_y_right + PADDLE_HEIGHT - 1);

    wire pixel_lit = ball_on || paddle_left_on || paddle_right_on;

    // ---- registered output, matching the "registered outputs, 1-cycle lag,
    //      intentional" convention already established in vga_sync.v ----
    always @(posedge clk) begin
        if (reset) begin
            red   <= {COLOR_WIDTH{1'b0}};
            green <= {COLOR_WIDTH{1'b0}};
            blue  <= {COLOR_WIDTH{1'b0}};
        end else if (video_on && pixel_lit) begin
            red   <= {COLOR_WIDTH{1'b1}};
            green <= {COLOR_WIDTH{1'b1}};
            blue  <= {COLOR_WIDTH{1'b1}};
        end else begin
            red   <= {COLOR_WIDTH{1'b0}};
            green <= {COLOR_WIDTH{1'b0}};
            blue  <= {COLOR_WIDTH{1'b0}};
        end
    end

endmodule