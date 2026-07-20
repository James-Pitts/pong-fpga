// Module: collision
// Purpose: Detects axis-aligned bounding-box (AABB) overlap
//          between the ball and each of the two paddles.
//          Outputs a single-cycle pulse the instant contact
//          begins (not held high for the whole overlap duration)
//          so downstream logic (ball direction flip) triggers
//          exactly once per hit, not repeatedly while touching.
//          NOTE: does not yet compute bounce angle — that is a
//          deferred polish item. Also not yet wired into
//          ball_control — that happens at top-level integration
//          (Milestone 7), per project convention of testing every
//          module standalone before integration.
module collision #(
    parameter BALL_SIZE      = 8,
    parameter PADDLE_WIDTH   = 10,
    parameter PADDLE_HEIGHT  = 60,
    parameter PADDLE_X_LEFT  = 20,    // fixed X of left paddle's left edge
    parameter PADDLE_X_RIGHT = 610    // fixed X of right paddle's left edge
)(
    input  wire       clk,
    input  wire       reset,
    input  wire [9:0] ball_x,
    input  wire [9:0] ball_y,
    input  wire [9:0] paddle_y_left,   // top-Y of left paddle (from paddle_control)
    input  wire [9:0] paddle_y_right,  // top-Y of right paddle (from paddle_control)
    output reg        hit_left,        // 1-cycle pulse: ball just touched left paddle
    output reg        hit_right        // 1-cycle pulse: ball just touched right paddle
);

    // Combinational AABB overlap checks (the "flashlight shadow"
    // test on both axes at once). These are LEVEL signals — true
    // for the whole duration the ball and paddle are touching,
    // not just one instant. That's why they need edge detection
    // below before becoming usable "hit" pulses.
    wire overlap_left, overlap_right;

    assign overlap_left =
        (ball_x <= PADDLE_X_LEFT + PADDLE_WIDTH - 1) &&               // ball's left edge hasn't passed paddle's right edge
        (ball_x + BALL_SIZE - 1 >= PADDLE_X_LEFT) &&                  // ball's right edge has reached paddle's left edge
        (ball_y <= paddle_y_left + PADDLE_HEIGHT - 1) &&              // ball's top edge hasn't passed paddle's bottom edge
        (ball_y + BALL_SIZE - 1 >= paddle_y_left);                    // ball's bottom edge has reached paddle's top edge

    assign overlap_right =
        (ball_x + BALL_SIZE - 1 >= PADDLE_X_RIGHT) &&
        (ball_x <= PADDLE_X_RIGHT + PADDLE_WIDTH - 1) &&
        (ball_y <= paddle_y_right + PADDLE_HEIGHT - 1) &&
        (ball_y + BALL_SIZE - 1 >= paddle_y_right);

    // Edge detection: same "remember last cycle, compare to now"
    // technique used for frame_tick in paddle_control/ball_control.
    // Converts a LEVEL signal (overlap_left/right) into a single-
    // cycle PULSE (hit_left/right) on the rising edge only.
    reg overlap_left_prev, overlap_right_prev;

    always @(posedge clk) begin
        if (reset) begin
            overlap_left_prev  <= 1'b0;
            overlap_right_prev <= 1'b0;
            hit_left            <= 1'b0;
            hit_right            <= 1'b0;
        end else begin
            overlap_left_prev  <= overlap_left;
            overlap_right_prev <= overlap_right;
            hit_left            <= overlap_left  & ~overlap_left_prev;
            hit_right            <= overlap_right & ~overlap_right_prev;
        end
    end

endmodule